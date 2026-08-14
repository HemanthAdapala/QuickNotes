import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../models/user_identity.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';

abstract class UserIdentityRepository {
  Future<UserIdentity?> findIdentity(String provider, String providerUserId);
  Future<User?> findUserById(String id);
  Future<void> updateLastAuthenticatedAt(String identityId, DateTime timestamp);
  Future<String> createCanonicalUserWithIdentity({
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
  Future<UserIdentity?> findIdentity(String provider, String providerUserId) async {
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
  Future<void> updateLastAuthenticatedAt(String identityId, DateTime timestamp) async {
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
      displayName: displayName ?? (email != null && email.contains('@') ? email.split('@').first : 'QuickNotes User'),
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
}
