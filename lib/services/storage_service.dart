import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';

class StorageService {
  /// Returns the size of the SQLite database in bytes.
  static Future<int> getDatabaseSize() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = join(documentsDirectory.path, 'quick_notes.db');
      final file = File(dbPath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      // Ignored
    }
    return 0;
  }

  /// Runs the VACUUM command to compact the SQLite database.
  static Future<void> compactDatabase() async {
    try {
      final db = await DatabaseService.instance.database;
      await db.execute('VACUUM');
    } catch (e) {
      // Ignored
    }
  }

  /// Returns the size of the application's temporary cache directory in bytes.
  static Future<int> getCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      return await _getDirSize(cacheDir);
    } catch (e) {
      return 0;
    }
  }

  /// Clears the application's temporary cache directory.
  static Future<void> clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        final entries = cacheDir.listSync(recursive: false);
        for (var entry in entries) {
          if (entry is File) {
            await entry.delete();
          } else if (entry is Directory) {
            await entry.delete(recursive: true);
          }
        }
      }
    } catch (e) {
      // Ignored
    }
  }

  /// Recursively calculates the size of a directory.
  static Future<int> _getDirSize(Directory dir) async {
    int size = 0;
    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            size += await entity.length();
          }
        }
      }
    } catch (e) {
      // Ignored
    }
    return size;
  }

  /// Helper to format bytes to a human-readable string (e.g. "2.4 MB")
  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}
