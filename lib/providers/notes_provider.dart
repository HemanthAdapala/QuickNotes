import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:home_widget/home_widget.dart' as home_widget;
import '../models/note.dart';
import '../models/folder.dart';
import '../models/note_summary.dart';
import '../services/database_service.dart';
import '../services/vault_service.dart';

enum SortOption { newest, oldest, alphabetical }
enum NotesViewType { feed, archive, favorites, trash }

class NotesProvider with ChangeNotifier {
  List<Note> _notes = [];
  List<Folder> _folders = [];
  bool _isLoading = false;

  int _currentPage = 0;
  bool _hasMoreNotes = true;
  bool _isPageLoading = false;
  final Map<int, List<NoteSummary>> _pageCache = {};
  List<NoteSummary> _notesSummary = [];

  bool get hasMoreNotes => _hasMoreNotes;
  bool get isPageLoading => _isPageLoading;
  List<NoteSummary> get notesSummary => _notesSummary;
  String _searchQuery = "";
  Timer? _searchDebouncer;
  SortOption _currentSort = SortOption.newest;
  NotesViewType _currentView = NotesViewType.feed;
  String _selectedCategory = "All";
  String _selectedTag = ""; // Tag filter
  String? _selectedFolderId; // Selected folder filter
  
  // Vault state
  bool _isVaultUnlocked = false;
  
  // Theme and Zen settings state
  bool _isDarkMode = false;
  bool _isZenModeEnabled = false;

  // Predefined default categories
  static const List<String> categories = [
    'Personal',
    'Work',
    'Ideas',
    'Study',
    'Uncategorized'
  ];

  // Getters
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  SortOption get currentSort => _currentSort;
  NotesViewType get currentView => _currentView;
  String get selectedCategory => _selectedCategory;
  String get selectedTag => _selectedTag;
  String? get selectedFolderId => _selectedFolderId;
  bool get isVaultUnlocked => _isVaultUnlocked;
  bool get isDarkMode => false;
  bool get isZenModeEnabled => _isZenModeEnabled;
  List<Folder> get folders => _folders;
  List<Note> get trashNotes => _notes.where((n) => n.isDeleted).toList();
  List<Note> get allActiveNotes => _notes.where((n) => !n.isDeleted).toList();

  void setNotesForTesting(List<Note> testNotes) {
    _notes = testNotes;
    notifyListeners();
  }

  // Filter notes in-memory dynamically based on view type, folder, category, and active tags
  List<Note> get notes {
    // 1. Filter by View Type
    List<Note> list = [];
    if (_currentView == NotesViewType.feed) {
      list = _notes.where((n) => !n.isArchived && !n.isDeleted).toList();
    } else if (_currentView == NotesViewType.archive) {
      list = _notes.where((n) => n.isArchived && !n.isDeleted).toList();
    } else if (_currentView == NotesViewType.favorites) {
      list = _notes.where((n) => n.isFavorite && !n.isArchived && !n.isDeleted).toList();
    } else if (_currentView == NotesViewType.trash) {
      list = _notes.where((n) => n.isDeleted).toList();
    }

    // 2. Filter by Folder
    if (_selectedFolderId != null) {
      list = list.where((n) => n.folderId == _selectedFolderId).toList();
    } else if (_currentView == NotesViewType.feed && _selectedCategory != "All") {
      // 3. Filter by Category (only if no specific folder is selected to prevent conflicts)
      list = list.where((n) => n.category == _selectedCategory).toList();
    }

    // 4. Filter by Tag
    if (_currentView == NotesViewType.feed && _selectedTag.isNotEmpty) {
      list = list.where((n) => n.tags.contains(_selectedTag)).toList();
    }

    // 5. Sort list (preserving pin logic)
    final pinned = list.where((n) => n.isPinned).toList();
    final unpinned = list.where((n) => !n.isPinned).toList();

    void sortList(List<Note> listToSort) {
      switch (_currentSort) {
        case SortOption.newest:
          listToSort.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          break;
        case SortOption.oldest:
          listToSort.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
          break;
        case SortOption.alphabetical:
          listToSort.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          break;
      }
    }

    sortList(pinned);
    sortList(unpinned);

    return [...pinned, ...unpinned];
  }

