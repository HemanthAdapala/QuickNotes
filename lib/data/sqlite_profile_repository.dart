import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';
import '../services/database_service.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite implementation of [ProfileRepository].
///
/// Uses the shared [DatabaseService] instance.
/// Profile existence (non-null return from [getProfileForUser]) is the
/// sole source of truth for profile completion status.
class SqliteProfileRepository implements ProfileRepository {
  static final SqliteProfileRepository _instance =
      SqliteProfileRepository._internal();
  factory SqliteProfileRepository() => _instance;
  SqliteProfileRepository._internal();

  Future<Database> get _db => DatabaseService.instance.database;

  @override
  Future<UserProfile?> getProfileForUser(String userId) async {
    final db = await _db;
    final maps = await db.query(
      'user_profiles',
      where: 'userId = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserProfile.fromMap(maps.first);
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final db = await _db;
    await db.insert(
      'user_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteProfile(String userId) async {
    final db = await _db;
    await db.delete(
      'user_profiles',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }
}
