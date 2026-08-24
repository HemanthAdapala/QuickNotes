import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:quick_notes/models/identity_link_result.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/models/user_profile.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/repositories/user_identity_repository.dart';
import 'package:quick_notes/services/database_exceptions.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/local_profile_service.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/services/user_identity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteUserIdentityRepository identityRepo;
  late UserIdentityService identityService;
  late SqliteNotesRepository notesRepo;
  late SqliteFoldersRepository foldersRepo;
  late SqliteTasksRepository tasksRepo;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    final secureStorageStore = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'write') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          secureStorageStore[args['key'] as String] = args['value'] as String;
          return null;
        } else if (methodCall.method == 'read') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          return secureStorageStore[args['key'] as String];
        } else if (methodCall.method == 'delete') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          secureStorageStore.remove(args['key'] as String);
          return null;
        }
        return null;
      },
    );

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await DatabaseService.instance.database;
    await db.delete('users');
    await db.delete('user_identities');
    await db.delete('user_profiles');
    await db.delete('notes');
    await db.delete('folders');
    await db.delete('tasks');
    await db.delete('sync_outbox');

    identityRepo = SqliteUserIdentityRepository();
    identityService = UserIdentityService();
    identityService.setRepositoryForTesting(identityRepo);
    notesRepo = SqliteNotesRepository();
    foldersRepo = SqliteFoldersRepository();
    tasksRepo = SqliteTasksRepository();
    await SessionManager().clearSession();
  });

  /// Helper to create a canonical offline user in the database
  Future<String> createOfflineUserInDb({String? customDisplayName}) async {
    final offlineUser = await LocalProfileService().createOfflineProfile();
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final db = await DatabaseService.instance.database;

    await db.insert('users', {
      'id': offlineUser.id,
      'isOffline': 1,
      'createdAt': nowIso,
      'updatedAt': nowIso,
    });

    await db.insert('user_profiles', {
      'userId': offlineUser.id,
      'displayName': customDisplayName ?? offlineUser.displayName,
      'email': offlineUser.email,
      'photoUrl': null,
      'usesGooglePhoto': 0,
      'profileVersion': 1,
      'createdAt': nowIso,
      'updatedAt': nowIso,
    });

    return offlineUser.id;
  }

  group('Phase 1.9.8.1 — Offline → Google Identity Linking Engine Tests', () {
    test('T-1. Fresh Google identity links to offline user in-place', () async {
      final offlineUserId = await createOfflineUserInDb();
      await SessionManager().saveSession(
        userId: offlineUserId,
        sessionType: SessionType.offline,
      );

      const googleId = 'google_uid_fresh_123';
      const email = 'alex@gmail.com';
      const displayName = 'Alex Google';
      const photoUrl = 'https://photo.google.com/alex.png';

      final result = await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: offlineUserId,
        googleId: googleId,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
      );

      expect(result.status, equals(IdentityLinkStatus.linked));
      expect(result.isSuccess, isTrue);
      expect(result.userId, equals(offlineUserId));
      expect(result.identity, isNotNull);
      expect(result.identity!.userId, equals(offlineUserId));
      expect(result.identity!.provider, equals('google'));
      expect(result.identity!.providerUserId, equals(googleId));
      expect(result.identity!.email, equals(email));

      // Verify users table: isOffline changed from 1 to 0
      final user = await identityRepo.findUserById(offlineUserId);
      expect(user, isNotNull);
      expect(user!.id, equals(offlineUserId));
      expect(user.isOffline, isFalse);

      // Verify user_identities table row
      final identityInDb = await identityRepo.findIdentity('google', googleId);
      expect(identityInDb, isNotNull);
      expect(identityInDb!.userId, equals(offlineUserId));

      // Verify user_profiles table updated
      final db = await DatabaseService.instance.database;
      final profileMaps = await db.query('user_profiles', where: 'userId = ?', whereArgs: [offlineUserId]);
      expect(profileMaps.isNotEmpty, isTrue);
      final profile = UserProfile.fromMap(profileMaps.first);
      expect(profile.email, equals(email));
      expect(profile.displayName, equals(displayName));
      expect(profile.photoUrl, equals(photoUrl));
      expect(profile.usesGooglePhoto, isTrue);
    });

    test('T-2. Google identity already belongs to same user (idempotent)', () async {
      final offlineUserId = await createOfflineUserInDb();
      const googleId = 'google_uid_same_123';

      // First link
      final firstResult = await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: offlineUserId,
        googleId: googleId,
        email: 'same@gmail.com',
      );
      expect(firstResult.status, equals(IdentityLinkStatus.linked));

      // Second link attempt with same Google ID
      final secondResult = await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: offlineUserId,
        googleId: googleId,
        email: 'same@gmail.com',
      );

      expect(secondResult.status, equals(IdentityLinkStatus.alreadyLinked));
      expect(secondResult.isSuccess, isTrue);
      expect(secondResult.userId, equals(offlineUserId));

      // Verify no duplicate row in user_identities
      final db = await DatabaseService.instance.database;
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM user_identities WHERE userId = ?',
        [offlineUserId],
      );
      expect(countResult.first['cnt'], equals(1));
    });

    test('T-3. Google identity belongs to another user (Identity Collision / Conflict)', () async {
      // Create user B who already owns google_uid_existing
      const existingGoogleId = 'google_uid_existing_456';
      final existingUserBId = await identityService.getOrCreateCanonicalUser(
        provider: 'google',
        providerUserId: existingGoogleId,
        email: 'userb@gmail.com',
        displayName: 'User B',
      );

      // Create active offline user A
      final offlineUserAId = await createOfflineUserInDb();

      // Offline User A attempts to link the Google ID that belongs to User B
      final conflictResult = await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: offlineUserAId,
        googleId: existingGoogleId,
        email: 'userb@gmail.com',
      );

      expect(conflictResult.status, equals(IdentityLinkStatus.conflict));
      expect(conflictResult.isSuccess, isFalse);
      expect(conflictResult.isConflict, isTrue);
      expect(conflictResult.conflictingUserId, equals(existingUserBId));

      // Verify User A remains offline with 0 identity rows
      final userA = await identityRepo.findUserById(offlineUserAId);
      expect(userA!.isOffline, isTrue);

      final identityForA = await identityRepo.findIdentityForUser(offlineUserAId, 'google');
      expect(identityForA, isNull);

      // Verify User B remains untouched
      final userBIdentity = await identityRepo.findIdentity('google', existingGoogleId);
      expect(userBIdentity!.userId, equals(existingUserBId));
    });

    test('T-4. Unknown active user returns userNotFound with zero DB mutations', () async {
      const nonexistentUserId = 'usr_nonexistent_999';

      final result = await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: nonexistentUserId,
        googleId: 'google_uid_unknown_test',
        email: 'unknown@gmail.com',
      );

      expect(result.status, equals(IdentityLinkStatus.userNotFound));
      expect(result.isSuccess, isFalse);

      final db = await DatabaseService.instance.database;
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM user_identities',
      );
      expect(countResult.first['cnt'], equals(0));
    });

    test('T-5. Active user already linked to a different Google account', () async {
      final offlineUserId = await createOfflineUserInDb();
      const firstGoogleId = 'google_uid_primary';
      const secondGoogleId = 'google_uid_secondary';

      // Link first Google ID
      await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: offlineUserId,
        googleId: firstGoogleId,
        email: 'primary@gmail.com',
      );

      // Attempt to link a second, different Google ID to the same user
      final result = await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: offlineUserId,
        googleId: secondGoogleId,
        email: 'secondary@gmail.com',
      );

      expect(result.status, equals(IdentityLinkStatus.alreadyLinkedToDifferentIdentity));
      expect(result.isSuccess, isFalse);

      // Verify first link remains preserved
      final identity = await identityRepo.findIdentityForUser(offlineUserId, 'google');
      expect(identity!.providerUserId, equals(firstGoogleId));
    });

    test('T-6. Existing local data preservation (Zero data migration, Zero re-keying)', () async {
      final offlineUserId = await createOfflineUserInDb();
      await SessionManager().saveSession(
        userId: offlineUserId,
        sessionType: SessionType.offline,
      );

      // 1. Create notes, folders, tasks under offlineUserId
      final note1 = Note(
        id: const Uuid().v4(),
        userId: offlineUserId,
        title: 'Offline Shopping List',
        content: 'Milk, Eggs, Bread',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final note2 = Note(
        id: const Uuid().v4(),
        userId: offlineUserId,
        title: 'Work Ideas',
        content: 'Draft proposal',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note1);
      await notesRepo.insertNote(note2);

      final folder = Folder(
        id: const Uuid().v4(),
        userId: offlineUserId,
        name: 'Personal Projects',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await foldersRepo.insertFolder(folder);

      final task = TaskItem(
        id: const Uuid().v4(),
        userId: offlineUserId,
        title: 'Finish audit',
        dueDate: DateTime.now(),
        priority: 'medium',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await tasksRepo.insertTask(task);

      // 2. Link Google identity in-place
      const googleId = 'google_uid_preserve_test';
      final linkResult = await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: offlineUserId,
        googleId: googleId,
        email: 'preserve@gmail.com',
      );
      expect(linkResult.status, equals(IdentityLinkStatus.linked));

      // 3. Verify ALL data is still accessible under offlineUserId
      final fetchedNotes = await notesRepo.getNotes();
      expect(fetchedNotes.length, equals(2));
      expect(fetchedNotes.any((n) => n.id == note1.id && n.userId == offlineUserId), isTrue);
      expect(fetchedNotes.any((n) => n.id == note2.id && n.userId == offlineUserId), isTrue);

      final fetchedFolders = await foldersRepo.getFolders();
      expect(fetchedFolders.length, equals(1));
      expect(fetchedFolders.first.id, equals(folder.id));
      expect(fetchedFolders.first.userId, equals(offlineUserId));

      final fetchedTasks = await tasksRepo.getTasks();
      expect(fetchedTasks.length, equals(1));
      expect(fetchedTasks.first.id, equals(task.id));
      expect(fetchedTasks.first.userId, equals(offlineUserId));
    });

    test('T-7. Profile Rule — Preserves custom offline user name', () async {
      const customName = 'Dr. Jane Watson';
      final offlineUserId = await createOfflineUserInDb(customDisplayName: customName);

      final result = await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: offlineUserId,
        googleId: 'google_uid_custom_name',
        email: 'jane.watson@gmail.com',
        displayName: 'Jane Google',
        photoUrl: 'https://photo.url/jane.jpg',
      );

      expect(result.status, equals(IdentityLinkStatus.linked));
      expect(result.profile!.displayName, equals(customName));
      expect(result.profile!.email, equals('jane.watson@gmail.com'));
      expect(result.profile!.photoUrl, equals('https://photo.url/jane.jpg'));
    });

    test('T-8. Profile Rule — Replaces default "Offline User" with Google display name', () async {
      final offlineUserId = await createOfflineUserInDb(); // default "Offline User"

      final result = await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: offlineUserId,
        googleId: 'google_uid_default_name',
        email: 'bob@gmail.com',
        displayName: 'Bob Smith',
        photoUrl: 'https://photo.url/bob.jpg',
      );

      expect(result.status, equals(IdentityLinkStatus.linked));
      expect(result.profile!.displayName, equals('Bob Smith'));
      expect(result.profile!.email, equals('bob@gmail.com'));
    });

    test('T-9. Cross-user isolation: User A link does not expose User B data', () async {
      // Create User B with private note
      const userBGoogleId = 'google_uid_isolated_b';
      final userBId = await identityService.getOrCreateCanonicalUser(
        provider: 'google',
        providerUserId: userBGoogleId,
        email: 'userb@gmail.com',
      );
      await SessionManager().saveSession(userId: userBId, sessionType: SessionType.google);

      final userBNote = Note(
        id: const Uuid().v4(),
        userId: userBId,
        title: 'User B Confidential Note',
        content: 'Secret Plan',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(userBNote);

      // Switch to offline User A and link fresh Google account
      final userAId = await createOfflineUserInDb();
      await SessionManager().saveSession(userId: userAId, sessionType: SessionType.offline);

      await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: userAId,
        googleId: 'google_uid_isolated_a',
        email: 'usera@gmail.com',
      );

      // Verify User A cannot see User B's note
      final userANotes = await notesRepo.getNotes();
      expect(userANotes.isEmpty, isTrue);

      // Attempting to read User B's note with User A active session throws OwnershipException
      expect(
        () async => await notesRepo.getNoteById(userBNote.id),
        throwsA(isA<OwnershipException>()),
      );
    });

    test('T-10. Repeated link operation idempotency', () async {
      final offlineUserId = await createOfflineUserInDb();
      const googleId = 'google_uid_idempotent';

      final r1 = await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: offlineUserId,
        googleId: googleId,
        email: 'idem@gmail.com',
      );
      final r2 = await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: offlineUserId,
        googleId: googleId,
        email: 'idem@gmail.com',
      );
      final r3 = await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: offlineUserId,
        googleId: googleId,
        email: 'idem@gmail.com',
      );

      expect(r1.status, equals(IdentityLinkStatus.linked));
      expect(r2.status, equals(IdentityLinkStatus.alreadyLinked));
      expect(r3.status, equals(IdentityLinkStatus.alreadyLinked));

      final db = await DatabaseService.instance.database;
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM user_identities WHERE userId = ?',
        [offlineUserId],
      );
      expect(countResult.first['cnt'], equals(1));
    });
  });
}
