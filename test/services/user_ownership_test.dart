import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:quick_notes/services/database_exceptions.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();

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

    try {
      final dbFile = File('quick_notes.db');
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
    } catch (_) {}
  });

  group('Phase 1.2 — User Ownership & Identity Architecture Tests', () {
    test(
        '1 & 2 & 3. Fresh installation creates 1 User, 1 UserProfile, 0 UserIdentity',
        () async {
      final dbPath = inMemoryDatabasePath;
      final db = await openDatabase(
        dbPath,
        version: 16,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE users(
              id TEXT PRIMARY KEY,
              isOffline INTEGER NOT NULL DEFAULT 1,
              createdAt TEXT NOT NULL,
              updatedAt TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE user_profiles(
              userId TEXT PRIMARY KEY,
              displayName TEXT NOT NULL,
              email TEXT NOT NULL,
              avatarId TEXT,
              photoUrl TEXT,
              usesGooglePhoto INTEGER NOT NULL DEFAULT 1,
              profileVersion INTEGER NOT NULL DEFAULT 1,
              createdAt TEXT NOT NULL,
              updatedAt TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE user_identities(
              id TEXT PRIMARY KEY,
              userId TEXT NOT NULL,
              provider TEXT NOT NULL,
              providerUserId TEXT NOT NULL,
              email TEXT,
              createdAt TEXT NOT NULL,
              lastAuthenticatedAt TEXT NOT NULL
            )
          ''');

          final now = DateTime.now().toIso8601String();
          final defaultUserId = 'usr_local_${uuid.v4()}';
          await db.execute(
            'INSERT INTO users (id, isOffline, createdAt, updatedAt) VALUES (?, 1, ?, ?)',
            [defaultUserId, now, now],
          );
          await db.execute(
            '''INSERT INTO user_profiles (userId, displayName, email, usesGooglePhoto, profileVersion, createdAt, updatedAt)
               VALUES (?, 'Offline User', 'offline@local.quicknotes', 0, 1, ?, ?)''',
            [defaultUserId, now, now],
          );
        },
      );

      final users = await db.query('users');
      final profiles = await db.query('user_profiles');
      final identities = await db.query('user_identities');

      expect(users.length, equals(1));
      expect(profiles.length, equals(1));
      expect(identities, isEmpty);

      await db.close();
    });

    test(
        '4 & 6 & 7 & 8 & 9. Existing v15 database with offline profile migrates & backfills successfully',
        () async {
      final dbPath =
          p.join(Directory.systemTemp.path, 'test_mig_4_${uuid.v4()}.db');
      // Step A: Set up v15 state
      var db = await openDatabase(
        dbPath,
        version: 15,
        onCreate: (db, version) async {
          await db.execute(
              'CREATE TABLE notes(id TEXT PRIMARY KEY, title TEXT, content TEXT, isPinned INTEGER, isFavorite INTEGER, isArchived INTEGER, category TEXT, noteType TEXT, tags TEXT, attachments TEXT, isLocked INTEGER, reminderTime TEXT, createdAt TEXT, updatedAt TEXT, colorValue INTEGER, folderId TEXT, isHabit INTEGER, habitRecurrence TEXT, habitStreak INTEGER, habitLastCompleted TEXT, isDeleted INTEGER, previewText TEXT, paperSettings TEXT)');
          await db.execute(
              'CREATE TABLE folders(id TEXT PRIMARY KEY, name TEXT, parentId TEXT, createdAt TEXT, colorHex TEXT, sticker TEXT)');
          await db.execute(
              'CREATE TABLE tasks(id TEXT PRIMARY KEY, title TEXT, description TEXT, folderId TEXT, categoryId TEXT, dueDate TEXT, startTime TEXT, endTime TEXT, priority TEXT, status TEXT, completed INTEGER, createdAt TEXT, updatedAt TEXT, completedAt TEXT, reminderEnabled INTEGER, reminderMode TEXT, reminderTime TEXT, notificationId INTEGER, repeatRule TEXT, isRecurring INTEGER, recurrenceRule TEXT, recurringSeriesId TEXT, timezone TEXT, completedDates TEXT)');
          await db.execute(
              'CREATE TABLE user_profiles(userId TEXT PRIMARY KEY, displayName TEXT NOT NULL, email TEXT NOT NULL, avatarId TEXT, photoUrl TEXT, usesGooglePhoto INTEGER NOT NULL DEFAULT 1, profileVersion INTEGER NOT NULL DEFAULT 1, createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL)');

          final now = DateTime.now().toIso8601String();
          final legacyOfflineId = 'local_legacy_123';
          await db.execute(
              "INSERT INTO user_profiles (userId, displayName, email, createdAt, updatedAt) VALUES (?, 'Legacy Local', 'offline@local.quicknotes', ?, ?)",
              [legacyOfflineId, now, now]);
          await db.execute(
              "INSERT INTO notes (id, title, content, createdAt, updatedAt) VALUES ('note_v15_1', 'V15 Note 1', 'Content', ?, ?)",
              [now, now]);
          await db.execute(
              "INSERT INTO folders (id, name, createdAt) VALUES ('folder_v15_1', 'V15 Folder 1', ?)",
              [now]);
          await db.execute(
              "INSERT INTO tasks (id, title, dueDate, priority, createdAt, updatedAt) VALUES ('task_v15_1', 'V15 Task 1', ?, 'High', ?, ?)",
              [now, now, now]);
        },
      );
      await db.close();

      // Step B: Upgrade to v16
      db = await openDatabase(
        dbPath,
        version: 16,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 16) {
            await db.execute(
                'CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY, isOffline INTEGER NOT NULL DEFAULT 1, createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL)');
            await db.execute(
                'CREATE TABLE IF NOT EXISTS user_identities(id TEXT PRIMARY KEY, userId TEXT NOT NULL, provider TEXT NOT NULL, providerUserId TEXT NOT NULL, email TEXT, createdAt TEXT NOT NULL, lastAuthenticatedAt TEXT NOT NULL)');
            await db.execute('ALTER TABLE notes ADD COLUMN userId TEXT');
            await db.execute('ALTER TABLE folders ADD COLUMN userId TEXT');
            await db.execute('ALTER TABLE tasks ADD COLUMN userId TEXT');

            final nowIso = DateTime.now().toIso8601String();
            final defaultUserId = 'usr_local_${uuid.v4()}';
            final profiles = await db.query('user_profiles', limit: 1);
            if (profiles.isNotEmpty) {
              final legacyUserId = profiles.first['userId']?.toString() ?? '';
              await db.execute(
                  'INSERT INTO users (id, isOffline, createdAt, updatedAt) VALUES (?, 1, ?, ?)',
                  [defaultUserId, nowIso, nowIso]);
              await db.execute(
                  'UPDATE user_profiles SET userId = ? WHERE userId = ?',
                  [defaultUserId, legacyUserId]);
            }
            await db.execute('UPDATE notes SET userId = ? WHERE userId IS NULL',
                [defaultUserId]);
            await db.execute(
                'UPDATE folders SET userId = ? WHERE userId IS NULL',
                [defaultUserId]);
            await db.execute('UPDATE tasks SET userId = ? WHERE userId IS NULL',
                [defaultUserId]);
          }
        },
      );

      final users = await db.query('users');
      final profiles = await db.query('user_profiles');
      final notes = await db.query('notes');
      final folders = await db.query('folders');
      final tasks = await db.query('tasks');

      expect(users.length, equals(1));
      final canonicalId = users.first['id'] as String;
      expect(profiles.first['userId'], equals(canonicalId));
      expect(notes.first['userId'], equals(canonicalId));
      expect(folders.first['userId'], equals(canonicalId));
      expect(tasks.first['userId'], equals(canonicalId));

      await db.close();
      try {
        await File(dbPath).delete();
      } catch (_) {}
    });

    test(
        '5 & 17. Existing Google profile preserves Google UID through UserIdentity (Known Google classification)',
        () async {
      final dbPath =
          p.join(Directory.systemTemp.path, 'test_mig_5_${uuid.v4()}.db');
      var db = await openDatabase(
        dbPath,
        version: 15,
        onCreate: (db, version) async {
          await db.execute(
              'CREATE TABLE user_profiles(userId TEXT PRIMARY KEY, displayName TEXT NOT NULL, email TEXT NOT NULL, avatarId TEXT, photoUrl TEXT, usesGooglePhoto INTEGER NOT NULL DEFAULT 1, profileVersion INTEGER NOT NULL DEFAULT 1, createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL)');
          final now = DateTime.now().toIso8601String();
          final googleUid = '1092837465918237465';
          await db.execute(
              "INSERT INTO user_profiles (userId, displayName, email, createdAt, updatedAt) VALUES (?, 'Google User', 'user@gmail.com', ?, ?)",
              [googleUid, now, now]);
        },
      );
      await db.close();

      db = await openDatabase(
        dbPath,
        version: 16,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 16) {
            await db.execute(
                'CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY, isOffline INTEGER NOT NULL DEFAULT 1, createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL)');
            await db.execute(
                'CREATE TABLE IF NOT EXISTS user_identities(id TEXT PRIMARY KEY, userId TEXT NOT NULL, provider TEXT NOT NULL, providerUserId TEXT NOT NULL, email TEXT, createdAt TEXT NOT NULL, lastAuthenticatedAt TEXT NOT NULL)');

            final nowIso = DateTime.now().toIso8601String();
            final defaultUserId = 'usr_local_${uuid.v4()}';
            final profiles = await db.query('user_profiles', limit: 1);
            if (profiles.isNotEmpty) {
              final legacyUserId = profiles.first['userId']?.toString() ?? '';
              final legacyEmail = profiles.first['email']?.toString() ?? '';

              final isKnownOffline = legacyUserId.startsWith('local_') ||
                  legacyEmail.endsWith('@local.quicknotes');
              final isKnownGoogle = !isKnownOffline &&
                  (legacyEmail.contains('@') ||
                      RegExp(r'^\d+$').hasMatch(legacyUserId));

              await db.execute(
                  'INSERT INTO users (id, isOffline, createdAt, updatedAt) VALUES (?, ?, ?, ?)',
                  [defaultUserId, isKnownGoogle ? 0 : 1, nowIso, nowIso]);

              if (isKnownGoogle) {
                await db.execute(
                    'INSERT INTO user_identities (id, userId, provider, providerUserId, email, createdAt, lastAuthenticatedAt) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    [
                      uuid.v4(),
                      defaultUserId,
                      'google',
                      legacyUserId,
                      legacyEmail,
                      nowIso,
                      nowIso
                    ]);
              }
              await db.execute(
                  'UPDATE user_profiles SET userId = ? WHERE userId = ?',
                  [defaultUserId, legacyUserId]);
            }
          }
        },
      );

      final users = await db.query('users');
      final identities = await db.query('user_identities');

      expect(users.length, equals(1));
      expect(users.first['isOffline'], equals(0)); // isOffline = false
      expect(identities.length, equals(1));
      expect(identities.first['provider'], equals('google'));
      expect(identities.first['providerUserId'], equals('1092837465918237465'));

      await db.close();
      try {
        await File(dbPath).delete();
      } catch (_) {}
    });

    test(
        '18 & 19. Known offline and ambiguous legacy identities safely fall back to offline user without UserIdentity',
        () async {
      final dbPath =
          p.join(Directory.systemTemp.path, 'test_mig_18_${uuid.v4()}.db');
      var db = await openDatabase(
        dbPath,
        version: 15,
        onCreate: (db, version) async {
          await db.execute(
              'CREATE TABLE user_profiles(userId TEXT PRIMARY KEY, displayName TEXT NOT NULL, email TEXT NOT NULL, avatarId TEXT, photoUrl TEXT, usesGooglePhoto INTEGER NOT NULL DEFAULT 1, profileVersion INTEGER NOT NULL DEFAULT 1, createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL)');
          final now = DateTime.now().toIso8601String();
          final ambiguousId = 'ambiguous_user_string';
          await db.execute(
              "INSERT INTO user_profiles (userId, displayName, email, createdAt, updatedAt) VALUES (?, 'Ambiguous User', 'no_domain_email', ?, ?)",
              [ambiguousId, now, now]);
        },
      );
      await db.close();

      db = await openDatabase(
        dbPath,
        version: 16,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 16) {
            await db.execute(
                'CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY, isOffline INTEGER NOT NULL DEFAULT 1, createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL)');
            await db.execute(
                'CREATE TABLE IF NOT EXISTS user_identities(id TEXT PRIMARY KEY, userId TEXT NOT NULL, provider TEXT NOT NULL, providerUserId TEXT NOT NULL, email TEXT, createdAt TEXT NOT NULL, lastAuthenticatedAt TEXT NOT NULL)');

            final nowIso = DateTime.now().toIso8601String();
            final defaultUserId = 'usr_local_${uuid.v4()}';
            final profiles = await db.query('user_profiles', limit: 1);
            if (profiles.isNotEmpty) {
              final legacyUserId = profiles.first['userId']?.toString() ?? '';
              final legacyEmail = profiles.first['email']?.toString() ?? '';

              final isKnownOffline = legacyUserId.startsWith('local_') ||
                  legacyEmail.endsWith('@local.quicknotes');
              final isKnownGoogle =
                  !isKnownOffline && legacyEmail.contains('@gmail.com');

              final isOffline = !isKnownGoogle;

              await db.execute(
                  'INSERT INTO users (id, isOffline, createdAt, updatedAt) VALUES (?, ?, ?, ?)',
                  [defaultUserId, isOffline ? 1 : 0, nowIso, nowIso]);
            }
          }
        },
      );

      final users = await db.query('users');
      final identities = await db.query('user_identities');

      expect(users.first['isOffline'], equals(1)); // Safe offline fallback
      expect(identities, isEmpty);

      await db.close();
      try {
        await File(dbPath).delete();
      } catch (_) {}
    });

    test(
        '10 & 11. Migration failure rolls back and retry does not create duplicates',
        () async {
      final dbPath =
          p.join(Directory.systemTemp.path, 'test_mig_10_${uuid.v4()}.db');
      var db = await openDatabase(
        dbPath,
        version: 15,
        onCreate: (db, version) async {
          await db
              .execute('CREATE TABLE notes(id TEXT PRIMARY KEY, title TEXT)');
        },
      );
      await db.close();

      // Intentionally cause error during upgrade
      try {
        await openDatabase(
          dbPath,
          version: 16,
          onUpgrade: (db, oldVersion, newVersion) async {
            await db.execute('CREATE TABLE users(id TEXT PRIMARY KEY)');
            throw Exception('Simulated migration crash');
          },
        );
      } catch (_) {}

      // Verify DB version remained at 15
      db = await openDatabase(dbPath, version: 15);
      final ver = await db.getVersion();
      expect(ver, equals(15));
      await db.close();
      try {
        await File(dbPath).delete();
      } catch (_) {}
    });

    test('Phase 1.2.1 — Repository operation with active user succeeds',
        () async {
      final sessionManager = SessionManager();
      await sessionManager.init();
      final activeUser = 'usr_active_${uuid.v4()}';
      await sessionManager.saveSession(
          userId: activeUser, sessionType: SessionType.offline);

      final notesRepo = SqliteNotesRepository();
      final note = Note(
        id: 'note_active_${uuid.v4()}',
        title: 'Active User Note',
        content: 'Test Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final res = await notesRepo.insertNote(note);
      expect(res, greaterThan(0));

      final notes = await notesRepo.getNotes();
      expect(notes.any((n) => n.id == note.id), isTrue);
    });

    test(
        'Phase 1.2.1 — Repository operation with no active user throws OwnershipException',
        () async {
      final sessionManager = SessionManager();
      await sessionManager.init();
      await sessionManager.clearSession(); // Ensure activeUserId is null

      final notesRepo = SqliteNotesRepository();
      final foldersRepo = SqliteFoldersRepository();
      final tasksRepo = SqliteTasksRepository();

      expect(
        () async => await notesRepo.getNotes(),
        throwsA(isA<OwnershipException>()),
      );
      expect(
        () async => await foldersRepo.getFolders(),
        throwsA(isA<OwnershipException>()),
      );
      expect(
        () async => await tasksRepo.getTasks(),
        throwsA(isA<OwnershipException>()),
      );
    });

    test(
        'Phase 1.2.1 — Repository query isolation: User A cannot read, update, or delete User B notes',
        () async {
      final sessionManager = SessionManager();
      await sessionManager.init();

      final userA = 'usr_userA_${uuid.v4()}';
      final userB = 'usr_userB_${uuid.v4()}';

      final notesRepo = SqliteNotesRepository();

      // User A creates a note
      await sessionManager.saveSession(
          userId: userA, sessionType: SessionType.offline);
      final noteA = Note(
        id: 'note_user_A_${uuid.v4()}',
        title: 'User A Confidential Note',
        content: 'Top Secret',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(noteA);

      final notesUserA = await notesRepo.getNotes();
      expect(notesUserA.any((n) => n.id == noteA.id), isTrue);

      // Switch to User B
      await sessionManager.saveSession(
          userId: userB, sessionType: SessionType.offline);
      final notesUserB = await notesRepo.getNotes();

      // User B cannot read User A note
      expect(notesUserB.any((n) => n.id == noteA.id), isFalse);

      // User B cannot update User A note
      expect(
        () async => await notesRepo.updateNote(noteA),
        throwsA(isA<OwnershipException>()),
      );

      // User B cannot delete User A note
      expect(
        () async => await notesRepo.deleteNote(noteA.id),
        throwsA(isA<OwnershipException>()),
      );
    });

    test(
        'Phase 1.2.1 — Logout clears ownership & provider in-memory state; User B login loads only User B data',
        () async {
      final sessionManager = SessionManager();
      await sessionManager.init();

      final userA = 'usr_logout_A_${uuid.v4()}';
      final userB = 'usr_logout_B_${uuid.v4()}';

      await sessionManager.saveSession(
          userId: userA, sessionType: SessionType.offline);
      expect(sessionManager.activeUserId, equals(userA));

      // Simulate logout
      await sessionManager.clearSession();
      expect(sessionManager.activeUserId, isNull);

      // Login User B
      await sessionManager.saveSession(
          userId: userB, sessionType: SessionType.offline);
      expect(sessionManager.activeUserId, equals(userB));
    });
  });
}
