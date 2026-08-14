import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/services/app_statistics_service.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/models/session_type.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '.';
      }
      return null;
    });

    SharedPreferences.setMockInitialValues({});
    final session = SessionManager();
    await session.init();
    await session.saveSession(userId: 'usr_test_save_arch', sessionType: SessionType.offline);
  });

  group('Saving Data Architecture Tests', () {
    test('TaskItem serialization toMap and fromMap', () {
      final now = DateTime.now();
      final task = TaskItem(
        id: 't1',
        title: 'Complete DB Migration',
        description: 'Migrate to SQLite v10 schema',
        dueDate: now,
        priority: 'High',
        completed: false,
        createdAt: now,
        updatedAt: now,
      );

      final map = task.toMap();
      expect(map['id'], 't1');
      expect(map['title'], 'Complete DB Migration');
      expect(map['priority'], 'High');
      expect(map['completed'], 0);

      final restored = TaskItem.fromMap(map);
      expect(restored.id, 't1');
      expect(restored.title, 'Complete DB Migration');
      expect(restored.priority, 'High');
      expect(restored.completed, false);
    });

    test('TasksRepository CRUD operations', () async {
      final repo = SqliteTasksRepository();
      final now = DateTime.now();

      final task = TaskItem(
        id: 'test_repo_task',
        title: 'Repository Task Test',
        description: 'Testing TasksRepository insert and query',
        dueDate: now,
        priority: 'Medium',
      );

      await repo.insertTask(task);
      final tasks = await repo.getTasks();
      expect(tasks.any((t) => t.id == 'test_repo_task'), isTrue);

      final updatedTask = task.copyWith(completed: true);
      await repo.updateTask(updatedTask);
      final updatedTasks = await repo.getTasks();
      final fetched = updatedTasks.firstWhere((t) => t.id == 'test_repo_task');
      expect(fetched.completed, isTrue);

      await repo.deleteTask('test_repo_task');
      final remaining = await repo.getTasks();
      expect(remaining.any((t) => t.id == 'test_repo_task'), isFalse);
    });

    test('NotesRepository and FoldersRepository CRUD operations', () async {
      final notesRepo = SqliteNotesRepository();
      final foldersRepo = SqliteFoldersRepository();
      final now = DateTime.now();

      final folder = Folder(
        id: 'f_test_1',
        name: 'Architecture Notes',
        createdAt: now,
      );
      await foldersRepo.insertFolder(folder);
      final folders = await foldersRepo.getFolders();
      expect(folders.any((f) => f.id == 'f_test_1'), isTrue);

      final note = Note(
        id: 'n_test_1',
        title: 'Architecture Blueprint',
        content: '4-tier layer separation protocol',
        createdAt: now,
        updatedAt: now,
        folderId: 'f_test_1',
        category: 'Work',
        tags: [],
        attachments: [],
        colorValue: 0,
      );
      await notesRepo.insertNote(note);
      final notes = await notesRepo.getNotes();
      expect(notes.any((n) => n.id == 'n_test_1'), isTrue);

      await notesRepo.deleteNote('n_test_1');
      await foldersRepo.deleteFolder('f_test_1');
    });

    test('TasksProvider reactive state management', () async {
      final provider = TasksProvider();
      await provider.loadTasks();
      final now = DateTime.now();

      await provider.addTask(
        title: 'Provider Task',
        description: 'Testing reactive provider state',
        dueDate: now,
        priority: 'High',
      );

      expect(provider.tasks.isNotEmpty, isTrue);
      final added = provider.tasks.firstWhere((t) => t.title == 'Provider Task');
      expect(added.completed, isFalse);

      await provider.toggleTaskCompletion(added.id);
      final toggled = provider.tasks.firstWhere((t) => t.id == added.id);
      expect(toggled.completed, isTrue);

      await provider.deleteTask(added.id);
      expect(provider.tasks.any((t) => t.id == added.id), isFalse);
    });

    test('AppStatisticsService dynamic calculations and filtering', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final List<Note> notes = [
        Note(id: '1', title: 'N1', content: '', createdAt: today, updatedAt: today, category: 'Work', folderId: 'f1', tags: [], attachments: [], colorValue: 0),
        Note(id: '2', title: 'N2', content: '', createdAt: today.add(const Duration(days: 2)), updatedAt: today.add(const Duration(days: 2)), category: 'Personal', folderId: 'f1', tags: [], attachments: [], colorValue: 0),
        Note(id: '3', title: 'N3', content: '', createdAt: today.add(const Duration(days: 15)), updatedAt: today.add(const Duration(days: 15)), category: 'Work', folderId: 'f2', tags: [], attachments: [], colorValue: 0),
      ];

      final List<TaskItem> tasks = [
        TaskItem(id: 't1', title: 'T1', dueDate: today, priority: 'High', completed: false),
        TaskItem(id: 't2', title: 'T2', dueDate: today, priority: 'Low', completed: true),
      ];

      expect(AppStatisticsService.calculateTotalNotes(notes), 3);
      expect(AppStatisticsService.calculateTotalTasks(tasks), 2);
      expect(AppStatisticsService.calculateCompletedTasks(tasks), 1);
      expect(AppStatisticsService.calculatePendingTasks(tasks), 1);
      expect(AppStatisticsService.calculateNotesForCategory(notes, 'Work'), 2);
      expect(AppStatisticsService.calculateNotesForFolder(notes, 'f1'), 2);

      final todayNotes = AppStatisticsService.filterNotesByDateRange(notes, 'Today');
      expect(todayNotes.length, 1);
      expect(todayNotes.first.id, '1');

      final todayTasks = AppStatisticsService.filterTasksByDateRange(tasks, 'Today');
      expect(todayTasks.length, 1);
      expect(todayTasks.first.id, 't1');
    });
  });
}
