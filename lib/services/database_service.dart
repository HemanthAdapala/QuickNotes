import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

    // Open/Create the database (version 7)
    return await openDatabase(
      path,
      version: 7,
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
    return await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Read All
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
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'isPinned DESC, updatedAt DESC',
    );
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
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  // Delete
  Future<int> delete(String id) async {
    if (kIsWeb) {
      _webNotes.removeWhere((n) => n.id == id);
      return 1;
    }
    final db = await instance.database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Read Single Note
  Future<Note?> queryById(String id) async {
    if (kIsWeb) {
      final matches = _webNotes.where((n) => n.id == id);
      return matches.isEmpty ? null : matches.first;
    }
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  // Search Notes
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
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'isPinned DESC, updatedAt DESC',
    );
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  // --- Folder Operations ---
  Future<int> insertFolder(Folder folder) async {
    if (kIsWeb) {
      _webFolders.removeWhere((f) => f.id == folder.id);
      _webFolders.add(folder);
      return 1;
    }
    final db = await instance.database;
    return await db.insert(
      'folders',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Folder>> queryAllFolders() async {
    if (kIsWeb) {
      final list = List<Folder>.from(_webFolders);
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    }
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('folders', orderBy: 'name ASC');
    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<int> deleteFolder(String id) async {
    if (kIsWeb) {
      _webFolders.removeWhere((f) => f.id == id);
      return 1;
    }
    final db = await instance.database;
    return await db.delete(
      'folders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
