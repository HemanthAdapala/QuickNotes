import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import '../models/note.dart';
import '../models/folder.dart';

class DatabaseService {
  // Singleton pattern
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  static Database? _database;

  // In-memory web fallback store
  static final List<Note> _webNotes = [];
  static final List<Folder> _webFolders = [];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Get location of SQLite DB file
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'quick_notes.db');

    // Open/Create the database (version 8)
    return await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Schema creation for clean install (version 7)
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
        createdAt TEXT
      )
    ''');

    // Create indexes for version 8
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_folderId ON notes(folderId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_category ON notes(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_createdAt ON notes(createdAt)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_updatedAt ON notes(updatedAt)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_isPinned ON notes(isPinned)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_reminderTime ON notes(reminderTime)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_folders_createdAt ON folders(createdAt)');
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
      // Add folder referencing column
      try {
        await db.execute('ALTER TABLE notes ADD COLUMN folderId TEXT');
      } catch (e) {
        // Column may exist from failed migrate
      }
      
      // Add habit columns
      try {
        await db.execute('ALTER TABLE notes ADD COLUMN isHabit INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE notes ADD COLUMN habitRecurrence TEXT');
        await db.execute('ALTER TABLE notes ADD COLUMN habitStreak INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE notes ADD COLUMN habitLastCompleted TEXT');
      } catch (e) {
        // Columns may exist from previous run
      }

      // Create folders table
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
      } catch (e) {
        // Column may exist from previous run
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE notes ADD COLUMN previewText TEXT');
      } catch (e) {
        // Column may exist from previous run
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE notes ADD COLUMN paperSettings TEXT');
      } catch (e) {
        // Column may exist from previous run
      }
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
      SELECT id, title, isPinned, isFavorite, isArchived, category, noteType, tags, attachments, isLocked, reminderTime, createdAt, updatedAt, colorValue, isDeleted, folderId, isHabit, habitRecurrence, habitStreak, habitLastCompleted, previewText, paperSettings,
      CASE WHEN noteType = 'checklist' THEN content ELSE SUBSTR(content, 1, 150) END AS content
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
      SELECT id, title, isPinned, isFavorite, isArchived, category, noteType, tags, attachments, isLocked, reminderTime, createdAt, updatedAt, colorValue, isDeleted, folderId, isHabit, habitRecurrence, habitStreak, habitLastCompleted, previewText, paperSettings,
      CASE WHEN noteType = 'checklist' THEN content ELSE SUBSTR(content, 1, 150) END AS content
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
      CASE WHEN noteType = 'checklist' THEN content ELSE SUBSTR(content, 1, 120) END AS content
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
  }
}
