import '../models/user_profile.dart';

/// ProfileRepository — Abstract interface for UserProfile persistence.
///
/// The existence of a UserProfile for a given userId is the sole source of
/// truth for whether a user has completed Quick Notes profile setup.
///
/// Implementations:
/// - [SqliteProfileRepository]: local SQLite storage (production).
abstract class ProfileRepository {
  /// Returns the UserProfile for [userId], or null if none exists.
  ///
  /// A null return value means the user has not yet completed profile setup.
  Future<UserProfile?> getProfileForUser(String userId);

  /// Persists [profile]. Creates a new record or updates an existing one.
  ///
  /// Uses upsert semantics — safe to call for both creation and editing.
  Future<void> saveProfile(UserProfile profile);

  /// Deletes the profile for [userId].
  ///
  /// After this call, [getProfileForUser] will return null for [userId].
  Future<void> deleteProfile(String userId);
}
