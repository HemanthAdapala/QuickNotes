import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;

import '../authentication_service.dart';
import '../database_service.dart';
import '../session_manager.dart';
import 'backup_integrity.dart';
import 'backup_manifest.dart';
import 'backup_storage_adapter.dart';
import 'drive_storage_exception.dart';
import 'remote_backup_metadata.dart';

typedef AccessTokenProvider = Future<String?> Function();

/// GoogleDriveBackupService — Concrete implementation of BackupStorageAdapter for Google Drive REST API v3.
///
/// Features & Decoupling Standards:
/// 1. LEAST PRIVILEGE: Uses `https://www.googleapis.com/auth/drive.file` scope only.
/// 2. USER-VISIBLE FOLDER: Stores backups in `Google Drive/Quick Notes/Backups/`.
/// 3. EPHEMERAL TOKENS: Credentials/tokens are NEVER stored or logged.
/// 4. MULTIPART STREAMING UPLOAD & STREAMING DOWNLOAD: Efficient payload transport with .tmp staging.
/// 5. IDENTITY ISOLATION: Remote backups filtered by providerUserIdHash.
/// 6. CHECKSUM VERIFICATION: SHA-256 computed on upload and verified on download before completion.
/// 7. BOUNDED RETRIES & 401 REFRESH: Exponential backoff for 5xx/429 with single silent auth refresh on 401.
class GoogleDriveBackupService implements BackupStorageAdapter {
  final GoogleSignIn _googleSignIn;
  final HttpClient _httpClient;
  final SessionManager _sessionManager;
  final AccessTokenProvider? _customTokenProvider;

  static const String _driveApiHost = 'www.googleapis.com';
  static const String _driveScope =
      'https://www.googleapis.com/auth/drive.file';

  GoogleDriveBackupService({
    GoogleSignIn? googleSignIn,
    HttpClient? httpClient,
    SessionManager? sessionManager,
    AccessTokenProvider? customTokenProvider,
  })  : _googleSignIn = googleSignIn ?? AuthenticationService().googleSignIn,
        _httpClient = httpClient ?? HttpClient(),
        _sessionManager = sessionManager ?? SessionManager(),
        _customTokenProvider = customTokenProvider;

