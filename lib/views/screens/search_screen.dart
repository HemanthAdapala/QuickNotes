// ──────────────────────────────────────────────────────────────────────────────
// search_screen.dart — Quick Notes Global Search Screen
//
// DESIGN & LAYOUT SPECIFICATION (Figma "Global Search Screen Basic"):
//   1. Header Bar: Liquid glass surface (44px left angle_left pill, 44px expanded
//      glass TextField input pill, 44px right close button pill).
//   2. Scope Selector Bar: Horizontal scrollable pills on grouped grey background
//      (Color(0xFFF2F2F7)) with active Yellow Accent pill (Color(0xFFFFCC00)) and
//      inactive grey pills (Color(0x28787880)).
//   3. Body Sheet Card: Top-rounded (20px) white sheet filling remaining height with
//      subtle top shadow, containing "Recent Searches" / "Clear all" header and
//      dynamic states (empty, typing, results, noResults).
//
// RESPONSIVENESS: Flex layouts (SafeArea, Column, Row, Expanded, SingleChildScrollView)
//   adapt dynamically to all device screen sizes.
// ──────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/tactile_button.dart';
import '../widgets/living_writing_experience.dart';
import '../widgets/search_note_card.dart';
import '../widgets/search_task_card.dart';
import '../widgets/folder_card.dart';
import 'note_editor_screen.dart';
import 'create_task_screen.dart';
import 'folder_notes_screen.dart';
import 'category_details_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums & Constants
// ─────────────────────────────────────────────────────────────────────────────

enum _Scope { all, notes, tasks, folders, categories }
enum _DateFilter { allTime, today, thisWeek, thisMonth }
enum _UiState { empty, typing, results, noResults }

const Color _kGroupedBg     = Color(0xFFF2F2F7);
const Color _kSheetBg       = Color(0xFFFFFFFF);
const Color _kInk           = Color(0xFF1C1C1E);
const Color _kAmberYellow   = Color(0xFFFFCC00);
const Color _kPillInactive  = Color(0x28787880);
const Color _kLabelSecondary= Color(0x993C3C43);
const Color _kPlaceholder   = Color(0xFF8C8987);
const Color _kDivider       = Color(0xFFE5E5EA);

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

