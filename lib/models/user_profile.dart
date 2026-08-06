/// UserProfile — Application-level user profile entity.
///
/// Existence of a UserProfile for a given userId is the single source of truth
/// for whether a user has completed the Quick Notes profile setup flow.
///
/// Design principles:
/// - avatarId is a logical identifier (e.g. "andre"), never an asset path.
///   Use AvatarRegistry.assetPath(avatarId) to resolve the display asset.
/// - usesGooglePhoto controls whether the Google account photo is displayed
///   or whether the user has selected a custom illustrated avatar.
/// - profileVersion supports non-destructive schema migrations.
class UserProfile {
  final String userId;
  final String displayName;
  final String email;

  /// Logical avatar identifier — e.g. "andre", "elsa".
  /// Resolve to asset path via AvatarRegistry.assetPath(avatarId).
  /// Null if the user has not yet selected a custom avatar.
  final String? avatarId;

  /// Google profile photo URL. May become stale if the user changes their
  /// Google account photo. Consult [usesGooglePhoto] before displaying.
  final String? photoUrl;

  /// When true, Quick Notes always renders the latest Google account photo.
  /// When false, the user has explicitly chosen a custom illustrated avatar
  /// and Google photo changes should be ignored.
  final bool usesGooglePhoto;

  /// Schema version. Increment when adding new fields that require migration.
  /// Current version: 1.
  final int profileVersion;

  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.email,
    this.avatarId,
    this.photoUrl,
    this.usesGooglePhoto = true,
    this.profileVersion = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy of this profile with specified fields overridden.
  UserProfile copyWith({
    String? userId,
    String? displayName,
    String? email,
    String? avatarId,
    String? photoUrl,
    bool? usesGooglePhoto,
    int? profileVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarId: avatarId ?? this.avatarId,
      photoUrl: photoUrl ?? this.photoUrl,
      usesGooglePhoto: usesGooglePhoto ?? this.usesGooglePhoto,
      profileVersion: profileVersion ?? this.profileVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serialize to SQLite-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'avatarId': avatarId,
      'photoUrl': photoUrl,
      'usesGooglePhoto': usesGooglePhoto ? 1 : 0,
      'profileVersion': profileVersion,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Deserialize from SQLite row.
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['userId'] as String,
      displayName: map['displayName'] as String,
      email: map['email'] as String,
      avatarId: map['avatarId'] as String?,
      photoUrl: map['photoUrl'] as String?,
      usesGooglePhoto: (map['usesGooglePhoto'] as int) == 1,
      profileVersion: map['profileVersion'] as int? ?? 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  @override
  String toString() =>
      'UserProfile(userId: $userId, displayName: $displayName, '
      'avatarId: $avatarId, usesGooglePhoto: $usesGooglePhoto, '
      'profileVersion: $profileVersion)';
}
