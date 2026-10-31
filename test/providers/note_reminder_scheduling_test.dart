import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class _InMemoryNotesRepository implements NotesRepository {
  final Map<String, Note> storage = {};

  @override
  Future<List<Note>> getNotes() async =>
      storage.values.where((n) => !n.isDeleted).toList();

  @override
  Future<List<Note>> getTrashNotes() async =>
      storage.values.where((n) => n.isDeleted).toList();

  @override
  Future<Note?> getNoteById(String id) async => storage[id];

  @override
  Future<int> insertNote(Note note) async {
    storage[note.id] = note;
    return 1;
  }

  @override
  Future<int> updateNote(Note note) async {
    storage[note.id] = note;
    return 1;
  }

  @override
  Future<int> trashNote(String id) async {
    final note = storage[id];
    if (note != null) {
      storage[id] = note.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
      );
      return 1;
    }
    return 0;
  }

  @override
  Future<int> restoreNote(String id) async {
    final note = storage[id];
    if (note != null) {
      storage[id] = note.copyWith(isDeleted: false);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteNote(String id) async {
    storage.remove(id);
    return 1;
  }

  @override
  Future<int> emptyTrash() async {
    storage.removeWhere((k, v) => v.isDeleted);
    return 1;
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    final q = query.toLowerCase();
    return storage.values.where((n) {
      if (n.isDeleted) return false;
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<List<Note>> queryHabits() async => [];

  @override
  Future<List<Map<String, dynamic>>> queryNotesSummaryPaged({
    String? folderId,
    String? category,
    bool? isFavorite,
    bool? isArchived,
    bool isDeleted = false,
    int limit = 20,
    int offset = 0,
  }) async =>
      [];

  @override
  Future<int> toggleArchive(String id) async => 1;

  @override
  Future<int> toggleFavorite(String id) async => 1;

  @override
  Future<int> togglePin(String id) async => 1;
}

class _InMemoryFoldersRepository implements FoldersRepository {
  final Map<String, Folder> storage = {};

  @override
  Future<List<Folder>> getFolders() async => storage.values.toList();

  @override
  Future<List<Folder>> getTrashFolders() async => [];

  @override
  Future<int> insertFolder(Folder folder) async {
    storage[folder.id] = folder;
    return 1;
  }

  @override
  Future<int> updateFolder(Folder folder) async {
    storage[folder.id] = folder;
    return 1;
  }

  @override
  Future<int> trashFolder(String id) async => 1;

  @override
  Future<Folder?> getFolderById(String id) async => storage[id];

  @override
  Future<int> restoreFolder(String id) async => 1;

  @override
  Future<int> deleteFolder(String id) async {
    storage.remove(id);
    return 1;
  }

  @override
  Future<int> emptyTrash() async {
    storage.clear();
    return 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  tz.initializeTimeZones();

  final List<MethodCall> notificationCalls = [];

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => '.',
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall call) async {
        if (call.method == 'checkPermissionStatus') return 1; // granted
        if (call.method == 'requestPermissions') return {17: 1};
        return 1;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall call) async {
        notificationCalls.add(call);
        return true;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (MethodCall call) async => true,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('class.yiss.home_widget'),
      (MethodCall call) async => true,
    );

    SharedPreferences.setMockInitialValues({});
    final session = SessionManager();
    await session.init();
    await session.saveSession(
      userId: 'usr_note_reminder_test',
      sessionType: SessionType.offline,
    );
  });

  setUp(() {
    notificationCalls.clear();
  });

  group('Note-Level Reminder Scheduling & Cancellation Suite (GAP-003)', () {
    late _InMemoryNotesRepository notesRepo;
    late _InMemoryFoldersRepository foldersRepo;
    late NotesProvider provider;

    setUp(() {
      notesRepo = _InMemoryNotesRepository();
      foldersRepo = _InMemoryFoldersRepository();
      provider = NotesProvider(
        notesRepository: notesRepo,
        foldersRepository: foldersRepo,
      );
    });

    test('1. Creating note with future reminder schedules zoned notification',
        () async {
      final scheduledTime = DateTime.now().add(const Duration(hours: 4));

      await provider.addNote(
        title: 'Dentist Appointment',
        content: 'Routine dental checkup and teeth cleaning.',
        category: 'Personal',
        colorIndex: 2,
        tags: ['Health'],
        attachments: [],
        reminderTime: scheduledTime,
      );

      final scheduleCalls = notificationCalls
          .where((call) => call.method == 'zonedSchedule')
          .toList();

      expect(scheduleCalls, hasLength(1));
      final call = scheduleCalls.first;
      final args = call.arguments as Map;

      final createdNote = notesRepo.storage.values.first;
      expect(args['id'], equals(createdNote.id.hashCode));
      expect(args['title'], equals('Reminder: Dentist Appointment'));
      expect(args['body'], contains('Routine dental checkup'));
      expect(args['payload'], equals(createdNote.id));
      // In flutter_local_notifications for Android, notification details are nested under 'platformSpecifics'
      if (args.containsKey('platformSpecifics')) {
        final specifics = args['platformSpecifics'] as Map;
        expect(specifics['channelId'], equals('quicknotes_reminders_channel'));
      }
    });

    test('2. Creating note without reminder does not trigger scheduling',
        () async {
      await provider.addNote(
        title: 'Grocery List',
        content: 'Apples, milk, bread, and eggs.',
        category: 'Personal',
        colorIndex: 0,
        tags: ['Shopping'],
        attachments: [],
        reminderTime: null,
      );

      final scheduleCalls = notificationCalls
          .where((call) => call.method == 'zonedSchedule')
          .toList();

      expect(scheduleCalls, isEmpty);
    });

    test('3. Creating note with past reminder date is ignored gracefully',
        () async {
      final pastDate = DateTime.now().subtract(const Duration(hours: 1));

      await provider.addNote(
        title: 'Past Event',
        content: 'This reminder is already in the past.',
        category: 'Ideas',
        colorIndex: 3,
        tags: [],
        attachments: [],
        reminderTime: pastDate,
      );

      final scheduleCalls = notificationCalls
          .where((call) => call.method == 'zonedSchedule')
          .toList();

      expect(scheduleCalls, isEmpty);
    });

    test('4. Updating note to new reminder cancels previous and reschedules',
        () async {
      final initialReminder = DateTime.now().add(const Duration(hours: 2));
      await provider.addNote(
        title: 'Flight Check-in',
        content: 'Boarding pass check-in opens now.',
        category: 'Work',
        colorIndex: 1,
        tags: ['Travel'],
        attachments: [],
        reminderTime: initialReminder,
      );

      final initialNote = notesRepo.storage.values.first;
      notificationCalls.clear();

      final newReminder = DateTime.now().add(const Duration(hours: 5));
      final updatedNote = initialNote.copyWith(
        title: 'Flight Check-in Updated',
        reminderTime: newReminder,
      );

      await provider.updateNote(updatedNote);

      final cancelCalls =
          notificationCalls.where((call) => call.method == 'cancel').toList();
      expect(cancelCalls, hasLength(1));
      expect(
          cancelCalls.first.arguments['id'], equals(initialNote.id.hashCode));

      final scheduleCalls = notificationCalls
          .where((call) => call.method == 'zonedSchedule')
          .toList();
      expect(scheduleCalls, hasLength(1));
      expect(scheduleCalls.first.arguments['title'],
          equals('Reminder: Flight Check-in Updated'));
    });

    test('5. Clearing reminder on update cancels alarm without rescheduling',
        () async {
      final initialReminder = DateTime.now().add(const Duration(hours: 3));
      await provider.addNote(
        title: 'Standup Meeting',
        content: 'Daily engineering sync at 10 AM.',
        category: 'Work',
        colorIndex: 1,
        tags: ['Work'],
        attachments: [],
        reminderTime: initialReminder,
      );

      final initialNote = notesRepo.storage.values.first;
      notificationCalls.clear();

      final clearedNote = initialNote.copyWith(
        clearReminder: true,
      );

      await provider.updateNote(clearedNote);

      final cancelCalls =
          notificationCalls.where((call) => call.method == 'cancel').toList();
      expect(cancelCalls, hasLength(1));
      expect(
          cancelCalls.first.arguments['id'], equals(initialNote.id.hashCode));

      final scheduleCalls = notificationCalls
          .where((call) => call.method == 'zonedSchedule')
          .toList();
      expect(scheduleCalls, isEmpty);
    });

    test('6. Moving note to trash cancels active reminder alarm', () async {
      final scheduledTime = DateTime.now().add(const Duration(hours: 6));
      await provider.addNote(
        title: 'Cancel Subscription',
        content: 'Cancel trial before billing cycle renews.',
        category: 'Personal',
        colorIndex: 4,
        tags: ['Finance'],
        attachments: [],
        reminderTime: scheduledTime,
      );

      final createdNote = notesRepo.storage.values.first;
      notificationCalls.clear();

      await provider.trashNote(createdNote.id);

      final cancelCalls =
          notificationCalls.where((call) => call.method == 'cancel').toList();
      expect(cancelCalls, hasLength(1));
      expect(
          cancelCalls.first.arguments['id'], equals(createdNote.id.hashCode));
    });

    test('7. Restoring note from trash reschedules reminder if still in future',
        () async {
      final futureReminder = DateTime.now().add(const Duration(hours: 8));
      await provider.addNote(
        title: 'Tax Filing Deadline',
        content: 'Submit tax return documents.',
        category: 'Personal',
        colorIndex: 5,
        tags: ['Tax'],
        attachments: [],
        reminderTime: futureReminder,
      );

      final createdNote = notesRepo.storage.values.first;
      await provider.trashNote(createdNote.id);
      notificationCalls.clear();

      await provider.restoreFromTrash(createdNote.id);

      final scheduleCalls = notificationCalls
          .where((call) => call.method == 'zonedSchedule')
          .toList();
      expect(scheduleCalls, hasLength(1));
      expect(
          scheduleCalls.first.arguments['id'], equals(createdNote.id.hashCode));
      expect(scheduleCalls.first.arguments['title'],
          equals('Reminder: Tax Filing Deadline'));
    });

    test('8. Permanently deleting note cancels reminder alarm', () async {
      final futureReminder = DateTime.now().add(const Duration(hours: 12));
      await provider.addNote(
        title: 'Temporary Reminder Note',
        content: 'Note to be permanently removed.',
        category: 'Ideas',
        colorIndex: 6,
        tags: [],
        attachments: [],
        reminderTime: futureReminder,
      );

      final createdNote = notesRepo.storage.values.first;
      notificationCalls.clear();

      await provider.deleteNote(createdNote.id);

      final cancelCalls =
          notificationCalls.where((call) => call.method == 'cancel').toList();
      expect(cancelCalls, hasLength(1));
      expect(
          cancelCalls.first.arguments['id'], equals(createdNote.id.hashCode));
    });
  });
}
