// ──────────────────────────────────────────────────────────────────────────────
// search_screen.dart — Quick Notes Search Screen
//
// FOUR STATES:
//   empty      → Recent searches + Browse by category
//   typing     → Live results loading (after 2+ chars)
//   results    → Grouped results with amber match highlights
//   noResults  → Empty state + "Create new note" shortcut
//
// DESIGN TOKENS (from Home Screen / AppColors):
//   Background : Color(0xFFF9F6E5)   AppColors.background
//   Ink        : Color(0xFF333333)   AppColors.ink
//   Amber      : Color(0xFFFFA322)   AppColors.amber
//   Placeholder: Color(0x73333333)   AppColors.placeholder
//   White      : Color(0xFFFFFFFF)
//
// TYPOGRAPHY:
//   Section labels : GoogleFonts.jetBrainsMono
//   Card titles    : GoogleFonts.playfairDisplay
//   Body / chips   : GoogleFonts.inter
//
// ANIMATIONS: All values from animation_constants.dart — no hardcoded Duration.
// ──────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/animations/animation_constants.dart';
import '../../core/animations/animated_list_entrance.dart';
import '../../core/animations/page_transitions.dart';
import '../../models/folder.dart';
import '../../models/note.dart';
import '../../models/task_item.dart';
import '../../providers/notes_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../services/recent_searches_service.dart';
import '../widgets/living_writing_experience.dart';
import 'note_editor_screen.dart';
import 'create_task_screen.dart';
import 'folder_notes_screen.dart';
import 'category_details_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum _Scope { all, notes, tasks, folders, categories }

enum _DateFilter { allTime, today, thisWeek, thisMonth }

enum _UiState { empty, typing, results, noResults }

// ─────────────────────────────────────────────────────────────────────────────
// Design constants
// ─────────────────────────────────────────────────────────────────────────────

const Color _kBg          = Color(0xFFFFFFFF);
const Color _kInk         = Color(0xFF333333);
const Color _kAmber       = Color(0xFFFFCC00);
const Color _kPlaceholder = Color(0x73333333);
const Color _kChipActive  = Color(0xFFF5A623);
const Color _kChipActiveTxt = Color(0xFFFFFFFF);
const Color _kChipInactive = Color(0xFFE9E1D9);
const Color _kChipInactiveTxt = Color(0xFF524534);
const Color _kFilterBg    = Color(0xFFEEEBDB);
const Color _kCardBorder  = Color(0x22333333);
const Color _kSectionLabel = Color(0xFF8C8987);
const Color _kDivider     = Color(0xFFE6E3D2);
const double _kBorderRadius = 16.0;

// Category accent colours (mirrors category_details_screen.dart)
const Map<String, Color> _kCategoryDotColors = {
  'Personal':      Color(0xFF4A90D9),
  'Work':          Color(0xFF4CAF50),
  'Ideas':         Color(0xFFFFB800),
  'Study':         Color(0xFFE91E63),
  'Hobbies':       Color(0xFF9C27B0),
  'Recipes':       Color(0xFF64B5F6),
  'Uncategorized': Color(0xFF9E9E9E),
};

Color _categoryDotColor(String category) {
  if (_kCategoryDotColors.containsKey(category)) return _kCategoryDotColors[category]!;
  final hue = (category.hashCode.abs() % 360).toDouble();
  return HSLColor.fromAHSL(1.0, hue, 0.55, 0.50).toColor();
}


