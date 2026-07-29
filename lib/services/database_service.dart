import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import '../models/note.dart';
import '../models/folder.dart';
import '../models/task_item.dart';

class DatabaseService {
  // Singleton pattern
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  static Database? _database;

  // In-memory web fallback store
  static final List<Note> _webNotes = [];
  static final List<Folder> _webFolders = [];
  static final List<TaskItem> _webTasks = [];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Get location of SQLite DB file
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'quick_notes.db');

    // Open/Create the database (version 13)
    return await openDatabase(
      path,
      version: 13,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Schema creation for clean install
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id TEXT PRIMARY KEY,
        title TEXT,
        content TEXT,
        isPinned INTEGER,
        isFavorite INTEGER DEFAULT 0,
        isArchived INTEGER DEFAULT 0,
        category TEXT DEFAULT "Uncategorized",
        noteType TEXT DEFAULT "text",
        tags TEXT,
        attachments TEXT,
        isLocked INTEGER DEFAULT 0,
        reminderTime TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        colorValue INTEGER,
        folderId TEXT,
        isHabit INTEGER DEFAULT 0,
        habitRecurrence TEXT,
        habitStreak INTEGER DEFAULT 0,
        habitLastCompleted TEXT,
        isDeleted INTEGER DEFAULT 0,
        previewText TEXT,
        paperSettings TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE folders(
        id TEXT PRIMARY KEY,
        name TEXT,
        parentId TEXT,
        createdAt TEXT,
        colorHex TEXT,
        sticker TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks(
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        folderId TEXT,
        categoryId TEXT,
        dueDate TEXT,
        startTime TEXT,
        endTime TEXT,
        priority TEXT,
        status TEXT DEFAULT "waiting",
        completed INTEGER DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT,
        completedAt TEXT,
        reminderEnabled INTEGER DEFAULT 0,
        reminderTime TEXT,
        notificationId INTEGER DEFAULT 0,
        repeatRule TEXT DEFAULT "none",
        isRecurring INTEGER DEFAULT 0,
        recurrenceRule TEXT,
        recurringSeriesId TEXT,
        timezone TEXT,
        completedDates TEXT
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_folderId ON notes(folderId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_category ON notes(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_createdAt ON notes(createdAt)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_updatedAt ON notes(updatedAt)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_isPinned ON notes(isPinned)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_reminderTime ON notes(reminderTime)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_folders_createdAt ON folders(createdAt)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_dueDate ON tasks(dueDate)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_notificationId ON tasks(notificationId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_recurringSeriesId ON tasks(recurringSeriesId)');
  }

  // Migration handling
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE notes ADD COLUMN isFavorite INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE notes ADD COLUMN isArchived INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE notes ADD COLUMN category TEXT DEFAULT "Uncategorized"');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE notes ADD COLUMN noteType TEXT DEFAULT "text"');
      await db.execute('ALTER TABLE notes ADD COLUMN tags TEXT');
      await db.execute('ALTER TABLE notes ADD COLUMN attachments TEXT');
      await db.execute('ALTER TABLE notes ADD COLUMN isLocked INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE notes ADD COLUMN reminderTime TEXT');
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE notes ADD COLUMN folderId TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE notes ADD COLUMN isHabit INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE notes ADD COLUMN habitRecurrence TEXT');
        await db.execute('ALTER TABLE notes ADD COLUMN habitStreak INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE notes ADD COLUMN habitLastCompleted TEXT');
      } catch (_) {}

      await db.execute('''
        CREATE TABLE IF NOT EXISTS folders(
          id TEXT PRIMARY KEY,
          name TEXT,
          parentId TEXT,
          createdAt TEXT
        )
      ''');
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE notes ADD COLUMN isDeleted INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE notes ADD COLUMN previewText TEXT');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE notes ADD COLUMN paperSettings TEXT');
      } catch (_) {}
    }
    if (oldVersion < 8) {
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_folderId ON notes(folderId)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_category ON notes(category)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_createdAt ON notes(createdAt)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_updatedAt ON notes(updatedAt)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_isPinned ON notes(isPinned)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_reminderTime ON notes(reminderTime)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_folders_createdAt ON folders(createdAt)');
      } catch (_) {}
    }
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE folders ADD COLUMN colorHex TEXT');
        await db.execute('ALTER TABLE folders ADD COLUMN sticker TEXT');
      } catch (_) {}
    }
    if (oldVersion < 10) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tasks(
            id TEXT PRIMARY KEY,
            title TEXT,
            description TEXT,
            dueDate TEXT,
            priority TEXT,
            completed INTEGER DEFAULT 0,
            createdAt TEXT,
            updatedAt TEXT,
            reminderTime TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_dueDate ON tasks(dueDate)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed)');
      } catch (_) {}
    }
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN folderId TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN categoryId TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN startTime TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN endTime TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN status TEXT DEFAULT "waiting"');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN reminderEnabled INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN notificationId INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN repeatRule TEXT DEFAULT "none"');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN timezone TEXT');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_notificationId ON tasks(notificationId)');
      } catch (_) {}
    }
    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN isRecurring INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN recurrenceRule TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN recurringSeriesId TEXT');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_recurringSeriesId ON tasks(recurringSeriesId)');
      } catch (_) {}
    }
    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN completedDates TEXT');
      } catch (_) {}
    }
  }

  // --- Performance Timing Helper ---
  static Future<T> timedQuery<T>(String name, Future<T> Function() query) async {
    final stopwatch = Stopwatch()..start();
    final result = await query();
    stopwatch.stop();
    if (kDebugMode) {
      debugPrint('DB QUERY [$name]: ${stopwatch.elapsedMilliseconds}ms');
    }
    return result;
  }

  // --- CRUD Operations ---

  // Create
  Future<int> insert(Note note) async {
    if (kIsWeb) {
      _webNotes.removeWhere((n) => n.id == note.id);
      _webNotes.add(note);
      return 1;
    }
    final db = await instance.database;
    return await timedQuery('insert', () => db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    ));
  }

  // Read All (Optimized to return content summary instead of loading full text for text notes)
  Future<List<Note>> queryAll() async {
    if (kIsWeb) {
      final list = List<Note>.from(_webNotes);
      list.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return list;
    }
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await timedQuery('queryAll', () => db.rawQuery('''
      SELECT id, title, isPinned, isFavorite, isArchived, category, noteType, tags, attachments, isLocked, reminderTime, createdAt, updatedAt, colorValue, isDeleted, folderId, isHabit, habitRecurrence, habitStreak, habitLastCompleted, previewText, paperSettings, content
      FROM notes
      ORDER BY isPinned DESC, updatedAt DESC
    '''));
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  // Update
  Future<int> update(Note note) async {
    if (kIsWeb) {
      _webNotes.removeWhere((n) => n.id == note.id);
      _webNotes.add(note);
      return 1;
    }
    final db = await instance.database;
    return await timedQuery('update', () => db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    ));
  }

  // Delete
  Future<int> delete(String id) async {
    if (kIsWeb) {
      _webNotes.removeWhere((n) => n.id == id);
      return 1;
    }
    final db = await instance.database;
    return await timedQuery('delete', () => db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    ));
  }

  // Read Single Note (Retrieves full content for the editor screen)
  Future<Note?> queryById(String id) async {
    if (kIsWeb) {
      final matches = _webNotes.where((n) => n.id == id);
      return matches.isEmpty ? null : matches.first;
    }
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await timedQuery('queryById', () => db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    ));
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  // Search Notes (Optimized to return content summary instead of loading full text for text notes)
  Future<List<Note>> search(String query) async {
    if (kIsWeb) {
      final q = query.toLowerCase();
      final list = _webNotes.where((n) {
        final titleMatch = n.title.toLowerCase().contains(q);
        final contentMatch = n.content.toLowerCase().contains(q);
        final tagMatch = n.tags.any((t) => t.toLowerCase().contains(q));
        return titleMatch || contentMatch || tagMatch;
      }).toList();
      list.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return list;
    }
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await timedQuery('search', () => db.rawQuery('''
      SELECT id, title, isPinned, isFavorite, isArchived, category, noteType, tags, attachments, isLocked, reminderTime, createdAt, updatedAt, colorValue, isDeleted, folderId, isHabit, habitRecurrence, habitStreak, habitLastCompleted, previewText, paperSettings, content
      FROM notes
      WHERE title LIKE ? OR content LIKE ? OR tags LIKE ?
      ORDER BY isPinned DESC, updatedAt DESC
    ''', ['%$query%', '%$query%', '%$query%']));
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  // Query notes summary with pagination and optional filters
  Future<List<Map<String, dynamic>>> queryNotesSummaryPaged({
    String? folderId,
    String? category,
    bool? isFavorite,
    bool? isArchived,
    bool isDeleted = false,
    int limit = 20,
    int offset = 0,
  }) async {
    if (kIsWeb) {
      var list = List<Note>.from(_webNotes);
      if (isDeleted) {
        list = list.where((n) => n.isDeleted).toList();
      } else {
        list = list.where((n) => !n.isDeleted).toList();
        if (isArchived != null) {
          list = list.where((n) => n.isArchived == isArchived).toList();
        }
        if (isFavorite != null) {
          list = list.where((n) => n.isFavorite == isFavorite).toList();
        }
        if (folderId != null) {
          list = list.where((n) => n.folderId == folderId).toList();
        }
        if (category != null) {
          list = list.where((n) => n.category == category).toList();
        }
      }
      
      list.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      
      final start = offset;
      if (start >= list.length) return [];
      final end = start + limit > list.length ? list.length : start + limit;
      return list.sublist(start, end).map((n) => n.toMap()).toList();
    }
    
    final db = await instance.database;
    
    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];
    
    whereClauses.add('isDeleted = ?');
    whereArgs.add(isDeleted ? 1 : 0);
    
    if (!isDeleted) {
      if (isArchived != null) {
        whereClauses.add('isArchived = ?');
        whereArgs.add(isArchived ? 1 : 0);
      }
      if (isFavorite != null) {
        whereClauses.add('isFavorite = ?');
        whereArgs.add(isFavorite ? 1 : 0);
      }
      if (folderId != null) {
        whereClauses.add('folderId = ?');
        whereArgs.add(folderId);
      }
      if (category != null) {
        whereClauses.add('category = ?');
        whereArgs.add(category);
      }
    }
    
    final whereString = whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
    
    final List<Map<String, dynamic>> maps = await timedQuery('queryNotesSummaryPaged', () => db.rawQuery('''
      SELECT id, title, isPinned, isFavorite, isArchived, category, noteType, reminderTime, createdAt, updatedAt, colorValue, isDeleted, folderId, previewText, isLocked, isHabit, habitStreak,
      SUBSTR(content, 1, 120) AS content
      FROM notes
      $whereString
      ORDER BY isPinned DESC, updatedAt DESC
      LIMIT ? OFFSET ?
    ''', [...whereArgs, limit, offset]));
    
    return maps;
  }

  // Query habits only (Optimized DB-level filtering)
  Future<List<Note>> queryHabits() async {
    if (kIsWeb) {
      return _webNotes.where((n) => n.isHabit).toList();
    }
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await timedQuery('queryHabits', () => db.query(
      'notes',
      where: 'isHabit = 1',
    ));
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  // Detach all notes from a folder (Optimized DB-level operation)
  Future<void> detachNotesFromFolder(String folderId) async {
    if (kIsWeb) {
      for (var i = 0; i < _webNotes.length; i++) {
        if (_webNotes[i].folderId == folderId) {
          _webNotes[i] = _webNotes[i].copyWith(clearFolder: true);
        }
      }
      return;
    }
    final db = await instance.database;
    await timedQuery('detachNotesFromFolder', () => db.update(
      'notes',
      {'folderId': null},
      where: 'folderId = ?',
      whereArgs: [folderId],
    ));
  }

  // Detach all child folders from a parent folder (Optimized DB-level operation)
  Future<void> detachChildFolders(String parentId) async {
    if (kIsWeb) {
      for (var i = 0; i < _webFolders.length; i++) {
        if (_webFolders[i].parentId == parentId) {
          _webFolders[i] = Folder(
            id: _webFolders[i].id,
            name: _webFolders[i].name,
            parentId: null,
            createdAt: _webFolders[i].createdAt,
          );
        }
      }
      return;
    }
    final db = await instance.database;
    await timedQuery('detachChildFolders', () => db.update(
      'folders',
      {'parentId': null},
      where: 'parentId = ?',
      whereArgs: [parentId],
    ));
  }

  // --- Folder Operations ---
  Future<int> insertFolder(Folder folder) async {
    if (kIsWeb) {
      _webFolders.removeWhere((f) => f.id == folder.id);
      _webFolders.add(folder);
      return 1;
    }
    final db = await instance.database;
    return await timedQuery('insertFolder', () => db.insert(
      'folders',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    ));
  }

  Future<List<Folder>> queryAllFolders() async {
    if (kIsWeb) {
      final list = List<Folder>.from(_webFolders);
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    }
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await timedQuery('queryAllFolders', () => db.query('folders', orderBy: 'name ASC'));
    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<int> deleteFolder(String id) async {
    if (kIsWeb) {
      for (var i = 0; i < _webNotes.length; i++) {
        if (_webNotes[i].folderId == id) {
          _webNotes[i] = _webNotes[i].copyWith(clearFolder: true);
        }
      }
      for (var i = 0; i < _webFolders.length; i++) {
        if (_webFolders[i].parentId == id) {
          _webFolders[i] = Folder(
            id: _webFolders[i].id,
            name: _webFolders[i].name,
            parentId: null,
            createdAt: _webFolders[i].createdAt,
          );
        }
      }
      _webFolders.removeWhere((f) => f.id == id);
      return 1;
    }
    final db = await instance.database;
    return await timedQuery('deleteFolder', () async {
      return await db.transaction((txn) async {
        await txn.update(
          'notes',
          {'folderId': null},
          where: 'folderId = ?',
          whereArgs: [id],
        );
        await txn.update(
          'folders',
          {'parentId': null},
          where: 'parentId = ?',
          whereArgs: [id],
        );
        return await txn.delete(
          'folders',
          where: 'id = ?',
          whereArgs: [id],
        );
      });
    });
  }

  Future<int> updateFolder(Folder folder) async {
    if (kIsWeb) {
      final index = _webFolders.indexWhere((f) => f.id == folder.id);
      if (index != -1) {
        _webFolders[index] = folder;
      }
      return 1;
    }
    final db = await instance.database;
    return await timedQuery('updateFolder', () => db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    ));
  }

  // ── Standalone Tasks Operations ─────────────────────────────────────────────
  Future<int> insertTask(TaskItem task) async {
    if (kIsWeb) {
      _webTasks.add(task);
      return 1;
    }
    final db = await instance.database;
    return await timedQuery('insertTask', () => db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    ));
  }

  Future<int> updateTask(TaskItem task) async {
    if (kIsWeb) {
      final index = _webTasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _webTasks[index] = task;
      }
      return 1;
    }
    final db = await instance.database;
    return await timedQuery('updateTask', () => db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    ));
  }

  Future<int> deleteTask(String id) async {
    if (kIsWeb) {
      _webTasks.removeWhere((t) => t.id == id);
      return 1;
    }
    final db = await instance.database;
    return await timedQuery('deleteTask', () => db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    ));
  }

  Future<List<TaskItem>> getAllTasks() async {
    if (kIsWeb) {
      final list = List<TaskItem>.from(_webTasks);
      list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      return list;
    }
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await timedQuery('queryAllTasks', () => db.query(
      'tasks',
      orderBy: 'dueDate DESC',
    ));
    return maps.map((map) => TaskItem.fromMap(map)).toList();
  }

  Future<List<TaskItem>> getTasksForDate(DateTime date) async {
    final all = await getAllTasks();
    final target = DateTime(date.year, date.month, date.day);
    return all.where((t) {
      final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return d.isAtSameMomentAs(target);
    }).toList();
  }

  /// Generates a collision-free 32-bit positive integer notification ID.
  Future<int> generateUniqueNotificationId() async {
    final rng = DateTime.now().microsecondsSinceEpoch;
    int candidate = (rng.abs() % 1073741823) + 1;

    if (kIsWeb) {
      final existingIds = _webTasks.map((t) => t.notificationId).toSet();
      while (existingIds.contains(candidate)) {
        candidate = (candidate + 1) % 1073741823 + 1;
      }
      return candidate;
    }

    final db = await instance.database;
    bool exists = true;
    while (exists) {
      final result = await db.query(
        'tasks',
        columns: ['notificationId'],
        where: 'notificationId = ?',
        whereArgs: [candidate],
        limit: 1,
      );
      if (result.isEmpty) {
        exists = false;
      } else {
        candidate = (candidate + 1) % 1073741823 + 1;
      }
    }
    return candidate;
  }
}
