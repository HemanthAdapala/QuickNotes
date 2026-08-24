import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/recovery/local_data_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('LocalDataDetector & LocalDataSummary Unit Tests', () {
    late Database db;
    late LocalDataDetector detector;
    final testUserIdA = 'usr_test_${const Uuid().v4()}';
    final testUserIdB = 'usr_test_${const Uuid().v4()}';

    setUp(() async {
      db = await DatabaseService.instance.database;

      // Clean tables
      await db.delete('notes');
      await db.delete('folders');
      await db.delete('tasks');

      detector = LocalDataDetector(
        dbService: DatabaseService.instance,
      );
    });

    test('1. Zero active notes/folders/tasks yields empty summary with hasData = false', () async {
      final summary = await detector.detectLocalData(userId: testUserIdA);

      expect(summary.noteCount, equals(0));
      expect(summary.folderCount, equals(0));
      expect(summary.taskCount, equals(0));
      expect(summary.totalCount, equals(0));
      expect(summary.hasData, isFalse);
    });

    test('2. Active notes for active user are counted accurately', () async {
      final nowIso = DateTime.now().toIso8601String();
      await db.insert('notes', {
        'id': 'note_1',
        'userId': testUserIdA,
        'title': 'Note 1',
        'content': 'Content 1',
        'isDeleted': 0,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'version': 1,
        'lastSyncedVersion': 0,
      });
      await db.insert('notes', {
        'id': 'note_2',
        'userId': testUserIdA,
        'title': 'Note 2',
        'content': 'Content 2',
        'isDeleted': 0,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'version': 1,
        'lastSyncedVersion': 0,
      });

      final summary = await detector.detectLocalData(userId: testUserIdA);

      expect(summary.noteCount, equals(2));
      expect(summary.folderCount, equals(0));
      expect(summary.taskCount, equals(0));
      expect(summary.totalCount, equals(2));
      expect(summary.hasData, isTrue);
    });

    test('3. Active folders for active user are counted accurately', () async {
      final nowIso = DateTime.now().toIso8601String();
      await db.insert('folders', {
        'id': 'folder_1',
        'userId': testUserIdA,
        'name': 'Work',
        'isDeleted': 0,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'version': 1,
        'lastSyncedVersion': 0,
      });

      final summary = await detector.detectLocalData(userId: testUserIdA);

      expect(summary.noteCount, equals(0));
      expect(summary.folderCount, equals(1));
      expect(summary.taskCount, equals(0));
      expect(summary.totalCount, equals(1));
      expect(summary.hasData, isTrue);
    });

    test('4. Active tasks for active user are counted accurately', () async {
      final nowIso = DateTime.now().toIso8601String();
      await db.insert('tasks', {
        'id': 'task_1',
        'userId': testUserIdA,
        'title': 'Task 1',
        'dueDate': nowIso,
        'isDeleted': 0,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'version': 1,
        'lastSyncedVersion': 0,
      });

      final summary = await detector.detectLocalData(userId: testUserIdA);

      expect(summary.noteCount, equals(0));
      expect(summary.folderCount, equals(0));
      expect(summary.taskCount, equals(1));
      expect(summary.totalCount, equals(1));
      expect(summary.hasData, isTrue);
    });

    test('5. Soft-deleted / trashed records are strictly excluded from counts', () async {
      final nowIso = DateTime.now().toIso8601String();
      await db.insert('notes', {
        'id': 'note_active',
        'userId': testUserIdA,
        'title': 'Active',
        'isDeleted': 0,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'version': 1,
        'lastSyncedVersion': 0,
      });
      await db.insert('notes', {
        'id': 'note_trashed',
        'userId': testUserIdA,
        'title': 'Trashed',
        'isDeleted': 1,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'version': 1,
        'lastSyncedVersion': 0,
      });
      await db.insert('folders', {
        'id': 'folder_trashed',
        'userId': testUserIdA,
        'name': 'Trashed Folder',
        'isDeleted': 1,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'version': 1,
        'lastSyncedVersion': 0,
      });
      await db.insert('tasks', {
        'id': 'task_trashed',
        'userId': testUserIdA,
        'title': 'Trashed Task',
        'dueDate': nowIso,
        'isDeleted': 1,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'version': 1,
        'lastSyncedVersion': 0,
      });

      final summary = await detector.detectLocalData(userId: testUserIdA);

      expect(summary.noteCount, equals(1));
      expect(summary.folderCount, equals(0));
      expect(summary.taskCount, equals(0));
      expect(summary.totalCount, equals(1));
    });

    test('6. Multi-tenant isolation: Other user records are strictly excluded', () async {
      final nowIso = DateTime.now().toIso8601String();
      await db.insert('notes', {
        'id': 'note_user_b',
        'userId': testUserIdB,
        'title': 'User B Note',
        'isDeleted': 0,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'version': 1,
        'lastSyncedVersion': 0,
      });
      await db.insert('folders', {
        'id': 'folder_user_b',
        'userId': testUserIdB,
        'name': 'User B Folder',
        'isDeleted': 0,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'version': 1,
        'lastSyncedVersion': 0,
      });

      final summaryA = await detector.detectLocalData(userId: testUserIdA);
      final summaryB = await detector.detectLocalData(userId: testUserIdB);

      expect(summaryA.totalCount, equals(0));
      expect(summaryA.hasData, isFalse);

      expect(summaryB.noteCount, equals(1));
      expect(summaryB.folderCount, equals(1));
      expect(summaryB.totalCount, equals(2));
      expect(summaryB.hasData, isTrue);
    });

    test('7. Null or empty userId returns empty summary without error', () async {
      final summaryNull = await detector.detectLocalData(userId: null);
      final summaryEmpty = await detector.detectLocalData(userId: '   ');

      expect(summaryNull.hasData, isFalse);
      expect(summaryEmpty.hasData, isFalse);
    });
  });
}