Color _noteCardColor(int colorValue) {
  switch (colorValue) {
    case 1: return const Color(0xFFFFAAA6); // Coral
    case 2: return const Color(0xFFFFD3B6); // Peach
    case 3: return const Color(0xFFFFFFA6); // Lemon
    case 4: return const Color(0xFFD4ECDD); // Sage
    case 5: return const Color(0xFFA8DADC); // Sky
    case 6: return const Color(0xFFD6C8FF); // Lavender
    case 7: return const Color(0xFFFFC6FF); // Blush
    default: return const Color(0xFFFFFDF7);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SearchScreen
// ─────────────────────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  /// 'all' | 'notes' | 'tasks' | 'folders' | 'categories'
  final String initialScope;

  /// Folder id to pre-filter (from Folder Detail entry).
  final String? presetFolder;

  /// Category name to pre-filter (from Category Detail entry).
  final String? presetCategory;

  const SearchScreen({
    super.key,
    this.initialScope = 'all',
    this.presetFolder,
    this.presetCategory,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {

  // ── Controllers ─────────────────────────────────────────────────────────

  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  // ── Debounce ─────────────────────────────────────────────────────────────

  Timer? _debounce;

  // ── State ─────────────────────────────────────────────────────────────────

  _Scope       _scope       = _Scope.all;
  _DateFilter  _dateFilter  = _DateFilter.allTime;
  _UiState     _uiState     = _UiState.empty;
  bool         _isLoading   = false;

  String? _filterFolderId;
  String? _filterCategory;

  String _query = '';

  // Results — all loaded once, then filtered client-side
  List<Note>     _allNoteResults      = [];
  List<TaskItem> _allTaskResults      = [];
  List<Folder>   _allFolderResults    = [];
  List<String>   _allCategoryResults  = [];

  // Displayed (after scope + filter)
  List<Note>     _noteResults     = [];
  List<TaskItem> _taskResults     = [];
  List<Folder>   _folderResults   = [];
  List<String>   _categoryResults = [];

  // Recent searches
  List<String> _recentSearches = [];

  // Result animation key — change to reset stagger
  int _resultGeneration = 0;

  // Entry fade animation
  late AnimationController _entryCtrl;
  late Animation<double>    _entryFade;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Map initialScope string to enum
    _scope = _scopeFromString(widget.initialScope);

    // Pre-set filters from entry context
    _filterFolderId  = widget.presetFolder;
    _filterCategory  = widget.presetCategory;

    // Entry fade animation
    _entryCtrl = AnimationController(vsync: this, duration: kDurationNormal);
    _entryFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: kCurveEnter));
    _entryCtrl.forward();

    // Load recent searches
    _loadRecentSearches();

    // Auto-focus keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    _queryCtrl.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.removeListener(_onQueryChanged);
    _queryCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Recent searches ───────────────────────────────────────────────────────

  Future<void> _loadRecentSearches() async {
    final searches = await RecentSearchesService.instance.load();
    if (mounted) setState(() => _recentSearches = searches);
  }

  Future<void> _saveSearch(String term) async {
    final updated = await RecentSearchesService.instance.addSearch(term);
    if (mounted) setState(() => _recentSearches = updated);
  }

  Future<void> _removeSearch(String term) async {
    final updated = await RecentSearchesService.instance.removeSearch(term);
    if (mounted) setState(() => _recentSearches = updated);
  }

  Future<void> _clearAllSearches() async {
    await RecentSearchesService.instance.clearAll();
    if (mounted) setState(() => _recentSearches = []);
  }

  // ── Query handling ────────────────────────────────────────────────────────

  void _onQueryChanged() {
    final text = _queryCtrl.text;
    setState(() {
      _query = text;
      if (text.isEmpty) {
        _uiState = _UiState.empty;
        _isLoading = false;
        _debounce?.cancel();
        _clearResults();
        return;
      }
      if (text.length >= 2) {
        _uiState = _UiState.typing;
        _isLoading = true;
      }
    });

    _debounce?.cancel();
    if (text.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _runSearch(text);
      });
    }
  }

  void _clearResults() {
    _allNoteResults = [];
    _allTaskResults = [];
    _allFolderResults = [];
    _allCategoryResults = [];
    _noteResults = [];
    _taskResults = [];
    _folderResults = [];
    _categoryResults = [];
  }

  void _runSearch(String query) {
    if (!mounted) return;
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);

    final q = query.toLowerCase();

    // Notes (non-deleted, non-archived)
    final notes = notesProvider.allActiveNotes.where((n) =>
      n.title.toLowerCase().contains(q) ||
      n.previewText.toLowerCase().contains(q)
    ).toList();

    // Standalone Tasks (from tasksProvider)
    final tasks = tasksProvider.tasks.where((t) =>
      t.title.toLowerCase().contains(q) || t.description.toLowerCase().contains(q)
    ).toList();

    // Folders
    final folders = notesProvider.folders.where((f) =>
      f.name.toLowerCase().contains(q)
    ).toList();

    // Categories
    final allCats = <String>{...NotesProvider.categories};
    for (final n in notesProvider.allActiveNotes) {
      allCats.add(n.category);
    }
    final categories = allCats.where((c) =>
      c.toLowerCase().contains(q)
    ).toList();

    if (!mounted) return;

    setState(() {
      _allNoteResults     = notes;
      _allTaskResults     = tasks;
      _allFolderResults   = folders;
      _allCategoryResults = categories;
      _isLoading = false;
      _resultGeneration++;
      _applyFilters();
      _uiState = (_noteResults.isEmpty &&
                  _taskResults.isEmpty &&
                  _folderResults.isEmpty &&
                  _categoryResults.isEmpty)
          ? _UiState.noResults
          : _UiState.results;

      // Save successful searches
      if (_uiState == _UiState.results) _saveSearch(query.trim());
    });
  }

  void _applyFilters() {
    var notes  = List<Note>.from(_allNoteResults);
    var tasks  = List<TaskItem>.from(_allTaskResults);
    var folders = List<Folder>.from(_allFolderResults);
    var cats   = List<String>.from(_allCategoryResults);

    // Folder filter
    if (_filterFolderId != null) {
      notes = notes.where((n) => n.folderId == _filterFolderId).toList();
      tasks = tasks.where((t) => t.folderId == _filterFolderId).toList();
    }

    // Category filter
    if (_filterCategory != null) {
      notes = notes.where((n) => n.category == _filterCategory).toList();
      tasks = tasks.where((t) => (t.categoryId == _filterCategory || t.priority == _filterCategory)).toList();
    }

    // Date filter
    final now = DateTime.now();
    notes = _applyDateFilter(notes, now);
    tasks = _applyTaskDateFilter(tasks, now);

    // Scope filter
    switch (_scope) {
      case _Scope.all:
        break;
      case _Scope.notes:
        tasks = []; folders = []; cats = [];
        break;
      case _Scope.tasks:
        notes = []; folders = []; cats = [];
        break;
      case _Scope.folders:
        notes = []; tasks = []; cats = [];
        break;
      case _Scope.categories:
        notes = []; tasks = []; folders = [];
        break;
    }

    _noteResults     = notes;
    _taskResults     = tasks;
    _folderResults   = folders;
    _categoryResults = cats;
  }

  List<Note> _applyDateFilter(List<Note> list, DateTime now) {
    switch (_dateFilter) {
      case _DateFilter.allTime:
        return list;
      case _DateFilter.today:
        return list.where((n) => _isSameDay(n.updatedAt, now)).toList();
      case _DateFilter.thisWeek:
        final weekAgo = now.subtract(const Duration(days: 7));
        return list.where((n) => n.updatedAt.isAfter(weekAgo)).toList();
      case _DateFilter.thisMonth:
        return list.where((n) =>
          n.updatedAt.year == now.year && n.updatedAt.month == now.month
        ).toList();
    }
  }

  List<TaskItem> _applyTaskDateFilter(List<TaskItem> list, DateTime now) {
    switch (_dateFilter) {
      case _DateFilter.allTime:
        return list;
      case _DateFilter.today:
        return list.where((t) => _isSameDay(t.dueDate.toLocal(), now)).toList();
      case _DateFilter.thisWeek:
        final weekAgo = now.subtract(const Duration(days: 7));
        return list.where((t) => t.dueDate.toLocal().isAfter(weekAgo)).toList();
      case _DateFilter.thisMonth:
        return list.where((t) {
          final localDue = t.dueDate.toLocal();
          return localDue.year == now.year && localDue.month == now.month;
        }).toList();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

  void _onScopeChanged(_Scope scope) {
    HapticFeedback.selectionClick();
    setState(() {
      _scope = scope;
      if (_uiState == _UiState.results || _uiState == _UiState.noResults) {
        _applyFilters();
        _uiState = (_noteResults.isEmpty && _taskResults.isEmpty &&
                    _folderResults.isEmpty && _categoryResults.isEmpty)
            ? _UiState.noResults
            : _UiState.results;
      }
    });
  }

  void _onDateFilterChanged(_DateFilter df) {
    setState(() {
      _dateFilter = df;
      if (_uiState == _UiState.results || _uiState == _UiState.noResults) {
        _applyFilters();
        _uiState = (_noteResults.isEmpty && _taskResults.isEmpty &&
                    _folderResults.isEmpty && _categoryResults.isEmpty)
            ? _UiState.noResults
            : _UiState.results;
      }
    });
  }

  void _onFolderFilterChanged(String? folderId) {
    setState(() {
      _filterFolderId = folderId;
      if (_uiState == _UiState.results || _uiState == _UiState.noResults) {
        _applyFilters();
        _uiState = (_noteResults.isEmpty && _taskResults.isEmpty &&
                    _folderResults.isEmpty && _categoryResults.isEmpty)
            ? _UiState.noResults
            : _UiState.results;
      }
    });
  }

  void _onCategoryFilterChanged(String? cat) {
    setState(() {
      _filterCategory = cat;
      if (_uiState == _UiState.results || _uiState == _UiState.noResults) {
        _applyFilters();
        _uiState = (_noteResults.isEmpty && _taskResults.isEmpty &&
                    _folderResults.isEmpty && _categoryResults.isEmpty)
            ? _UiState.noResults
            : _UiState.results;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _filterFolderId = null;
      _filterCategory = null;
      _dateFilter     = _DateFilter.allTime;
      if (_uiState == _UiState.results || _uiState == _UiState.noResults) {
        _applyFilters();
        _uiState = (_noteResults.isEmpty && _taskResults.isEmpty &&
                    _folderResults.isEmpty && _categoryResults.isEmpty)
            ? _UiState.noResults
            : _UiState.results;
      }
    });
  }

  void _searchAllFolders() {
    setState(() {
      _filterFolderId = null;
      _filterCategory = null;
      _dateFilter     = _DateFilter.allTime;
      _scope          = _Scope.all;
      if (_uiState == _UiState.results || _uiState == _UiState.noResults) {
        _applyFilters();
        _uiState = (_noteResults.isEmpty && _taskResults.isEmpty &&
                    _folderResults.isEmpty && _categoryResults.isEmpty)
            ? _UiState.noResults
            : _UiState.results;
      }
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openNote(Note note) {
    Navigator.push(context, buildPageRoute(
      NoteEditorScreen(note: note),
    ));
  }

  void _openTask(TaskItem task) async {
    await Navigator.push(context, buildPageRoute(
      TaskEditorScreen(
        initialDate: task.dueDate.toLocal(),
        taskToEdit: task,
      ),
    ));
    if (mounted && _query.isNotEmpty) {
      _runSearch(_query);
    }
  }

  void _openFolder(Folder folder) {
    Navigator.push(context, FolderMorphPageRoute(
      cardBounds: Rect.zero,
      builder: (_) => FolderNotesScreen(folder: folder),
    ));
  }

  void _openCategory(String category) {
    Navigator.push(context, buildPageRoute(
      CategoryDetailsScreen(category: category),
    ));
  }

  void _createNoteWithTitle(String title) {
    Navigator.push(context, buildPageRoute(
      const NoteEditorScreen(defaultCategory: 'Uncategorized'),
    ));
  }

  void _tapRecentSearch(String term) {
    _queryCtrl.text = term;
    _queryCtrl.selection = TextSelection.collapsed(offset: term.length);
    // The listener will trigger the search
  }

  void _tapCategoryChip(String category) {
    _queryCtrl.text = category;
    _queryCtrl.selection = TextSelection.collapsed(offset: category.length);
    _scope = _Scope.categories;
  }

  void _cancelSearch() {
    _debounce?.cancel();
    Navigator.of(context).pop();
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  _Scope _scopeFromString(String s) {
    switch (s) {
      case 'notes':      return _Scope.notes;
      case 'tasks':      return _Scope.tasks;
      case 'folders':    return _Scope.folders;
      case 'categories': return _Scope.categories;
      default:           return _Scope.all;
    }
  }

  String _scopeLabel(_Scope s) {
    switch (s) {
      case _Scope.all:        return 'All';
      case _Scope.notes:      return 'Notes';
      case _Scope.tasks:      return 'Tasks';
      case _Scope.folders:    return 'Folders';
      case _Scope.categories: return 'Categories';
    }
  }


  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return GestureDetector(
      // Tapping outside keyboard does NOT dismiss the screen
      onTap: () => FocusScope.of(context).requestFocus(_focusNode),
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Column(
            children: [
              _buildNavBar(topPad),
              _buildScopePills(),
              if (_uiState == _UiState.typing ||
                  _uiState == _UiState.results ||
                  _uiState == _UiState.noResults)
                _buildFilterBar(),
              const Divider(color: _kDivider, height: 1),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Nav bar ───────────────────────────────────────────────────────────────

  Widget _buildNavBar(double topPad) {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          // Back chevron
          _NavIconButton(
            icon: Icons.chevron_left_rounded,
            onTap: _cancelSearch,
          ),

          // Search bar
          Expanded(
            child: Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDD8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kDivider),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search_rounded, size: 18, color: _kPlaceholder),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _queryCtrl,
                      focusNode: _focusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) _saveSearch(v.trim());
                      },
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: _kInk,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Search notes, tasks, folders…',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 15,
                          color: _kPlaceholder,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _queryCtrl.clear();
                        _focusNode.requestFocus();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.cancel_rounded,
                            size: 18, color: _kPlaceholder),
                      ),
                    )
                  else
                    const SizedBox(width: 12),
                ],
              ),
            ),
          ),

          // Cancel
          GestureDetector(
            onTap: _cancelSearch,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kAmber,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scope pills ───────────────────────────────────────────────────────────

  Widget _buildScopePills() {
    const scopes = _Scope.values;
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: scopes.map((s) {
            final isActive = _scope == s;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _onScopeChanged(s),
                child: AnimatedContainer(
                  duration: kDurationFast,
                  curve: kCurveDefault,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? _kChipActive : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? _kChipActive : const Color(0xFFBFB8AA),
                    ),
                  ),
                  child: Text(
                    _scopeLabel(s),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? _kChipActiveTxt : _kChipInactiveTxt,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Filter bar ────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    final provider = Provider.of<NotesProvider>(context, listen: false);

    return Container(
      color: _kFilterBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Folder filter
            _FilterDropdownButton(
              label: _filterFolderId != null
                  ? (provider.folders
                        .where((f) => f.id == _filterFolderId)
                        .firstOrNull?.name ?? 'Folder')
                  : 'Any folder',
              isActive: _filterFolderId != null,
              onTap: () => _showFolderPicker(provider.folders),
            ),
            const SizedBox(width: 8),
            // Category filter
            _FilterDropdownButton(
              label: _filterCategory ?? 'Any category',
              isActive: _filterCategory != null,
              onTap: () => _showCategoryPicker(),
            ),
            const SizedBox(width: 8),
            // Date filter
            _FilterDropdownButton(
              label: _dateFilterLabel(_dateFilter),
              isActive: _dateFilter != _DateFilter.allTime,
              onTap: () => _showDatePicker(),
            ),
          ],
        ),
      ),
    );
  }

  String _dateFilterLabel(_DateFilter df) {
    switch (df) {
      case _DateFilter.allTime:   return 'Any date';
      case _DateFilter.today:     return 'Today';
      case _DateFilter.thisWeek:  return 'This week';
      case _DateFilter.thisMonth: return 'This month';
    }
  }

  void _showFolderPicker(List<Folder> folders) {
    _focusNode.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _kChipInactive,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Filter by Folder',
                    style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _kInk)),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.folder_open_rounded),
                title: Text('Any folder', style: GoogleFonts.inter(color: _kInk)),
                trailing: _filterFolderId == null
                    ? const Icon(Icons.check_rounded, color: _kAmber) : null,
                onTap: () {
                  Navigator.pop(context);
                  _onFolderFilterChanged(null);
                },
              ),
              ...folders.map((f) => ListTile(
                leading: const Icon(Icons.folder_rounded, color: _kAmber),
                title: Text(f.name, style: GoogleFonts.inter(color: _kInk)),
                trailing: _filterFolderId == f.id
                    ? const Icon(Icons.check_rounded, color: _kAmber) : null,
                onTap: () {
                  Navigator.pop(context);
                  _onFolderFilterChanged(f.id);
                  _focusNode.requestFocus();
                },
              )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((_) => _focusNode.requestFocus());
  }

  void _showCategoryPicker() {
    _focusNode.unfocus();
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final cats = <String>{...NotesProvider.categories};
    for (final n in provider.allActiveNotes) { cats.add(n.category); }

    showModalBottomSheet(
      context: context,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _kChipInactive,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Filter by Category',
                    style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _kInk)),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.label_outline_rounded),
                title: Text('Any category', style: GoogleFonts.inter(color: _kInk)),
                trailing: _filterCategory == null
                    ? const Icon(Icons.check_rounded, color: _kAmber) : null,
                onTap: () {
                  Navigator.pop(context);
                  _onCategoryFilterChanged(null);
                },
              ),
              ...cats.map((c) => ListTile(
                leading: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: _categoryDotColor(c),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(c, style: GoogleFonts.inter(color: _kInk)),
                trailing: _filterCategory == c
                    ? const Icon(Icons.check_rounded, color: _kAmber) : null,
                onTap: () {
                  Navigator.pop(context);
                  _onCategoryFilterChanged(c);
                  _focusNode.requestFocus();
                },
              )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((_) => _focusNode.requestFocus());
  }

  void _showDatePicker() {
    _focusNode.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        const options = _DateFilter.values;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _kChipInactive,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Filter by Date',
                    style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _kInk)),
                ),
              ),
              const SizedBox(height: 8),
              ...options.map((df) => ListTile(
                leading: const Icon(Icons.calendar_today_rounded),
                title: Text(_dateFilterLabel(df),
                    style: GoogleFonts.inter(color: _kInk)),
                trailing: _dateFilter == df
                    ? const Icon(Icons.check_rounded, color: _kAmber) : null,
                onTap: () {
                  Navigator.pop(context);
                  _onDateFilterChanged(df);
                  _focusNode.requestFocus();
                },
              )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((_) => _focusNode.requestFocus());
  }

  // ── Body dispatch ─────────────────────────────────────────────────────────

  Widget _buildBody() {
    switch (_uiState) {
      case _UiState.empty:
        return FadeTransition(
          opacity: _entryFade,
          child: _buildEmptyState(),
        );
      case _UiState.typing:
        return _buildTypingState();
      case _UiState.results:
        return _buildResultsState();
      case _UiState.noResults:
        return _buildNoResultsState();
    }
  }

  // ── STATE 1: Empty ────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final cats = <String>{...NotesProvider.categories};
    for (final n in provider.allActiveNotes) { cats.add(n.category); }

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── RECENT SEARCHES ─────────────────────────────────────────────
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECENT SEARCHES',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: _kSectionLabel, letterSpacing: 0.8)),
              GestureDetector(
                onTap: _clearAllSearches,
                child: Text('Clear all',
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: _kAmber)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._recentSearches.map((term) => _RecentSearchRow(
            term: term,
            onTap: () => _tapRecentSearch(term),
            onDelete: () => _removeSearch(term),
          )),
          const SizedBox(height: 24),
        ],

        // ── BROWSE BY CATEGORY ───────────────────────────────────────────
        Text('BROWSE BY CATEGORY',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: _kSectionLabel, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cats.map((c) => _CategoryChip(
            category: c,
            dotColor: _categoryDotColor(c),
            onTap: () => _tapCategoryChip(c),
          )).toList(),
        ),
      ],
    );
  }

  // ── STATE 2: Typing ───────────────────────────────────────────────────────

  Widget _buildTypingState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        if (_isLoading) ...[
          Center(
            child: Column(children: [
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(_kAmber),
                ),
              ),
              const SizedBox(height: 12),
              Text('Searching…',
                style: GoogleFonts.inter(fontSize: 14, color: _kPlaceholder)),
            ]),
          ),
        ],
        ..._buildShimmerRows(),
      ],
    );
  }

  List<Widget> _buildShimmerRows() {
    return List.generate(5, (i) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _ShimmerRow(index: i),
    ));
  }

  // ── STATE 3: Results ──────────────────────────────────────────────────────

  Widget _buildResultsState() {
    final List<Widget> items = [];
    int idx = 0;
    final gen = _resultGeneration;

    void addSection(String label, int count, List<Widget> rows) {
      items.add(AnimatedListEntrance(
        key: ValueKey('header_${label}_$gen'),
        index: idx++,
        child: _SectionHeader(label: label, count: count),
      ));
      items.addAll(rows);
    }

    if (_noteResults.isNotEmpty) {
      addSection('NOTES', _noteResults.length,
        _noteResults.map((n) => AnimatedListEntrance(
          key: ValueKey('note_${n.id}_$gen'),
          index: idx++,
          child: _NoteResultRow(
            note: n, query: _query,
            onTap: () => _openNote(n),
          ),
        )).toList(),
      );
    }

    if (_taskResults.isNotEmpty) {
      addSection('TASKS', _taskResults.length,
        _taskResults.map((t) => AnimatedListEntrance(
          key: ValueKey('task_${t.id}_$gen'),
          index: idx++,
          child: _TaskResultRow(
            task: t, query: _query,
            onTap: () => _openTask(t),
          ),
        )).toList(),
      );
    }

    if (_folderResults.isNotEmpty) {
      final provider = Provider.of<NotesProvider>(context, listen: false);
      addSection('FOLDERS', _folderResults.length,
        _folderResults.map((f) {
          final noteCount = provider.allActiveNotes
              .where((n) => n.folderId == f.id).length;
          return AnimatedListEntrance(
            key: ValueKey('folder_${f.id}_$gen'),
            index: idx++,
            child: _FolderResultRow(
              folder: f, noteCount: noteCount, query: _query,
              onTap: () => _openFolder(f),
            ),
          );
        }).toList(),
      );
    }

    if (_categoryResults.isNotEmpty) {
      final provider = Provider.of<NotesProvider>(context, listen: false);
      addSection('CATEGORIES', _categoryResults.length,
        _categoryResults.map((c) {
          final noteCount = provider.allActiveNotes
              .where((n) => n.category == c).length;
          return AnimatedListEntrance(
            key: ValueKey('cat_${c}_$gen'),
            index: idx++,
            child: _CategoryResultRow(
              category: c, noteCount: noteCount, query: _query,
              dotColor: _categoryDotColor(c),
              onTap: () => _openCategory(c),
            ),
          );
        }).toList(),
      );
    }

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: items,
    );
  }

  // ── STATE 4: No Results ───────────────────────────────────────────────────

  Widget _buildNoResultsState() {
    return FadeTransition(
      opacity: _entryFade..addListener(() => setState(() {})),
      child: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
        children: [
          // Empty state illustration
          Center(
            child: Column(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: const BoxDecoration(
                    color: _kChipInactive,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.search_rounded, size: 40, color: _kSectionLabel),
                      Positioned(
                        right: 14, bottom: 14,
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(
                            color: _kBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: _kSectionLabel),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No results for "$_query"',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w700, color: _kInk),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try different keywords or remove filters',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14, color: _kPlaceholder),
                ),
                const SizedBox(height: 24),
                // Ghost action chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GhostChip(
                      label: 'Clear filters',
                      onTap: _clearFilters,
                    ),
                    const SizedBox(width: 12),
                    _GhostChip(
                      label: 'Search in all folders',
                      onTap: _searchAllFolders,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
          const Divider(color: _kDivider),
          const SizedBox(height: 16),

          // CREATE NEW section
          Text('CREATE NEW',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: _kSectionLabel, letterSpacing: 0.8)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _createNoteWithTitle(_query.trim()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDD8),
                borderRadius: BorderRadius.circular(_kBorderRadius),
                border: Border.all(color: _kDivider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _kAmber.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_rounded, color: _kAmber, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(text: TextSpan(children: [
                          TextSpan(
                            text: '"',
                            style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w500,
                              color: _kInk),
                          ),
                          TextSpan(
                            text: _query.trim(),
                            style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: _kAmber),
                          ),
                          TextSpan(
                            text: '"',
                            style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w500,
                              color: _kInk),
                          ),
                        ])),
                        const SizedBox(height: 2),
                        Text('Start a new note with this title',
                          style: GoogleFonts.inter(
                            fontSize: 12, color: _kPlaceholder)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _kPlaceholder),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers: highlight matched text with amber spans
// ─────────────────────────────────────────────────────────────────────────────

List<TextSpan> _buildHighlightSpans(String text, String query,
    {required TextStyle base, required TextStyle highlight}) {
  if (query.isEmpty) return [TextSpan(text: text, style: base)];

  final spans = <TextSpan>[];
  final lower = text.toLowerCase();
  final lowerQ = query.toLowerCase();
  int start = 0;

  while (true) {
    final idx = lower.indexOf(lowerQ, start);
    if (idx == -1) {
      spans.add(TextSpan(text: text.substring(start), style: base));
      break;
    }
    if (idx > start) {
      spans.add(TextSpan(text: text.substring(start, idx), style: base));
    }
    spans.add(TextSpan(
        text: text.substring(idx, idx + query.length), style: highlight));
    start = idx + query.length;
  }
  return spans;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 28, color: _kInk),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(
        children: [
          Text(label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: _kSectionLabel, letterSpacing: 0.8)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _kChipInactive,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: _kChipInactiveTxt)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RecentSearchRow extends StatelessWidget {
  final String term;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _RecentSearchRow({
    required this.term,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, size: 18, color: _kSectionLabel),
            const SizedBox(width: 12),
            Expanded(
              child: Text(term,
                style: GoogleFonts.inter(
                  fontSize: 15, color: _kInk, fontWeight: FontWeight.w400)),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close_rounded, size: 16, color: _kPlaceholder),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String category;
  final Color dotColor;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.category,
    required this.dotColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EDD8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kDivider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(category,
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500, color: _kInk)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FilterDropdownButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _FilterDropdownButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kDurationFast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _kAmber.withValues(alpha:0.15) : const Color(0xFFE9E1D9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? _kAmber : const Color(0xFFCCC5B8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? _kAmber : _kChipInactiveTxt)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isActive ? _kAmber : _kChipInactiveTxt),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result row: Note
// ─────────────────────────────────────────────────────────────────────────────

class _NoteResultRow extends StatelessWidget {
  final Note note;
  final String query;
  final VoidCallback onTap;
  const _NoteResultRow({required this.note, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cardColor = _noteCardColor(note.colorValue);
    final dateStr = DateFormat('MMM d').format(note.updatedAt);
    final baseTitle = GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600, color: _kInk);
    final hlTitle  = baseTitle.copyWith(color: _kAmber, fontWeight: FontWeight.w700);
    final baseBody = GoogleFonts.inter(fontSize: 13, color: const Color(0xFF524534));
    final hlBody   = baseBody.copyWith(color: _kAmber, fontWeight: FontWeight.w600);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          border: Border.all(color: _kCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(children:
                _buildHighlightSpans(
                  note.title.isEmpty ? 'Untitled' : note.title,
                  query, base: baseTitle, highlight: hlTitle)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (note.previewText.isNotEmpty) ...[
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(children:
                  _buildHighlightSpans(note.previewText, query,
                      base: baseBody, highlight: hlBody)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha:0.07),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(note.category,
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: const Color(0xFF524534))),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: _categoryDotColor(note.category),
                    shape: BoxShape.circle,
                  ),
                ),
                const Spacer(),
                Text(dateStr,
                  style: GoogleFonts.inter(
                    fontSize: 11, color: _kPlaceholder)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result row: Task
// ─────────────────────────────────────────────────────────────────────────────

class _TaskResultRow extends StatelessWidget {
  final TaskItem task;
  final String query;
  final VoidCallback onTap;
  const _TaskResultRow({required this.task, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = task.reminderTime != null
        ? 'Due ${DateFormat('MMM d').format(task.reminderTime!.toLocal())}'
        : DateFormat('MMM d').format(task.dueDate.toLocal());
    final baseTitle = GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w500, color: _kInk);
    final hlTitle  = baseTitle.copyWith(color: _kAmber, fontWeight: FontWeight.w700);

    final categoryLabel = task.categoryId ?? (task.priority != 'None' ? task.priority : 'Task');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF7),
          borderRadius: BorderRadius.circular(_kBorderRadius),
          border: Border.all(color: _kDivider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                task.completed ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: _kAmber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(children:
                      _buildHighlightSpans(
                        task.title.isEmpty ? 'Untitled task' : task.title,
                        query, base: baseTitle, highlight: hlTitle)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(dateStr,
                        style: GoogleFonts.inter(
                          fontSize: 12, color: _kPlaceholder)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kAmber.withValues(alpha:0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(categoryLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: _kAmber)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result row: Folder
// ─────────────────────────────────────────────────────────────────────────────

class _FolderResultRow extends StatelessWidget {
  final Folder folder;
  final int noteCount;
  final String query;
  final VoidCallback onTap;
  const _FolderResultRow({
    required this.folder,
    required this.noteCount,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w500, color: _kInk);
    final hl   = base.copyWith(color: _kAmber, fontWeight: FontWeight.w700);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF7),
          borderRadius: BorderRadius.circular(_kBorderRadius),
          border: Border.all(color: _kDivider),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kAmber.withValues(alpha:0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.folder_rounded, color: _kAmber, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(children:
                  _buildHighlightSpans(folder.name, query, base: base, highlight: hl)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kChipInactive,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$noteCount notes',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _kChipInactiveTxt)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result row: Category
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryResultRow extends StatelessWidget {
  final String category;
  final int noteCount;
  final String query;
  final Color dotColor;
  final VoidCallback onTap;
  const _CategoryResultRow({
    required this.category,
    required this.noteCount,
    required this.query,
    required this.dotColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w500, color: _kInk);
    final hl   = base.copyWith(color: _kAmber, fontWeight: FontWeight.w700);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF7),
          borderRadius: BorderRadius.circular(_kBorderRadius),
          border: Border.all(color: _kDivider),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha:0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                      color: dotColor, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(children:
                  _buildHighlightSpans(category, query, base: base, highlight: hl)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('$noteCount notes',
              style: GoogleFonts.inter(
                fontSize: 12, color: _kPlaceholder)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ghost chip
// ─────────────────────────────────────────────────────────────────────────────

class _GhostChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBFB8AA)),
        ),
        child: Text(label,
          style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: _kChipInactiveTxt)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer placeholder row (typing state)
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerRow extends StatefulWidget {
  final int index;
  const _ShimmerRow({required this.index});

  @override
  State<_ShimmerRow> createState() => _ShimmerRowState();
}

class _ShimmerRowState extends State<_ShimmerRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.3 + _anim.value * 0.35;
        return Opacity(
          opacity: opacity,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: _kChipInactive,
              borderRadius: BorderRadius.circular(_kBorderRadius),
            ),
          ),
        );
      },
    );
  }
}
