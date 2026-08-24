import 'user_identity.dart';
import 'user_profile.dart';

/// Status outcomes for identity linking operations.
enum IdentityLinkStatus {
  /// Successfully linked the external identity to the active user in-place.
  linked,

  /// The active user is already linked to this exact external identity.
  alreadyLinked,

  /// The external identity is already linked to a different canonical user.
  conflict,

  /// The active user ID was not found in the database.
  userNotFound,

  /// The active user is already linked to a different identity under the same provider.
  alreadyLinkedToDifferentIdentity,

  /// An unrecoverable failure or transaction error occurred.
  failure,
}

/// Domain Result model representing the outcome of linking an external identity
/// (e.g. Google OAuth account) to an active canonical user.
class IdentityLinkResult {
  final IdentityLinkStatus status;
  final String? userId;
  final UserIdentity? identity;
  final UserProfile? profile;
  final String? conflictingUserId;
  final String? errorMessage;

  const IdentityLinkResult({
    required this.status,
    this.userId,
    this.identity,
    this.profile,
    this.conflictingUserId,
    this.errorMessage,
  });

  /// True if the identity is successfully linked or was already linked to the active user.
  bool get isSuccess =>
      status == IdentityLinkStatus.linked ||
      status == IdentityLinkStatus.alreadyLinked;

  /// True if an identity collision occurred with another canonical user.
  bool get isConflict => status == IdentityLinkStatus.conflict;

  factory IdentityLinkResult.linked({
    required String userId,
    required UserIdentity identity,
    required UserProfile profile,
  }) {
    return IdentityLinkResult(
      status: IdentityLinkStatus.linked,
      userId: userId,
      identity: identity,
      profile: profile,
    );
  }

  factory IdentityLinkResult.alreadyLinked({
    required String userId,
    required UserIdentity identity,
  }) {
    return IdentityLinkResult(
      status: IdentityLinkStatus.alreadyLinked,
      userId: userId,
      identity: identity,
    );
  }

  factory IdentityLinkResult.conflict({
    required String activeUserId,
    required String conflictingUserId,
    required String googleId,
  }) {
    return IdentityLinkResult(
      status: IdentityLinkStatus.conflict,
      userId: activeUserId,
      conflictingUserId: conflictingUserId,
      errorMessage:
          'Google identity $googleId is already linked to existing user $conflictingUserId',
    );
  }

  factory IdentityLinkResult.userNotFound(String activeUserId) {
    return IdentityLinkResult(
      status: IdentityLinkStatus.userNotFound,
      userId: activeUserId,
      errorMessage: 'Active user $activeUserId not found in database',
    );
  }

  factory IdentityLinkResult.alreadyLinkedToDifferentIdentity({
    required String activeUserId,
    required String existingProviderUserId,
    required String targetGoogleId,
  }) {
    return IdentityLinkResult(
      status: IdentityLinkStatus.alreadyLinkedToDifferentIdentity,
      userId: activeUserId,
      errorMessage:
          'User $activeUserId is already linked to Google identity $existingProviderUserId, cannot link to $targetGoogleId',
    );
  }

  factory IdentityLinkResult.failure(String errorMessage) {
    return IdentityLinkResult(
      status: IdentityLinkStatus.failure,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() {
    return 'IdentityLinkResult(status: $status, userId: $userId, conflict: $conflictingUserId, error: $errorMessage)';
  }
}
