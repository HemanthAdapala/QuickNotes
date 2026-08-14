/// User — Domain Entity representing canonical Quick Notes user identity.
///
/// Serves as the sole, stable ownership anchor ([id]) for all local and cloud entities
/// (notes, folders, tasks) decoupled from external authentication provider strings.
class User {
  /// Canonical Quick Notes User UUID (e.g., "usr_local_550e8400..." or "usr_550e8400...")
  final String id;

  /// True if the user operates in local offline mode; false once an external auth provider is linked.
  final bool isOffline;

  /// Timestamp when this canonical user record was created.
  final DateTime createdAt;

  /// Timestamp when this user record was last updated.
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.isOffline,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isOffline': isOffline ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      isOffline: (map['isOffline'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  User copyWith({
    String? id,
    bool? isOffline,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      isOffline: isOffline ?? this.isOffline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isOffline == other.isOffline;

  @override
  int get hashCode => id.hashCode ^ isOffline.hashCode;

  @override
  String toString() {
    return 'User(id: $id, isOffline: $isOffline, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
