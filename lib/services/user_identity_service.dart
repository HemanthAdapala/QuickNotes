import '../repositories/user_identity_repository.dart';

/// UserIdentityService — Single authority for resolving external provider credentials
/// (e.g., Google account ID) into canonical Quick Notes user IDs (`usr_...`).
class UserIdentityService {
  static final UserIdentityService _instance = UserIdentityService._internal();
  factory UserIdentityService() => _instance;
  UserIdentityService._internal();

  UserIdentityRepository _identityRepository = SqliteUserIdentityRepository();

  /// For testing injection
  void setRepositoryForTesting(UserIdentityRepository repository) {
    _identityRepository = repository;
  }

  /// Resolves an external provider account ID (e.g. Google UID) to a canonical `User.id`.
  ///
  /// - CASE A: If a mapping exists in `user_identities`, returns existing `userId` (canonical `usr_...`)
  ///   and updates `lastAuthenticatedAt`.
  /// - CASE B: If no mapping exists, atomically creates a new `User` (`usr_<uuid>`), `UserIdentity`,
  ///   and `UserProfile` inside `runInTransaction()` and returns the new canonical `userId`.
  Future<String> getOrCreateCanonicalUser({
    required String provider,
    required String providerUserId,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    final existingIdentity = await _identityRepository.findIdentity(provider, providerUserId);

    if (existingIdentity != null) {
      await _identityRepository.updateLastAuthenticatedAt(
        existingIdentity.id,
        DateTime.now(),
      );
      return existingIdentity.userId;
    }

    return await _identityRepository.createCanonicalUserWithIdentity(
      provider: provider,
      providerUserId: providerUserId,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
    );
  }
}
