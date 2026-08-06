enum SessionType {
  google,
  offline,
  apple,
  email,
  guest,
}

extension SessionTypeExtension on SessionType {
  String toValue() {
    return name;
  }

  static SessionType fromValue(String? value) {
    switch (value) {
      case 'google':
        return SessionType.google;
      case 'apple':
        return SessionType.apple;
      case 'email':
        return SessionType.email;
      case 'guest':
        return SessionType.guest;
      case 'offline':
      default:
        return SessionType.offline;
    }
  }
}
