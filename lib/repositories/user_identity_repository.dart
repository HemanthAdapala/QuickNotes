import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/identity_link_result.dart';
import '../models/user.dart';
import '../models/user_identity.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/session_manager.dart';

abstract class UserIdentityRepository {
  Future<UserIdentity?> findIdentity(String provider, String providerUserId);
  Future<UserIdentity?> findIdentityForUser(String userId, String provider);
  Future<User?> findUserById(String id);
  Future<void> updateLastAuthenticatedAt(String identityId, DateTime timestamp);
  Future<String> createCanonicalUserWithIdentity({
    required String provider,
    required String providerUserId,
    String? email,
    String? displayName,
    String? photoUrl,
  });
  Future<IdentityLinkResult> linkIdentityToActiveUser({
    required String activeUserId,
    required String provider,
    required String providerUserId,
    String? email,
    String? displayName,
    String? photoUrl,
  });
}

class SqliteUserIdentityRepository implements UserIdentityRepository {
  final DatabaseService _dbService;
  final Uuid _uuid;

  SqliteUserIdentityRepository({
    DatabaseService? dbService,
    Uuid? uuid,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _uuid = uuid ?? const Uuid();

  @override
  Future<UserIdentity?> findIdentity(
      String provider, String providerUserId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'user_identities',
      where: 'provider = ? AND providerUserId = ?',
      whereArgs: [provider, providerUserId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return UserIdentity.fromMap(maps.first);
  }

  @override
  Future<UserIdentity?> findIdentityForUser(
      String userId, String provider) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'user_identities',
      where: 'userId = ? AND provider = ?',
      whereArgs: [userId, provider],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return UserIdentity.fromMap(maps.first);
  }

  @override
  Future<User?> findUserById(String id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  @override
  Future<void> updateLastAuthenticatedAt(
      String identityId, DateTime timestamp) async {
    final db = await _dbService.database;
    await db.update(
      'user_identities',
      {'lastAuthenticatedAt': timestamp.toIso8601String()},
      where: 'id = ?',
      whereArgs: [identityId],
    );
  }

  @override
  Future<String> createCanonicalUserWithIdentity({
    required String provider,
    required String providerUserId,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    final now = DateTime.now();
    final canonicalUserId = 'usr_${_uuid.v4()}';
    final identityId = _uuid.v4();

    final user = User(
      id: canonicalUserId,
      isOffline: false,
      createdAt: now,
      updatedAt: now,
    );

    final userIdentity = UserIdentity(
      id: identityId,
      userId: canonicalUserId,
      provider: provider,
      providerUserId: providerUserId,
      email: email,
      createdAt: now,
      lastAuthenticatedAt: now,
    );

    final userProfile = UserProfile(
      userId: canonicalUserId,
      displayName: displayName ??
          (email != null && email.contains('@')
              ? email.split('@').first
              : 'QuickNotes User'),
      email: email ?? 'user@quicknotes.app',
      photoUrl: photoUrl,
      usesGooglePhoto: photoUrl != null && photoUrl.isNotEmpty,
      profileVersion: 1,
      createdAt: now,
      updatedAt: now,
    );

    await _dbService.runInTransaction((txn) async {
      await txn.insert('users', user.toMap());
      await txn.insert('user_identities', userIdentity.toMap());

      final existingProfiles = await txn.query(
        'user_profiles',
        where: 'userId = ?',
        whereArgs: [canonicalUserId],
      );

      if (existingProfiles.isEmpty) {
        await txn.insert('user_profiles', userProfile.toMap());
      }
    });

    return canonicalUserId;
  }

  @override
  Future<IdentityLinkResult> linkIdentityToActiveUser({
    required String activeUserId,
    required String provider,
    required String providerUserId,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final db = await _dbService.database;

      // STEP 1: Verify activeUserId exists in `users`
      final userMaps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [activeUserId],
        limit: 1,
      );

      if (userMaps.isEmpty) {
        if (activeUserId.startsWith('usr_local_')) {
          final now = DateTime.now();
          final nowIso = now.toIso8601String();
          await db.insert(
            'users',
            {
              'id': activeUserId,
              'isOffline': 1,
              'createdAt': nowIso,
              'updatedAt': nowIso,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          final existingProfile = await db.query(
            'user_profiles',
            where: 'userId = ?',
            whereArgs: [activeUserId],
            limit: 1,
          );
          if (existingProfile.isEmpty) {
            await db.insert(
              'user_profiles',
              {
                'userId': activeUserId,
                'displayName': 'Guest',
                'email': 'offline@local.quicknotes',
                'photoUrl': null,
                'usesGooglePhoto': 0,
                'profileVersion': 1,
                'createdAt': nowIso,
                'updatedAt': nowIso,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        } else {
          return IdentityLinkResult.userNotFound(activeUserId);
        }
      }

      // STEP 2: Check if this user already has an identity for this provider
      final userExistingIdentities = await db.query(
        'user_identities',
        where: 'userId = ? AND provider = ?',
        whereArgs: [activeUserId, provider],
        limit: 1,
      );

      if (userExistingIdentities.isNotEmpty) {
        final existingForUser =
            UserIdentity.fromMap(userExistingIdentities.first);
        if (existingForUser.providerUserId == providerUserId) {
          // STEP 5: Same Google identity already linked to same user
          await updateLastAuthenticatedAt(existingForUser.id, DateTime.now());
          return IdentityLinkResult.alreadyLinked(
            userId: activeUserId,
            identity: existingForUser,
          );
        } else {
          return IdentityLinkResult.alreadyLinkedToDifferentIdentity(
            activeUserId: activeUserId,
            existingProviderUserId: existingForUser.providerUserId,
            targetGoogleId: providerUserId,
          );
        }
      }

      // STEP 3: Find if provider identity already exists anywhere in `user_identities`
      final identityMaps = await db.query(
        'user_identities',
        where: 'provider = ? AND providerUserId = ?',
        whereArgs: [provider, providerUserId],
        limit: 1,
      );

      if (identityMaps.isNotEmpty) {
        final existingIdentity = UserIdentity.fromMap(identityMaps.first);
        if (existingIdentity.userId != activeUserId) {
          // STEP 6: Identity belongs to a DIFFERENT user -> CONFLICT
          return IdentityLinkResult.conflict(
            activeUserId: activeUserId,
            conflictingUserId: existingIdentity.userId,
            googleId: providerUserId,
          );
        } else {
          return IdentityLinkResult.alreadyLinked(
            userId: activeUserId,
            identity: existingIdentity,
          );
        }
      }

      // STEP 4: Google identity does not exist -> Atomic link & promotion transaction
      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      final identityId = _uuid.v4();

      final newIdentity = UserIdentity(
        id: identityId,
        userId: activeUserId,
        provider: provider,
        providerUserId: providerUserId,
        email: email,
        createdAt: now,
        lastAuthenticatedAt: now,
      );

      late UserProfile updatedProfile;

      await _dbService.runInTransaction((txn) async {
        // 1. Insert user_identities
        await txn.insert('user_identities', newIdentity.toMap());

        // 2. Update users: isOffline = 0
        await txn.update(
          'users',
          {
            'isOffline': 0,
            'updatedAt': nowIso,
          },
          where: 'id = ?',
          whereArgs: [activeUserId],
        );

        // 3. Update or Insert user_profiles with Google profile metadata
        final profileMaps = await txn.query(
          'user_profiles',
          where: 'userId = ?',
          whereArgs: [activeUserId],
          limit: 1,
        );

        if (profileMaps.isNotEmpty) {
          final existingProfile = UserProfile.fromMap(profileMaps.first);
          // Profile rule: If user has a custom name (not default 'Guest' or empty), preserve it
          final isDefaultOfflineName = existingProfile.displayName == 'Guest' ||
              existingProfile.displayName.trim().isEmpty;

          final effectiveDisplayName = isDefaultOfflineName
              ? (displayName ??
                  (email != null && email.contains('@')
                      ? email.split('@').first
                      : 'QuickNotes User'))
              : existingProfile.displayName;

          final effectiveEmail = email ?? existingProfile.email;
          final effectivePhotoUrl = photoUrl ?? existingProfile.photoUrl;
          final effectiveUsesGooglePhoto =
              photoUrl != null && photoUrl.isNotEmpty
                  ? true
                  : existingProfile.usesGooglePhoto;

          updatedProfile = existingProfile.copyWith(
            displayName: effectiveDisplayName,
            email: effectiveEmail,
            photoUrl: effectivePhotoUrl,
            usesGooglePhoto: effectiveUsesGooglePhoto,
            updatedAt: now,
          );

          await txn.update(
            'user_profiles',
            updatedProfile.toMap(),
            where: 'userId = ?',
            whereArgs: [activeUserId],
          );
        } else {
          updatedProfile = UserProfile(
            userId: activeUserId,
            displayName: displayName ??
                (email != null && email.contains('@')
                    ? email.split('@').first
                    : 'QuickNotes User'),
            email: email ?? 'user@quicknotes.app',
            photoUrl: photoUrl,
            usesGooglePhoto: photoUrl != null && photoUrl.isNotEmpty,
            profileVersion: 1,
            createdAt: now,
            updatedAt: now,
          );

          await txn.insert('user_profiles', updatedProfile.toMap());
        }
      });

      return IdentityLinkResult.linked(
        userId: activeUserId,
        identity: newIdentity,
        profile: updatedProfile,
      );
    } catch (e) {
      return IdentityLinkResult.failure(
        'Failed to link Google identity: ${e.toString()}',
      );
    }
  }
}
