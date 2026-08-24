import 'session_type.dart';

class CurrentUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final SessionType sessionType;
  final bool isOffline;
  final DateTime createdAt;

  const CurrentUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.sessionType,
    required this.isOffline,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'sessionType': sessionType.toValue(),
      'isOffline': isOffline,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      sessionType:
          SessionTypeExtension.fromValue(json['sessionType'] as String?),
      isOffline: json['isOffline'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  CurrentUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    SessionType? sessionType,
    bool? isOffline,
    DateTime? createdAt,
  }) {
    return CurrentUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      sessionType: sessionType ?? this.sessionType,
      isOffline: isOffline ?? this.isOffline,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
