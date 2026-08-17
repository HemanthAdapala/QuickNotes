/// BackupFormat — Core constants and rules for Quick Notes Backup Format V1.
class BackupFormat {
  BackupFormat._();

  /// Format V1 version identifier.
  static const int formatVersion = 1;

  /// Current SQLite database schema version supported by this application.
  static const int databaseSchemaVersion = 18;

  /// Application release version string.
  static const String defaultAppVersion = '1.1.0+2';

  /// Standard file extension for Quick Notes backup archives.
  static const String fileExtension = '.qnb';

  /// Directory layout within the container archive.
  static const String manifestFileName = 'manifest.json';
  static const String dataDirectory = 'data';
  static const String attachmentsDirectory = 'attachments';

  static const String notesDataFileName = 'data/notes.json';
  static const String foldersDataFileName = 'data/folders.json';
  static const String tasksDataFileName = 'data/tasks.json';

  /// Relative URI scheme prefix used for portable asset references in backup payloads.
  static const String attachmentSchemePrefix = 'attachment://';

  /// Validates whether a format version is compatible with Format V1 deserializer.
  static bool isSupportedFormatVersion(int version) {
    return version == formatVersion;
  }
}