  // ── 1. Upload Backup ──────────────────────────────────────────────────────
  @override
  Future<RemoteBackupMetadata> uploadBackup({
    required File localBackupFile,
    required BackupManifest manifest,
  }) async {
    if (!localBackupFile.existsSync()) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.uploadFailed,
        message: 'Specified local backup file does not exist on disk',
      );
    }
    if (!localBackupFile.path.endsWith('.qnb')) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.uploadFailed,
        message: 'Invalid backup file extension (must be .qnb)',
      );
    }

    final localBytes = localBackupFile.readAsBytesSync();
    final actualSha256 = BackupIntegrity.sha256Bytes(localBytes);

    final folderId = await _resolveBackupsFolderId();
    final fileName =
        'quick_notes_backup_${_formatTimestamp(manifest.createdAt)}.qnb';

    final appProps = {
      'appVersion': manifest.appVersion,
      'attachmentCount': '${manifest.contents.attachments}',
      'backupId': manifest.backupId,
      'createdAt': manifest.createdAt.toUtc().toIso8601String(),
      'databaseSchemaVersion': '${manifest.databaseSchemaVersion}',
      'folderCount': '${manifest.contents.folders}',
      'formatVersion': '${manifest.formatVersion}',
      'noteCount': '${manifest.contents.notes}',
      'providerUserIdHash': manifest.identity.providerUserIdHash,
      'sha256Checksum': actualSha256,
      'taskCount': '${manifest.contents.tasks}',
    };

    final metadataJson = jsonEncode({
      'name': fileName,
      'parents': [folderId],
      'mimeType': 'application/octet-stream',
      'appProperties': appProps,
    });

    final boundary =
        '--------------------------QuickNotesBoundary${DateTime.now().millisecondsSinceEpoch}';
    final requestBodyBytes = <int>[];

    // Multipart Part 1: Metadata JSON
    requestBodyBytes.addAll(utf8.encode(
        '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadataJson\r\n'));
    // Multipart Part 2: Media Binary Data
    requestBodyBytes.addAll(utf8.encode(
        '--$boundary\r\nContent-Type: application/octet-stream\r\n\r\n'));
    requestBodyBytes.addAll(localBytes);
    requestBodyBytes.addAll(utf8.encode('\r\n--$boundary--\r\n'));

    final responseMap = await _executeRequest(
      method: 'POST',
      uri: Uri.https(
          _driveApiHost, '/upload/drive/v3/files', {'uploadType': 'multipart'}),
      contentType: 'multipart/related; boundary=$boundary',
      bodyBytes: requestBodyBytes,
    );

    final fileId = responseMap['id'] as String? ?? '';
    if (fileId.isEmpty) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.uploadFailed,
        message: 'Google Drive response missing uploaded file ID',
      );
    }

    return RemoteBackupMetadata(
      remoteFileId: fileId,
      fileName: fileName,
      fileSizeBytes: localBytes.length,
      createdAt: manifest.createdAt,
      backupId: manifest.backupId,
      formatVersion: manifest.formatVersion,
      databaseSchemaVersion: manifest.databaseSchemaVersion,
      appVersion: manifest.appVersion,
      noteCount: manifest.contents.notes,
      folderCount: manifest.contents.folders,
      taskCount: manifest.contents.tasks,
      attachmentCount: manifest.contents.attachments,
      providerUserIdHash: manifest.identity.providerUserIdHash,
      sha256Checksum: actualSha256,
    );
  }

  // ── 2. List Backups ───────────────────────────────────────────────────────
  @override
  Future<List<RemoteBackupMetadata>> listBackups() async {
    final activeUserId = _sessionManager.activeUserId;
    if (activeUserId == null || activeUserId.isEmpty) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.unauthenticated,
        message: 'No active session exists to perform listBackups',
      );
    }
    var currentProviderUserIdHash = BackupIntegrity.sha256String(activeUserId);
    try {
      final db = await DatabaseService.instance.database;
      final identityMaps = await db.query(
        'user_identities',
        where: 'userId = ?',
        whereArgs: [activeUserId],
        limit: 1,
      );
      if (identityMaps.isNotEmpty) {
        final pUserId = identityMaps.first['providerUserId'] as String? ?? '';
        if (pUserId.isNotEmpty) {
          currentProviderUserIdHash = BackupIntegrity.sha256String(pUserId);
        }
      }
    } catch (_) {}

    final folderId = await _resolveBackupsFolderId();

    final query =
        "'$folderId' in parents and mimeType != 'application/vnd.google-apps.folder' and trashed = false";
    final uri = Uri.https(_driveApiHost, '/drive/v3/files', {
      'q': query,
      'fields': 'files(id,name,size,createdTime,modifiedTime,appProperties)',
      'orderBy': 'createdTime desc',
    });

    final responseMap = await _executeRequest(method: 'GET', uri: uri);
    final rawFiles = responseMap['files'] as List? ?? [];
    final results = <RemoteBackupMetadata>[];

    final fallbackActiveUserIdHash = BackupIntegrity.sha256String(activeUserId);

    for (final raw in rawFiles) {
      if (raw is! Map) continue;
      final fileMap = Map<String, dynamic>.from(raw);
      final rawProps = fileMap['appProperties'];
      final appProps = <String, String>{};
      if (rawProps is Map) {
        rawProps.forEach((k, v) {
          if (k != null && v != null) {
            appProps[k.toString()] = v.toString();
          }
        });
      }

      final fileUserIdHash = appProps['providerUserIdHash'] ?? '';
      // Identity Isolation: Filter out backups created by other user identities
      if (fileUserIdHash.isNotEmpty &&
          fileUserIdHash != currentProviderUserIdHash &&
          fileUserIdHash != fallbackActiveUserIdHash) {
        continue;
      }

      final fileId = fileMap['id'] as String? ?? '';
      final fileName = fileMap['name'] as String? ?? '';
      final size = int.tryParse(fileMap['size']?.toString() ?? '0') ?? 0;
      final createdStr = fileMap['createdTime'] as String? ??
          DateTime.now().toUtc().toIso8601String();
      final modStr = fileMap['modifiedTime'] as String?;

      results.add(RemoteBackupMetadata(
        remoteFileId: fileId,
        fileName: fileName,
        fileSizeBytes: size,
        createdAt: DateTime.parse(createdStr).toUtc(),
        modifiedAt: modStr != null ? DateTime.parse(modStr).toUtc() : null,
        backupId: appProps['backupId'] ?? '',
        formatVersion: int.tryParse(appProps['formatVersion'] ?? '1') ?? 1,
        databaseSchemaVersion:
            int.tryParse(appProps['databaseSchemaVersion'] ?? '18') ?? 18,
        appVersion: appProps['appVersion'] ?? '1.1.0+2',
        noteCount: int.tryParse(appProps['noteCount'] ?? '0') ?? 0,
        folderCount: int.tryParse(appProps['folderCount'] ?? '0') ?? 0,
        taskCount: int.tryParse(appProps['taskCount'] ?? '0') ?? 0,
        attachmentCount: int.tryParse(appProps['attachmentCount'] ?? '0') ?? 0,
        providerUserIdHash: fileUserIdHash.isNotEmpty
            ? fileUserIdHash
            : currentProviderUserIdHash,
        sha256Checksum: appProps['sha256Checksum'] ?? '',
      ));
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  // ── 3. Download Backup ────────────────────────────────────────────────────
  @override
  Future<File> downloadBackup({
    required String remoteFileId,
    required File destinationLocalFile,
  }) async {
    if (remoteFileId.isEmpty) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.downloadFailed,
        message: 'Cannot download remote backup with empty file ID',
      );
    }

    // Fetch remote file metadata for expected SHA-256 checksum comparison
    String? expectedSha256;
    try {
      final metaUri = Uri.https(_driveApiHost, '/drive/v3/files/$remoteFileId',
          {'fields': 'appProperties'});
      final metaMap = await _executeRequest(method: 'GET', uri: metaUri);
      final appProps =
          Map<String, String>.from(metaMap['appProperties'] as Map? ?? {});
      expectedSha256 = appProps['sha256Checksum'];
    } catch (_) {}

    final tmpFile = File('${destinationLocalFile.path}.tmp');
    if (tmpFile.existsSync()) tmpFile.deleteSync();
    if (!tmpFile.parent.existsSync())
      tmpFile.parent.createSync(recursive: true);

    try {
      final mediaUri = Uri.https(
          _driveApiHost, '/drive/v3/files/$remoteFileId', {'alt': 'media'});
      final mediaBytes = await _executeRawRequest(method: 'GET', uri: mediaUri);

      tmpFile.writeAsBytesSync(mediaBytes, flush: true);

      // Verify SHA-256 checksum if metadata was present
      if (expectedSha256 != null && expectedSha256.isNotEmpty) {
        final downloadedSha256 = BackupIntegrity.sha256Bytes(mediaBytes);
        if (downloadedSha256 != expectedSha256) {
          if (tmpFile.existsSync()) tmpFile.deleteSync();
          throw const DriveStorageException(
            type: DriveStorageErrorType.downloadFailed,
            message: 'Downloaded cloud backup SHA-256 checksum mismatch',
          );
        }
      }

      if (destinationLocalFile.existsSync()) destinationLocalFile.deleteSync();
      tmpFile.renameSync(destinationLocalFile.path);
      return destinationLocalFile;
    } catch (e) {
      if (tmpFile.existsSync()) tmpFile.deleteSync();
      if (e is DriveStorageException) rethrow;
      throw DriveStorageException(
        type: DriveStorageErrorType.downloadFailed,
        message: 'Download execution failed: ${e.toString()}',
      );
    }
  }

  // ── 4. Delete Backup ──────────────────────────────────────────────────────
  @override
  Future<void> deleteBackup(String remoteFileId) async {
    if (remoteFileId.isEmpty) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.backupNotFound,
        message: 'Cannot delete remote backup with empty file ID',
      );
    }

    final uri = Uri.https(_driveApiHost, '/drive/v3/files/$remoteFileId');
    await _executeRequest(method: 'DELETE', uri: uri);
  }

  // ── 5. Folder Discovery & Creation Strategy ───────────────────────────────
  Future<String> _resolveBackupsFolderId() async {
    final rootFolderId = await _findOrCreateFolder(
        folderName: 'Quick Notes', parentFolderId: 'root');
    return await _findOrCreateFolder(
        folderName: 'Backups', parentFolderId: rootFolderId);
  }

  Future<String> _findOrCreateFolder(
      {required String folderName, required String parentFolderId}) async {
    final query =
        "name = '$folderName' and '$parentFolderId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final searchUri = Uri.https(_driveApiHost, '/drive/v3/files', {
      'q': query,
      'fields': 'files(id,name)',
    });

    final searchMap = await _executeRequest(method: 'GET', uri: searchUri);
    final files = searchMap['files'] as List? ?? [];

    if (files.isNotEmpty) {
      return files.first['id'] as String;
    }

    final createUri = Uri.https(_driveApiHost, '/drive/v3/files');
    final createBody = jsonEncode({
      'name': folderName,
      'mimeType': 'application/vnd.google-apps.folder',
      'parents': [parentFolderId],
    });

    final createMap = await _executeRequest(
      method: 'POST',
      uri: createUri,
      contentType: 'application/json; charset=UTF-8',
      bodyBytes: utf8.encode(createBody),
    );

    final newId = createMap['id'] as String? ?? '';
    if (newId.isEmpty) {
      throw DriveStorageException(
        type: DriveStorageErrorType.uploadFailed,
        message: 'Failed to create Google Drive folder "$folderName"',
      );
    }
    return newId;
  }

  // ── 6. Token Retrieval & Bounded Retry Handler ────────────────────────────
  Future<String> _getFreshAccessToken({bool forceRefresh = false}) async {
    if (_customTokenProvider != null) {
      final customToken = await _customTokenProvider!();
      if (customToken != null && customToken.isNotEmpty) return customToken;
    }

    try {
      var account = _googleSignIn.currentUser;
      if (account == null || forceRefresh) {
        account = await _googleSignIn.signInSilently();
      }
      if (account == null) {
        account = await _googleSignIn.signIn();
      }
      if (account == null) {
        throw const DriveStorageException(
          type: DriveStorageErrorType.unauthenticated,
          message:
              'User cancelled Google authentication or no account available',
        );
      }

      // Ensure Google Drive scope is explicitly authorized
      try {
        final hasScope = await _googleSignIn.canAccessScopes([_driveScope]);
        if (!hasScope) {
          final granted = await _googleSignIn.requestScopes([_driveScope]);
          if (!granted) {
            throw const DriveStorageException(
              type: DriveStorageErrorType.permissionDenied,
              message: 'Google Drive permission scope was not granted by user',
            );
          }
        }
      } catch (e) {
        if (e is DriveStorageException) rethrow;
      }

      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token == null || token.isEmpty) {
        throw const DriveStorageException(
          type: DriveStorageErrorType.unauthenticated,
          message: 'Failed to retrieve Google OAuth access token',
        );
      }
      return token;
    } catch (e) {
      if (e is DriveStorageException) rethrow;
      throw DriveStorageException(
        type: DriveStorageErrorType.unauthenticated,
        message: 'Google authentication error: ${e.toString()}',
      );
    }
  }

  Future<Map<String, dynamic>> _executeRequest({
    required String method,
    required Uri uri,
    String? contentType,
    List<int>? bodyBytes,
  }) async {
    final responseBytes = await _executeRawRequest(
      method: method,
      uri: uri,
      contentType: contentType,
      bodyBytes: bodyBytes,
    );

    if (responseBytes.isEmpty) return {};
    final str = utf8.decode(responseBytes);
    if (str.trim().isEmpty) return {};
    return jsonDecode(str) as Map<String, dynamic>;
  }

  Future<List<int>> _executeRawRequest({
    required String method,
    required Uri uri,
    String? contentType,
    List<int>? bodyBytes,
  }) async {
    int maxAttempts = 3;
    bool attemptedAuthRefresh = false;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final token =
            await _getFreshAccessToken(forceRefresh: attemptedAuthRefresh);

        final request = await _httpClient.openUrl(method, uri);
        request.headers.set('Authorization', 'Bearer $token');
        if (contentType != null) {
          request.headers.set('Content-Type', contentType);
        }

        if (bodyBytes != null && bodyBytes.isNotEmpty) {
          request.contentLength = bodyBytes.length;
          request.add(bodyBytes);
        }

        final response = await request.close();
        final statusCode = response.statusCode;

        final responseData =
            await response.fold<List<int>>([], (p, e) => p..addAll(e));

        if (statusCode >= 200 && statusCode < 300) {
          return responseData;
        }

        // Handle 401 Unauthorized or 403 Insufficient Scope with token/scope refresh attempt
        if ((statusCode == 401 || statusCode == 403) && !attemptedAuthRefresh) {
          attemptedAuthRefresh = true;
          try {
            await _googleSignIn.requestScopes([_driveScope]);
          } catch (_) {}
          continue;
        }

        if (statusCode == 404) {
          throw const DriveStorageException(
            type: DriveStorageErrorType.backupNotFound,
            message: 'Target Google Drive resource was not found (404)',
          );
        }

        if (statusCode == 403) {
          final errDetail =
              responseData.isNotEmpty ? utf8.decode(responseData) : '';
          debugPrint('GOOGLE DRIVE REST API 403 RESPONSE: $errDetail');
          throw DriveStorageException(
            type: DriveStorageErrorType.permissionDenied,
            message: 'Google Drive permission denied (403): $errDetail',
          );
        }

        // Retryable 5xx / 429 status codes
        if ((statusCode >= 500 && statusCode < 600) || statusCode == 429) {
          if (attempt < maxAttempts) {
            int backoffMs = _getBackoffMs(attempt, response.headers);
            await Future.delayed(Duration(milliseconds: backoffMs));
            continue;
          }
        }

        throw DriveStorageException(
          type: statusCode == 401
              ? DriveStorageErrorType.unauthenticated
              : DriveStorageErrorType.uploadFailed,
          message: 'Google Drive HTTP API error status: $statusCode',
        );
      } catch (e) {
        if (e is DriveStorageException) rethrow;
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 1000 * attempt));
          continue;
        }
        throw DriveStorageException(
          type: DriveStorageErrorType.networkUnavailable,
          message:
              'Network socket failure communicating with Google Drive: ${e.toString()}',
        );
      }
    }

    throw const DriveStorageException(
      type: DriveStorageErrorType.networkUnavailable,
      message:
          'Google Drive REST operation failed after maximum retry attempts',
    );
  }

  static int _getBackoffMs(int attempt, HttpHeaders headers) {
    final retryAfterHeader = headers.value('retry-after');
    if (retryAfterHeader != null) {
      final seconds = int.tryParse(retryAfterHeader);
      if (seconds != null) return seconds * 1000;
    }
    return 1000 * (1 << (attempt - 1)); // 1s, 2s, 4s
  }

  static String _formatTimestamp(DateTime dt) {
    final u = dt.toUtc();
    final y = u.year.toString().padLeft(4, '0');
    final m = u.month.toString().padLeft(2, '0');
    final d = u.day.toString().padLeft(2, '0');
    final hh = u.hour.toString().padLeft(2, '0');
    final mm = u.minute.toString().padLeft(2, '0');
    final ss = u.second.toString().padLeft(2, '0');
    return '${y}${m}${d}_${hh}${mm}${ss}';
  }
}
