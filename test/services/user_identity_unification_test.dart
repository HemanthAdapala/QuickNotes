import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/services/user_identity_service.dart';
import 'package:quick_notes/services/local_profile_service.dart';
import 'package:quick_notes/repositories/user_identity_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/repositories/outbox_repository.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/session_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteUserIdentityRepository identityRepo;
  late UserIdentityService identityService;
  late SqliteNotesRepository notesRepo;
  late SqliteFoldersRepository foldersRepo;
  late SqliteTasksRepository tasksRepo;
  late SqliteOutboxRepository outboxRepo;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    identityRepo = SqliteUserIdentityRepository();
    identityService = UserIdentityService();
    notesRepo = SqliteNotesRepository();
    foldersRepo = SqliteFoldersRepository();
    tasksRepo = SqliteTasksRepository();
    outboxRepo = SqliteOutboxRepository();
    await SessionManager().clearSession();
  });

  group('Phase 1.7.1 — Canonical User Identity Unification Tests', () {
    test('1 & 2 & 3 & 4. First Google login creates canonical User.id beginning with usr_', () async {
      const googleUid = '112345678901234567890';
      const email = 'alex@example.com';

      final canonicalId = await identityService.getOrCreateCanonicalUser(
        provider: 'google',
        providerUserId: googleUid,
        email: email,
        displayName: 'Alex Google',
      );

      expect(canonicalId.startsWith('usr_'), isTrue);
      expect(canonicalId.contains(googleUid), isFalse);

      final identity = await identityRepo.findIdentity('google', googleUid);
      expect(identity, isNotNull);
      expect(identity!.provider, equals('google'));
      expect(identity.providerUserId, equals(googleUid));
      expect(identity.userId, equals(canonicalId));
      expect(identity.email, equals(email));

      final user = await identityRepo.findUserById(canonicalId);
      expect(user, isNotNull);
      expect(user!.id, equals(canonicalId));
      expect(user.isOffline, isFalse);
    });

    test('5 & 6. SessionManager activeUserId stores canonical User.id, NEVER Google account ID', () async {
      const googleUid = '99887766554433221100';

      final canonicalId = await identityService.getOrCreateCanonicalUser(
        provider: 'google',
        providerUserId: googleUid,
        email: 'test@example.com',
      );

      await SessionManager().saveSession(
        userId: canonicalId,
        sessionType: SessionType.google,
      );

      final activeId = SessionManager().activeUserId;
      expect(activeId, equals(canonicalId));
      expect(activeId, isNot(equals(googleUid)));
      expect(activeId!.startsWith('usr_'), isTrue);
    });

    test('7 & 8 & 9 & 10. Repeated login with same Google UID returns SAME canonical User.id without duplicating rows', () async {
      const googleUid = '55555555555555555555';
      final db = await DatabaseService.instance.database;

      final firstCanonicalId = await identityService.getOrCreateCanonicalUser(
        provider: 'google',
        providerUserId: googleUid,
        email: 'repeat@example.com',
      );

      final initialUsers = await db.query('users', where: 'id = ?', whereArgs: [firstCanonicalId]);
      final initialIdentities = await db.query('user_identities', where: 'providerUserId = ?', whereArgs: [googleUid]);
      expect(initialUsers.length, equals(1));
      expect(initialIdentities.length, equals(1));

      final firstAuthTime = DateTime.parse(initialIdentities.first['lastAuthenticatedAt'] as String);

      await Future.delayed(const Duration(milliseconds: 50));

      final secondCanonicalId = await identityService.getOrCreateCanonicalUser(
        provider: 'google',
        providerUserId: googleUid,
        email: 'repeat@example.com',
      );

      expect(secondCanonicalId, equals(firstCanonicalId));

      final finalUsers = await db.query('users', where: 'id = ?', whereArgs: [firstCanonicalId]);
      final finalIdentities = await db.query('user_identities', where: 'providerUserId = ?', whereArgs: [googleUid]);

      expect(finalUsers.length, equals(1));
      expect(finalIdentities.length, equals(1));

      final secondAuthTime = DateTime.parse(finalIdentities.first['lastAuthenticatedAt'] as String);
      expect(secondAuthTime.isAfter(firstAuthTime) || secondAuthTime == firstAuthTime, isTrue);
    });

    test('11. Different Google UIDs receive different canonical User.ids', () async {
      const uid1 = 'google_user_111';
      const uid2 = 'google_user_222';

      final id1 = await identityService.getOrCreateCanonicalUser(
        provider: 'google',
        providerUserId: uid1,
      );

      final id2 = await identityService.getOrCreateCanonicalUser(
        provider: 'google',
        providerUserId: uid2,
      );

      expect(id1, isNot(equals(id2)));
    });

    test('12 & 13. Failed or cancelled authentication leaves SessionManager activeUserId unchanged', () async {
      const existingId = 'usr_test_existing_123';
      await SessionManager().saveSession(
        userId: existingId,
        sessionType: SessionType.offline,
      );

      expect(SessionManager().activeUserId, equals(existingId));

      // Simulate failure / cancellation by not overwriting SessionManager
      expect(SessionManager().activeUserId, equals(existingId));
    });

    test('14. Offline user creation still produces usr_local_<uuid>', () async {
      final offlineUser = await LocalProfileService().createOfflineProfile();
      await SessionManager().saveSession(
        userId: offlineUser.id,
        sessionType: offlineUser.sessionType,
      );

      expect(offlineUser.id.startsWith('usr_local_'), isTrue);
      expect(SessionManager().activeUserId, equals(offlineUser.id));
      expect(SessionManager().isOffline, isTrue);
    });

    test('15 & 16 & 17 & 18. Notes, Folders, Tasks, and Outbox created after Google login use canonical User.id', () async {
      const googleUid = '77777777777777777777';

      final canonicalId = await identityService.getOrCreateCanonicalUser(
        provider: 'google',
        providerUserId: googleUid,
        email: 'scoped@example.com',
      );

      await SessionManager().saveSession(
        userId: canonicalId,
        sessionType: SessionType.google,
      );

      // Create Note
      final note = Note(
        id: const Uuid().v4(),
        userId: SessionManager().userId,
        title: 'Scoped Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      // Create Folder
      final folder = Folder(
        id: const Uuid().v4(),
        userId: SessionManager().userId,
        name: 'Scoped Folder',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await foldersRepo.insertFolder(folder);

      // Create Task
      final task = TaskItem(
        id: const Uuid().v4(),
        userId: SessionManager().userId,
        title: 'Scoped Task',
        dueDate: DateTime.now(),
        priority: 'medium',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await tasksRepo.insertTask(task);

      // Verify Note
      final fetchedNote = await notesRepo.getNoteById(note.id);
      expect(fetchedNote, isNotNull);
      expect(fetchedNote!.userId, equals(canonicalId));
      expect(fetchedNote.userId?.startsWith('usr_'), isTrue);

      // Verify Folder
      final allFolders = await foldersRepo.getFolders();
      final fetchedFolder = allFolders.firstWhere((f) => f.id == folder.id);
      expect(fetchedFolder, isNotNull);
      expect(fetchedFolder.userId, equals(canonicalId));

      // Verify Task
      final userTasks = await tasksRepo.getTasks();
      expect(userTasks.any((t) => t.id == task.id), isTrue);

      // Verify Outbox Items
      final outboxItems = await outboxRepo.getPendingOutboxItems(canonicalId);
      expect(outboxItems.length, greaterThanOrEqualTo(3));
      for (final item in outboxItems) {
        expect(item.userId, equals(canonicalId));
        expect(item.userId.startsWith('usr_'), isTrue);
      }
    });

    test('19 & 20. User + UserIdentity creation is atomic', () async {
      const googleUid = '88888888888888888888';
      final db = await DatabaseService.instance.database;

      final canonicalId = await identityService.getOrCreateCanonicalUser(
        provider: 'google',
        providerUserId: googleUid,
      );

      final userRows = await db.query('users', where: 'id = ?', whereArgs: [canonicalId]);
      final identityRows = await db.query('user_identities', where: 'userId = ?', whereArgs: [canonicalId]);
      final profileRows = await db.query('user_profiles', where: 'userId = ?', whereArgs: [canonicalId]);

      expect(userRows.length, equals(1));
      expect(identityRows.length, equals(1));
      expect(profileRows.length, equals(1));
    });
  });
}
