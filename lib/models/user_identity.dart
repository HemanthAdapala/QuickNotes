/// UserIdentity — Domain Entity representing external authentication provider linkage.
///
/// Maps external authentication provider credentials (e.g. Google OAuth UID) to a
/// canonical Quick Notes [userId].
class UserIdentity {
  /// Unique identifier for this identity record (UUID v4)
  final String id;

  /// Foreign key linking to canonical [User.id]
  final String userId;

  /// Provider name e.g. "google", "apple", "microsoft", "email"
  final String provider;

  /// External OAuth UID or sub claim (e.g., Google account ID)
  final String providerUserId;

  /// External provider email address (if available)
  final String? email;

  /// Timestamp when this identity linkage was established
  final DateTime createdAt;

  /// Timestamp when the user last authenticated via this provider
  final DateTime lastAuthenticatedAt;

  const UserIdentity({
    required this.id,
    required this.userId,
    required this.provider,
    required this.providerUserId,
    this.email,
    required this.createdAt,
    required this.lastAuthenticatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'provider': provider,
      'providerUserId': providerUserId,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'lastAuthenticatedAt': lastAuthenticatedAt.toIso8601String(),
    };
  }

  factory UserIdentity.fromMap(Map<String, dynamic> map) {
    return UserIdentity(
      id: map['id'] as String,
      userId: map['userId'] as String,
      provider: map['provider'] as String,
      providerUserId: map['providerUserId'] as String,
      email: map['email'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastAuthenticatedAt: DateTime.parse(map['lastAuthenticatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserIdentity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          provider == other.provider &&
          providerUserId == other.providerUserId;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      provider.hashCode ^
      providerUserId.hashCode;

  @override
  String toString() {
    return 'UserIdentity(id: $id, userId: $userId, provider: $provider, providerUserId: $providerUserId, email: $email)';
  }
}