// ─────────────────────────────────────────────────────────────────────────────
// SearchScreen
// ─────────────────────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  final String initialScope;
  final String? presetFolder;
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

  // Controllers
  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  Timer? _debounce;

  // State
  _Scope            _scope       = _Scope.all;
  final _DateFilter _dateFilter  = _DateFilter.allTime;
  _UiState          _uiState     = _UiState.empty;
  bool         _isLoading   = false;

  String? _filterFolderId;
  String? _filterCategory;
  String  _query = '';

  // Results
  List<Note>     _allNoteResults      = [];
  List<TaskItem> _allTaskResults      = [];
  List<Folder>   _allFolderResults    = [];
  List<String>   _allCategoryResults  = [];

  List<Note>     _noteResults     = [];
  List<TaskItem> _taskResults     = [];
  List<Folder>   _folderResults   = [];
  List<String>   _categoryResults = [];

  List<String> _recentSearches = [];
  int _resultGeneration = 0;

  late AnimationController _entryCtrl;
  late Animation<double>    _entryFade;

  @override
  void initState() {
    super.initState();

    _scope = _scopeFromString(widget.initialScope);
    _filterFolderId = widget.presetFolder;
    _filterCategory = widget.presetCategory;

    _entryCtrl = AnimationController(vsync: this, duration: kDurationNormal);
    _entryFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: kCurveEnter));
    _entryCtrl.forward();

    _loadRecentSearches();

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

  // ── Recent Searches Persistence ──────────────────────────────────────────

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

  // ── Query & Search Logic ──────────────────────────────────────────────────

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

    // Active Notes
    final notes = notesProvider.allActiveNotes.where((n) =>
      n.title.toLowerCase().contains(q) ||
      n.previewText.toLowerCase().contains(q)
    ).toList();

    // Standalone Tasks
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

      if (_uiState == _UiState.results) _saveSearch(query.trim());
    });
  }

  void _applyFilters() {
    var notes   = List<Note>.from(_allNoteResults);
    var tasks   = List<TaskItem>.from(_allTaskResults);
    var folders = List<Folder>.from(_allFolderResults);
    var cats    = List<String>.from(_allCategoryResults);

    if (_filterFolderId != null) {
      notes = notes.where((n) => n.folderId == _filterFolderId).toList();
      tasks = tasks.where((t) => t.folderId == _filterFolderId).toList();
    }

    if (_filterCategory != null) {
      notes = notes.where((n) => n.category == _filterCategory).toList();
      tasks = tasks.where((t) => (t.categoryId == _filterCategory || t.priority == _filterCategory)).toList();
    }

    final now = DateTime.now();
    notes = _applyDateFilter(notes, now);
    tasks = _applyTaskDateFilter(tasks, now);

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

  void _closeOrClearSearch() {
    HapticFeedback.lightImpact();
    if (_query.isNotEmpty) {
      _queryCtrl.clear();
      _focusNode.requestFocus();
    } else {
      _debounce?.cancel();
      Navigator.of(context).pop();
    }
  }

  void _popSearch() {
    HapticFeedback.lightImpact();
    _debounce?.cancel();
    Navigator.of(context).pop();
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
  }

  void _tapCategoryChip(String category) {
    _queryCtrl.text = category;
    _queryCtrl.selection = TextSelection.collapsed(offset: category.length);
    _scope = _Scope.categories;
  }

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
    return Scaffold(
      backgroundColor: _kGroupedBg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildHeaderBar(),
            const SizedBox(height: 12),
            _buildScopePillBar(),
            const SizedBox(height: 12),
            Expanded(child: _buildBodySheetCard()),
          ],
        ),
      ),
    );
  }

  // ── 1. AppHeader Bar (Liquid Glass) ──────────────────────────────────────

  Widget _buildHeaderBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        height: 44.0,
        child: Row(
          children: [
            // Left glass pill button (angle_left)
            BottomBarGlassSurface(
              width: 44.0,
              height: 44.0,
              borderRadius: BorderRadius.circular(22.0),
              useFrost: true,
              child: TactileButton(
                useAppleSpring: true,
                compressionScale: 0.7,
                settleDuration: const Duration(milliseconds: 1000),
                onTap: _popSearch,
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/angle_left.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(_kInk, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Center expanded glass search field
            Expanded(
              child: BottomBarGlassSurface(
                width: double.infinity,
                height: 44.0,
                borderRadius: BorderRadius.circular(22.0),
                useFrost: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
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
                        hintText: 'Search notes, tasks, folders...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 15,
                          color: _kPlaceholder,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Right glass pill close button
            BottomBarGlassSurface(
              width: 44.0,
              height: 44.0,
              borderRadius: BorderRadius.circular(22.0),
              useFrost: true,
              child: TactileButton(
                useAppleSpring: true,
                compressionScale: 0.7,
                settleDuration: const Duration(milliseconds: 1000),
                onTap: _closeOrClearSearch,
                child: const Center(
                  child: Icon(
                    Icons.close_rounded,
                    color: _kInk,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Scope Pill Bar ────────────────────────────────────────────────────

  Widget _buildScopePillBar() {
    const scopes = _Scope.values;
    return SizedBox(
      height: 40.0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: scopes.map((s) {
            final isActive = _scope == s;
            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: GestureDetector(
                onTap: () => _onScopeChanged(s),
                child: AnimatedContainer(
                  duration: kDurationFast,
                  curve: kCurveDefault,
                  height: 40.0,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  decoration: BoxDecoration(
                    color: isActive ? _kAmberYellow : _kPillInactive,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _scopeLabel(s),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                      color: isActive ? Colors.white : _kLabelSecondary,
                      letterSpacing: -0.43,
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

  // ── 3. Main White Body Card Sheet ────────────────────────────────────────

  Widget _buildBodySheetCard() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _kSheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            offset: Offset(0, -4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
        child: Column(
          children: [
            // Recent Searches Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Searches',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: _kLabelSecondary,
                      letterSpacing: -0.43,
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearAllSearches,
                    child: Text(
                      'Clear all',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: _kLabelSecondary,
                        letterSpacing: -0.43,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: _kDivider, height: 1),

            // Dynamic Body State Content
            Expanded(child: _buildBodyStateContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyStateContent() {
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

  // ── State 1: Empty (Recent Searches & Browse Categories) ───────────────

  Widget _buildEmptyState() {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final cats = <String>{...NotesProvider.categories};
    for (final n in provider.allActiveNotes) { cats.add(n.category); }

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          ..._recentSearches.map((term) => _RecentSearchRow(
            term: term,
            onTap: () => _tapRecentSearch(term),
            onDelete: () => _removeSearch(term),
          )),
          const SizedBox(height: 24),
        ],

        Text(
          'BROWSE BY CATEGORY',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _kLabelSecondary,
            letterSpacing: 0.8,
          ),
        ),
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

  // ── State 2: Typing (Shimmer Skeleton) ────────────────────────────────────

  Widget _buildTypingState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        if (_isLoading) ...[
          Center(
            child: Column(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(_kAmberYellow),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Searching...',
                  style: GoogleFonts.inter(fontSize: 14, color: _kPlaceholder),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        ...List.generate(5, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ShimmerRow(index: i),
        )),
      ],
    );
  }

  // ── State 3: Results ──────────────────────────────────────────────────────

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
          child: SearchNoteCard(
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
          child: SearchTaskCard(
            task: t, query: _query,
            onTap: () => _openTask(t),
          ),
        )).toList(),
      );
    }

    if (_folderResults.isNotEmpty) {
      final provider = Provider.of<NotesProvider>(context, listen: false);
      items.add(AnimatedListEntrance(
        key: ValueKey('header_FOLDERS_$gen'),
        index: idx++,
        child: _SectionHeader(label: 'FOLDERS', count: _folderResults.length),
      ));
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 150.0 / 192.0,
            ),
            itemCount: _folderResults.length,
            itemBuilder: (context, folderIndex) {
              final f = _folderResults[folderIndex];
              final noteCount = provider.allActiveNotes
                  .where((n) => n.folderId == f.id).length;
              return AnimatedListEntrance(
                key: ValueKey('folder_${f.id}_$gen'),
                index: idx++,
                child: FolderGridCard(
                  folder: f,
                  index: folderIndex,
                  noteCount: noteCount,
                  query: _query,
                  onTap: () => _openFolder(f),
                ),
              );
            },
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: items,
    );
  }

  // ── State 4: No Results ───────────────────────────────────────────────────

  Widget _buildNoResultsState() {
    return FadeTransition(
      opacity: _entryFade,
      child: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: _kGroupedBg,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.search_rounded, size: 36, color: _kLabelSecondary),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 13, color: _kLabelSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No results for "$_query"',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700, color: _kInk),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try searching across all scopes or categories',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14, color: _kPlaceholder),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Divider(color: _kDivider),
          const SizedBox(height: 16),

          Text(
            'CREATE NEW',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kLabelSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _createNoteWithTitle(_query.trim()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDD8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kDivider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _kAmberYellow.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_rounded, color: Color(0xFFD49200), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '"',
                                style: GoogleFonts.inter(
                                  fontSize: 15, fontWeight: FontWeight.w500, color: _kInk),
                              ),
                              TextSpan(
                                text: _query.trim(),
                                style: GoogleFonts.inter(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFFD49200)),
                              ),
                              TextSpan(
                                text: '"',
                                style: GoogleFonts.inter(
                                  fontSize: 15, fontWeight: FontWeight.w500, color: _kInk),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Start a new note with this title',
                          style: GoogleFonts.inter(fontSize: 12, color: _kPlaceholder),
                        ),
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
// Highlight Helper
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
// Sub-Widgets
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
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kLabelSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _kPillInactive,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kLabelSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
            const Icon(Icons.history_rounded, size: 18, color: _kLabelSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                term,
                style: GoogleFonts.inter(
                  fontSize: 15, color: _kInk, fontWeight: FontWeight.w400),
              ),
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
            Text(
              category,
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500, color: _kInk),
            ),
          ],
        ),
      ),
    );
  }
}



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
    final hl   = base.copyWith(color: const Color(0xFFD49200), fontWeight: FontWeight.w700);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kDivider),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
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
            Text(
              '$noteCount notes',
              style: GoogleFonts.inter(fontSize: 12, color: _kPlaceholder),
            ),
          ],
        ),
      ),
    );
  }
}

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
              color: _kPillInactive,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}