  // Retrieve list of all unique tags across all notes
  List<String> get allTags {
    final Set<String> uniqueTags = {};
    for (var note in _notes) {
      uniqueTags.addAll(note.tags);
    }
    return uniqueTags.toList();
  }

  final _uuid = const Uuid();
  final _dbService = DatabaseService.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  NotesProvider() {
    _isDarkMode = false;
    _initNotifications();
    loadFolders();
    loadNotes();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  void setZenMode(bool value) {
    _isZenModeEnabled = value;
    notifyListeners();
  }

  // Initialize notifications helper
  Future<void> _initNotifications() async {
    try {
      tz.initializeTimeZones();
      
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint("Note notification tapped. Payload ID: ${details.payload}");
        },
      );
    } catch (e) {
      debugPrint("Error initializing notifications: $e");
    }
  }

  // --- Vault Master operations ---
  Future<bool> unlockVault(String pin) async {
    final success = await VaultService.instance.verifyPin(pin);
    if (success) {
      _isVaultUnlocked = true;
      await loadNotes();
    }
    return success;
  }

  Future<bool> unlockVaultBiometrically() async {
    final success = await VaultService.instance.authenticateBiometrically();
    if (success) {
      _isVaultUnlocked = true;
      await loadNotes();
    }
    return success;
  }

  void lockVault() {
    _isVaultUnlocked = false;
    loadNotes();
  }

  // Static list of premium color options (represented as indices 0-7)
  static const List<String> colorNames = [
    'Default',
    'Coral',
    'Peach',
    'Lemon',
    'Sage',
    'Sky',
    'Lavender',
    'Blush'
  ];

  // Resolve color index to light mode background color (Playful Pop pastels)
  static Color getLightColor(int index, BuildContext context) {
    switch (index) {
      case 1: return const Color(0xFFFFAAA6); // Coral
      case 2: return const Color(0xFFFFD3B6); // Peach
      case 3: return const Color(0xFFFFFFA6); // Lemon
      case 4: return const Color(0xFFD4ECDD); // Sage
      case 5: return const Color(0xFFA8DADC); // Sky
      case 6: return const Color(0xFFD6C8FF); // Lavender
      case 7: return const Color(0xFFFFC6FF); // Blush
      case 0:
      default:
        return Theme.of(context).cardColor;
    }
  }

  // Resolve color index to dark mode background color (High-contrast saturated dark pastels)
  static Color getDarkColor(int index, BuildContext context) {
    switch (index) {
      case 1: return const Color(0xFF8C3232); // Coral
      case 2: return const Color(0xFF965228); // Peach
      case 3: return const Color(0xFF7D7D28); // Lemon
      case 4: return const Color(0xFF23443B); // Sage
      case 5: return const Color(0xFF162E4A); // Sky
      case 6: return const Color(0xFF4C2791); // Lavender
      case 7: return const Color(0xFF6A073D); // Blush
      case 0:
      default:
        return Theme.of(context).cardColor;
    }
  }

  // Fetch colors dynamically based on dark/light theme
  static Color getNoteColor(int index, BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      return getDarkColor(index, context);
    }
    return getLightColor(index, context);
  }

  // Fetch appropriate text color for the note contents
  static Color getNoteTextColor(int index, BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (index == 0) {
      return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    }
    if (brightness == Brightness.dark) {
      return Colors.white70;
    }
    return Colors.black87;
  }

  // Fetch appropriate title color for the note contents
  static Color getNoteTitleColor(int index, BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (index == 0) {
      return Theme.of(context).textTheme.titleMedium?.color ?? Colors.black;
    }
    if (brightness == Brightness.dark) {
      return Colors.white;
    }
    return Colors.black87;
  }

  // Fetch category badge tag color
  static Color getCategoryTagColor(int noteColorIndex, BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (noteColorIndex == 0) {
      return Theme.of(context).colorScheme.primaryContainer.withAlpha(80);
    }
    if (brightness == Brightness.dark) {
      return Colors.white.withAlpha(25);
    }
    return Colors.black.withAlpha(15);
  }

  // Cache folder mappings for folder names
  Map<String, String> get _folderNameMap {
    final map = <String, String>{};
    for (final f in _folders) {
      map[f.id] = f.name;
    }
    return map;
  }

  // Clear cache and reset pagination
  void clearPageCache() {
    _pageCache.clear();
    _currentPage = 0;
    _hasMoreNotes = true;
    _notesSummary = [];
  }

  // Load next page
  Future<void> loadNextPage() async {
    if (_isPageLoading || !_hasMoreNotes) return;
    _currentPage++;
    await loadNotesPage();
  }

  Future<void> loadNotesPage({bool refresh = false}) async {
    if (refresh) {
      clearPageCache();
    }
    
    _isPageLoading = true;
    notifyListeners();

    try {
      if (_pageCache.containsKey(_currentPage)) {
        final cached = _pageCache[_currentPage]!;
        _notesSummary.addAll(cached);
        _hasMoreNotes = cached.length == 20; // kPageSize
      } else {
        final folderMap = _folderNameMap;
        const limit = 20;
        final offset = _currentPage * limit;
        
        final isDeleted = _currentView == NotesViewType.trash;
        final isArchived = _currentView == NotesViewType.archive;
        final isFavorite = _currentView == NotesViewType.favorites;
        
        final maps = await _dbService.queryNotesSummaryPaged(
          folderId: _selectedFolderId,
          category: (_selectedFolderId == null && _selectedCategory != "All" && _currentView == NotesViewType.feed) ? _selectedCategory : null,
          isFavorite: isFavorite ? true : null,
          isArchived: isArchived ? true : (_currentView == NotesViewType.feed ? false : null),
          isDeleted: isDeleted,
          limit: limit,
          offset: offset,
        );
        
        final List<NoteSummary> summaries = [];
        for (final map in maps) {
          final isLocked = (map['isLocked'] as int? ?? 0) == 1;
          Map<String, dynamic> processedMap = Map.from(map);
          if (isLocked) {
            if (_isVaultUnlocked) {
              final titleDec = await VaultService.instance.decryptText(map['title'] as String);
              final contentDec = await VaultService.instance.decryptText(map['content'] as String? ?? '');
              processedMap['title'] = titleDec;
              processedMap['content'] = contentDec;
            } else {
              processedMap['title'] = "🔐 Locked Note";
              processedMap['content'] = "[Unlocked with authentication]";
            }
          }
          final fId = map['folderId'] as String?;
          final fName = fId != null ? folderMap[fId] : null;
          final cat = map['category'] as String? ?? 'Uncategorized';
          final catColor = _getCategoryColorValue(cat);
          summaries.add(NoteSummary.fromMap(processedMap, folderName: fName, categoryColor: catColor));
        }
        
        _pageCache[_currentPage] = summaries;
        _notesSummary.addAll(summaries);
        _hasMoreNotes = summaries.length == limit;
      }
    } catch (e) {
      debugPrint("Error loading notes page: $e");
    } finally {
      _isPageLoading = false;
      notifyListeners();
    }
  }

  int? _getCategoryColorValue(String category) {
    switch (category.toLowerCase()) {
      case 'personal': return const Color(0xFF78C291).value;
      case 'work': return const Color(0xFF4A90E2).value;
      case 'study': return const Color(0xFFA388E8).value;
      case 'ideas': return const Color(0xFFF5D44A).value;
      case 'important': return const Color(0xFFE57373).value;
      case 'unimportant': return const Color(0xFFFF7043).value;
      case 'uncategorized':
      default:
        return null;
    }
  }

  Future<Note?> getNoteById(String id) async {
    try {
      final note = await _dbService.queryById(id);
      if (note == null) return null;
      if (note.isLocked) {
        if (_isVaultUnlocked) {
          final titleDec = await VaultService.instance.decryptText(note.title);
          final contentDec = await VaultService.instance.decryptText(note.content);
          return note.copyWith(title: titleDec, content: contentDec);
        } else {
          return note.copyWith(title: "🔐 Locked Note", content: "[Unlocked with authentication]");
        }
      }
      return note;
    } catch (e) {
      debugPrint("Error getting note by id: $e");
      return null;
    }
  }

  // Load notes from Database
  Future<void> loadNotes() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Run habits completion resets
      await _checkAndResetHabits();

      // Refresh paginated summaries
      await loadNotesPage(refresh: true);

      List<Note> rawNotes = [];
      if (_searchQuery.trim().isEmpty) {
        rawNotes = await _dbService.queryAll();
      } else {
        if (_isVaultUnlocked) {
          rawNotes = await _dbService.queryAll();
        } else {
          rawNotes = await _dbService.search(_searchQuery);
        }
      }

      // Decrypt notes in memory concurrently if vault is unlocked, else scrub sensitive text
      final List<Future<Note>> futures = rawNotes.map((note) async {
        if (note.isLocked) {
          if (_isVaultUnlocked) {
            final titleDec = await VaultService.instance.decryptText(note.title);
            final contentDec = await VaultService.instance.decryptText(note.content);
            return note.copyWith(title: titleDec, content: contentDec);
          } else {
            return note.copyWith(title: "🔐 Locked Note", content: "[Unlocked with authentication]");
          }
        } else {
          return note;
        }
      }).toList();

      _notes = await Future.wait(futures);

      // Apply in-memory search filter if search was conducted while vault is unlocked
      if (_searchQuery.trim().isNotEmpty && _isVaultUnlocked) {
        final query = _searchQuery.toLowerCase();
        _notes = _notes.where((n) {
          final titleMatch = n.title.toLowerCase().contains(query);
          final contentMatch = n.content.toLowerCase().contains(query);
          final tagMatch = n.tags.any((t) => t.toLowerCase().contains(query));
          return titleMatch || contentMatch || tagMatch;
        }).toList();
      }

      // Send pinned note stats to HomeWidget
      await _updateWidgetData();
    } catch (e) {
      debugPrint("Error loading notes: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a new note
  Future<void> addNote({
    required String title,
    required String content,
    required int colorIndex,
    String category = 'Uncategorized',
    String noteType = 'text',
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    bool isPinned = false,
    bool isFavorite = false,
    bool isArchived = false,
    bool isLocked = false,
    DateTime? reminderTime,
    String? folderId,
    bool isHabit = false,
    String habitRecurrence = 'none',
    String paperGuideType = 'lines_extra_tight',
    bool paperGuideVisible = true,
    double paperGuideHeight = 1.05,
    double paperGuideOpacity = 0.15,
    int paperGuideColor = 0,
  }) async {
    String finalTitle = title;
    String finalContent = content;

    if (isLocked) {
      finalTitle = await VaultService.instance.encryptText(title);
      finalContent = await VaultService.instance.encryptText(content);
    }

    final newNote = Note(
      id: _uuid.v4(),
      title: finalTitle,
      content: finalContent,
      isPinned: isPinned,
      isFavorite: isFavorite,
      isArchived: isArchived,
      category: category,
      noteType: noteType,
      tags: tags,
      attachments: attachments,
      isLocked: isLocked,
      reminderTime: reminderTime,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      colorValue: colorIndex,
      folderId: folderId,
      isHabit: isHabit,
      habitRecurrence: habitRecurrence,
      habitStreak: 0,
      paperGuideType: paperGuideType,
      paperGuideVisible: paperGuideVisible,
      paperGuideHeight: paperGuideHeight,
      paperGuideOpacity: paperGuideOpacity,
      paperGuideColor: paperGuideColor,
    );

    try {
      await _dbService.insert(newNote);
      if (reminderTime != null) {
        await _scheduleReminder(newNote);
      }
      await loadNotes();
    } catch (e) {
      debugPrint("Error adding note: $e");
    }
  }

  // Import a note directly into the database
  Future<void> importNote(Note note) async {
    try {
      await _dbService.insert(note);
      await loadNotes();
    } catch (e) {
      debugPrint("Error importing note: $e");
    }
  }

  // Restore a deleted note (Undo action)
  Future<void> restoreNote(Note note) async {
    try {
      await _dbService.insert(note);
      if (note.reminderTime != null) {
        await _scheduleReminder(note);
      }
      await loadNotes();
    } catch (e) {
      debugPrint("Error restoring note: $e");
    }
  }

  // Update an existing note
  Future<void> updateNote(Note updatedNote) async {
    String finalTitle = updatedNote.title;
    String finalContent = updatedNote.content;

    if (updatedNote.isLocked) {
      finalTitle = await VaultService.instance.encryptText(updatedNote.title);
      finalContent = await VaultService.instance.encryptText(updatedNote.content);
    }

    final noteToSave = updatedNote.copyWith(
      title: finalTitle,
      content: finalContent,
      updatedAt: DateTime.now(),
    );

    try {
      await _dbService.update(noteToSave);
      
      // Update reminder notification
      await _cancelReminder(updatedNote.id);
      if (noteToSave.reminderTime != null) {
        await _scheduleReminder(noteToSave);
      }
      
      await loadNotes();
    } catch (e) {
      debugPrint("Error updating note: $e");
    }
  }

  // Soft delete a note (Move to Trash)
  Future<void> trashNote(String id) async {
    try {
      final rawNote = await _dbService.queryById(id);
      if (rawNote != null) {
        final updatedNote = rawNote.copyWith(isDeleted: true);
        await _dbService.update(updatedNote);
        await _cancelReminder(id);
        await loadNotes();
      }
    } catch (e) {
      debugPrint("Error trashing note: $e");
    }
  }

  // Restore a note from Trash
  Future<void> restoreFromTrash(String id) async {
    try {
      final rawNote = await _dbService.queryById(id);
      if (rawNote != null) {
        final updatedNote = rawNote.copyWith(isDeleted: false);
        await _dbService.update(updatedNote);
        if (updatedNote.reminderTime != null) {
          await _scheduleReminder(updatedNote);
        }
        await loadNotes();
      }
    } catch (e) {
      debugPrint("Error restoring note from trash: $e");
    }
  }

  // Restore note alias for trash screen compatibility
  Future<void> restoreNoteFromTrash(String id) async {
    await restoreFromTrash(id);
  }

  // Permanently delete a note (Hard delete)
  Future<void> deleteNote(String id) async {
    try {
      await _cancelReminder(id);
      await _dbService.delete(id);
      await loadNotes();
    } catch (e) {
      debugPrint("Error deleting note: $e");
    }
  }

  // Empty all notes in the Trash
  Future<void> emptyTrash() async {
    try {
      final trashNotes = _notes.where((n) => n.isDeleted).toList();
      for (var note in trashNotes) {
        await _dbService.delete(note.id);
      }
      await loadNotes();
    } catch (e) {
      debugPrint("Error emptying trash: $e");
    }
  }

  // Toggle Pinned Status
  Future<void> togglePin(String id) async {
    try {
      final rawNote = await _dbService.queryById(id);
      if (rawNote != null) {
        final updatedNote = rawNote.copyWith(isPinned: !rawNote.isPinned);
        await _dbService.update(updatedNote);
        await loadNotes();
      }
    } catch (e) {
      debugPrint("Error toggling pin: $e");
    }
  }

  // Toggle Favorite Status
  Future<void> toggleFavorite(String id) async {
    try {
      final rawNote = await _dbService.queryById(id);
      if (rawNote != null) {
        final updatedNote = rawNote.copyWith(isFavorite: !rawNote.isFavorite);
        await _dbService.update(updatedNote);
        await loadNotes();
      }
    } catch (e) {
      debugPrint("Error toggling favorite: $e");
    }
  }

  // Toggle Archive Status
  Future<void> toggleArchive(String id) async {
    try {
      final rawNote = await _dbService.queryById(id);
      if (rawNote != null) {
        final updatedNote = rawNote.copyWith(isArchived: !rawNote.isArchived);
        await _dbService.update(updatedNote);
        await loadNotes();
      }
    } catch (e) {
      debugPrint("Error toggling archive: $e");
    }
  }

  // Set Navigation View Type
  void setViewType(NotesViewType view) {
    _currentView = view;
    _selectedTag = "";
    _selectedFolderId = null; // Clear folder when moving to tabs
    loadNotes();
  }

  // Set Active Category Filter
  void setSelectedCategory(String category) {
    _selectedCategory = category;
    _selectedFolderId = null; // Clear folder filter if selecting category
    loadNotes();
  }

  // Set Tag Filter
  void setSelectedTag(String tag) {
    _selectedTag = tag;
    loadNotes();
  }

  // Set Search Query
  void setSearchQuery(String query) {
    _searchQuery = query;
    if (_searchDebouncer?.isActive ?? false) {
      _searchDebouncer!.cancel();
    }
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      loadNotes();
    });
  }

  // Set Sorting Option
  void setSortOption(SortOption option) {
    _currentSort = option;
    loadNotes();
  }

  // --- Folder Operations ---
  void setSelectedFolder(String? folderId) {
    _selectedFolderId = folderId;
    _selectedCategory = "All"; // Reset category to avoid overlapping filters
    loadNotes();
  }

  Future<void> loadFolders() async {
    try {
      _folders = await _dbService.queryAllFolders();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading folders: $e");
    }
  }

  Future<void> createFolder(String name, {String? parentId}) async {
    final folder = Folder(
      id: _uuid.v4(),
      name: name,
      parentId: parentId,
      createdAt: DateTime.now(),
    );
    try {
      await _dbService.insertFolder(folder);
      await loadFolders();
    } catch (e) {
      debugPrint("Error creating folder: $e");
    }
  }

  Future<void> deleteFolder(String id) async {
    try {
      // Detach notes referencing this folder in the database to prevent data loss (DB-level optimized)
      await _dbService.detachNotesFromFolder(id);
      
      // Detach child folders referencing this parent folder (DB-level optimized)
      await _dbService.detachChildFolders(id);

      await _dbService.deleteFolder(id);
      if (_selectedFolderId == id) {
        _selectedFolderId = null;
      }
      await loadFolders();
      await loadNotes();
    } catch (e) {
      debugPrint("Error deleting folder: $e");
    }
  }

  // --- Habit Checklists Reset Engine ---
  Future<void> _checkAndResetHabits() async {
    final rawNotes = await _dbService.queryHabits();
    for (int i = 0; i < rawNotes.length; i++) {
      final note = rawNotes[i];
      if (note.isHabit && note.noteType == 'checklist' && note.habitRecurrence != 'none') {
        final lastCompleted = note.habitLastCompleted;
        final now = DateTime.now();

        bool shouldReset = false;
        if (lastCompleted == null) {
          shouldReset = true;
        } else {
          if (note.habitRecurrence == 'daily') {
            final lastDay = DateTime(lastCompleted.year, lastCompleted.month, lastCompleted.day);
            final today = DateTime(now.year, now.month, now.day);
            if (today.isAfter(lastDay)) {
              shouldReset = true;
            }
          } else if (note.habitRecurrence == 'weekly') {
            final difference = now.difference(lastCompleted).inDays;
            if (difference >= 7 || now.weekday < lastCompleted.weekday) {
              shouldReset = true;
            }
          }
        }

        if (shouldReset) {
          // Decrypt content programmatically if locked to prevent data corruption
          String decryptedContent = note.content;
          if (note.isLocked) {
            decryptedContent = await VaultService.instance.decryptText(note.content);
          }

          bool allCompleted = false;
          List<dynamic> items = [];
          try {
            items = jsonDecode(decryptedContent) as List<dynamic>;
            if (items.isNotEmpty) {
              allCompleted = items.every((item) => item['checked'] == true || item['done'] == true);
            }
          } catch (_) {}

          int newStreak = note.habitStreak;
          if (allCompleted) {
            newStreak += 1;
          } else {
            newStreak = 0; // Reset streak on miss
          }

          // Uncheck items for the new period, resetting both potential keys for safety
          final resetItems = items.map((item) {
            final copy = Map<String, dynamic>.from(item);
            if (copy.containsKey('checked')) {
              copy['checked'] = false;
            }
            if (copy.containsKey('done')) {
              copy['done'] = false;
            }
            if (!copy.containsKey('checked') && !copy.containsKey('done')) {
              copy['done'] = false;
            }
            return copy;
          }).toList();

          String updatedContent = jsonEncode(resetItems);
          if (note.isLocked) {
            updatedContent = await VaultService.instance.encryptText(updatedContent);
          }

          final updatedNote = note.copyWith(
            content: updatedContent,
            habitStreak: newStreak,
            habitLastCompleted: now,
          );

          await _dbService.update(updatedNote);
        }
      }
    }
  }

  // --- Home Screen Widget Synchronization ---
  Future<void> _updateWidgetData() async {
    try {
      final pinnedCount = _notes.where((n) => n.isPinned).length;
      await home_widget.HomeWidget.saveWidgetData<String>('pinned_count', pinnedCount.toString());
      await home_widget.HomeWidget.updateWidget(
        name: 'QuickCaptureWidget',
        androidName: 'QuickCaptureWidget',
      );
    } catch (e) {
      debugPrint("Error updating home widget data: $e");
    }
  }

  // --- Local Alarms Scheduled Notification Helpers ---
  Future<void> _scheduleReminder(Note note) async {
    if (note.reminderTime == null) return;
    
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    final id = note.id.hashCode;
    
    try {
      final reminderDate = note.reminderTime!;
      if (reminderDate.isBefore(DateTime.now())) return;

      const androidDetails = AndroidNotificationDetails(
        'quicknotes_reminders_channel',
        'Note Reminders',
        channelDescription: 'Alarms and notification alerts for note reminders',
        importance: Importance.max,
        priority: Priority.high,
      );
      
      const details = NotificationDetails(android: androidDetails);
      final tzDateTime = tz.TZDateTime.from(reminderDate, tz.local);

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: "Reminder: ${note.title.isNotEmpty ? note.title : 'Untitled'}",
        body: note.noteType == 'checklist' 
            ? "Your task list is waiting" 
            : (note.content.length > 50 ? "${note.content.substring(0, 50)}..." : note.content),
        scheduledDate: tzDateTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: note.id,
      );
      debugPrint("Scheduled alarm for note ${note.id} at $tzDateTime");
    } catch (e) {
      debugPrint("Error scheduling alarm: $e");
    }
  }

  Future<void> _cancelReminder(String noteId) async {
    try {
      await _notificationsPlugin.cancel(id: noteId.hashCode);
      debugPrint("Cancelled alarm for note $noteId");
    } catch (e) {
      debugPrint("Error cancelling alarm: $e");
    }
  }
}
