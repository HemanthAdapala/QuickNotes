import 'dart:io';
import 'backup_manifest.dart';
import 'remote_backup_metadata.dart';

/// BackupStorageAdapter — Provider-neutral abstract interface defining remote backup storage operations.
///
/// Decouples local BackupEngine / RestoreEngine logic from specific cloud providers (Google Drive, Dropbox, etc.).
abstract class BackupStorageAdapter {
  /// Uploads a local .qnb backup file to remote storage.
  Future<RemoteBackupMetadata> uploadBackup({
    required File localBackupFile,
    required BackupManifest manifest,
  });

  /// Lists all available remote .qnb backups for the active user.
  Future<List<RemoteBackupMetadata>> listBackups();

  /// Downloads a remote .qnb backup file to a local destination file.
  Future<File> downloadBackup({
    required String remoteFileId,
    required File destinationLocalFile,
  });

  /// Deletes a remote .qnb backup file from remote storage.
  Future<void> deleteBackup(String remoteFileId);
}
