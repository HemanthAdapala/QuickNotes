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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/motion/motion_constants.dart';
import '../../core/motion/quick_notes_haptics.dart';
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

const Color _kGroupedBg = Color(0xFFF2F2F7);
const Color _kSheetBg = Color(0xFFFFFFFF);
const Color _kInk = Color(0xFF1C1C1E);
const Color _kAmberYellow = Color(0xFFFFCC00);
const Color _kPillInactive = Color(0x28787880);
const Color _kLabelSecondary = Color(0x993C3C43);
const Color _kPlaceholder = Color(0xFF8C8987);
const Color _kDivider = Color(0xFFE5E5EA);

const Map<String, Color> _kCategoryDotColors = {
  'Personal': Color(0xFF4A90D9),
  'Work': Color(0xFF4CAF50),
  'Ideas': Color(0xFFFFB800),
  'Study': Color(0xFFE91E63),
  'Hobbies': Color(0xFF9C27B0),
  'Recipes': Color(0xFF64B5F6),
  'Uncategorized': Color(0xFF9E9E9E),
};

Color _categoryDotColor(String category) {
  if (_kCategoryDotColors.containsKey(category)) {
    return _kCategoryDotColors[category]!;
  }
  final hue = (category.hashCode.abs() % 360).toDouble();
  return HSLColor.fromAHSL(1.0, hue, 0.55, 0.50).toColor();
}

String _scopeLabel(_Scope s) {
  switch (s) {
    case _Scope.all:
      return 'All';
    case _Scope.notes:
      return 'Notes';
    case _Scope.tasks:
      return 'Tasks';
    case _Scope.folders:
      return 'Folders';
    case _Scope.categories:
      return 'Categories';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Screen State Model
// ─────────────────────────────────────────────────────────────────────────────

class _SearchState {
  final String query;
  final _UiState uiState;
  final bool isLoading;
  final int resultGeneration;
  final List<Note> noteResults;
  final List<TaskItem> taskResults;
  final List<Folder> folderResults;
  final List<String> categoryResults;
  final Map<String, int> folderNoteCounts;
  final Map<String, int> categoryNoteCounts;
  final List<String> recentSearches;

  const _SearchState({
    required this.query,
    required this.uiState,
    required this.isLoading,
    required this.resultGeneration,
    required this.noteResults,
    required this.taskResults,
    required this.folderResults,
    required this.categoryResults,
    required this.folderNoteCounts,
    required this.categoryNoteCounts,
    required this.recentSearches,
  });

  factory _SearchState.initial({List<String> recentSearches = const []}) {
    return _SearchState(
      query: '',
      uiState: _UiState.empty,
      isLoading: false,
      resultGeneration: 0,
      noteResults: const [],
      taskResults: const [],
      folderResults: const [],
      categoryResults: const [],
      folderNoteCounts: const {},
      categoryNoteCounts: const {},
      recentSearches: recentSearches,
    );
  }

  _SearchState copyWith({
    String? query,
    _UiState? uiState,
    bool? isLoading,
    int? resultGeneration,
    List<Note>? noteResults,
    List<TaskItem>? taskResults,
    List<Folder>? folderResults,
    List<String>? categoryResults,
    Map<String, int>? folderNoteCounts,
    Map<String, int>? categoryNoteCounts,
    List<String>? recentSearches,
  }) {
    return _SearchState(
      query: query ?? this.query,
      uiState: uiState ?? this.uiState,
      isLoading: isLoading ?? this.isLoading,
      resultGeneration: resultGeneration ?? this.resultGeneration,
      noteResults: noteResults ?? this.noteResults,
      taskResults: taskResults ?? this.taskResults,
      folderResults: folderResults ?? this.folderResults,
      categoryResults: categoryResults ?? this.categoryResults,
      folderNoteCounts: folderNoteCounts ?? this.folderNoteCounts,
      categoryNoteCounts: categoryNoteCounts ?? this.categoryNoteCounts,
      recentSearches: recentSearches ?? this.recentSearches,
    );
  }
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

  // State Notifiers (G-04 Rebuild Isolation)
  late final ValueNotifier<_Scope> _scopeNotifier;
  late final ValueNotifier<_SearchState> _searchNotifier;

  final _DateFilter _dateFilter = _DateFilter.allTime;
  String? _filterFolderId;
  String? _filterCategory;

  // Unfiltered Result Snapshot (for client-side scope filtering)
  List<Note> _allNoteResults = [];
  List<TaskItem> _allTaskResults = [];
  List<Folder> _allFolderResults = [];
  List<String> _allCategoryResults = [];
  Map<String, int> _allFolderNoteCounts = {};
  Map<String, int> _allCategoryNoteCounts = {};
  int _resultGeneration = 0;

  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  bool _entryInitialized = false;

  late final Widget _headerBar;

  @override
  void initState() {
    super.initState();

    final initialScope = _scopeFromString(widget.initialScope);
    _scopeNotifier = ValueNotifier<_Scope>(initialScope);
    _searchNotifier = ValueNotifier<_SearchState>(_SearchState.initial());

    _filterFolderId = widget.presetFolder;
    _filterCategory = widget.presetCategory;

    _entryCtrl = AnimationController(
      vsync: this,
      duration: QuickNotesMotion.kMotionPage,
    );
    _entryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: QuickNotesMotion.kMotionAppleEase,
      ),
    );

    _headerBar = _SearchHeaderBar(
      controller: _queryCtrl,
      focusNode: _focusNode,
      onBack: _popSearch,
      onCloseOrClear: _closeOrClearSearch,
      onSubmitted: _onSubmitted,
    );

    _loadRecentSearches();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    _queryCtrl.addListener(_onQueryChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_entryInitialized) {
      _entryInitialized = true;
      final disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (disableAnimations) {
        _entryCtrl.value = 1.0;
      } else {
        _entryCtrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.removeListener(_onQueryChanged);
    _queryCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    _entryCtrl.dispose();
    _scopeNotifier.dispose();
    _searchNotifier.dispose();
    super.dispose();
  }

  // ── Recent Searches Persistence ──────────────────────────────────────────

  Future<void> _loadRecentSearches() async {
    final searches = await RecentSearchesService.instance.load();
    if (mounted) {
      _searchNotifier.value = _searchNotifier.value.copyWith(
        recentSearches: searches,
      );
    }
  }

  Future<void> _saveSearch(String term) async {
    final updated = await RecentSearchesService.instance.addSearch(term);
    if (mounted) {
      _searchNotifier.value = _searchNotifier.value.copyWith(
        recentSearches: updated,
      );
    }
  }

  Future<void> _removeSearch(String term) async {
    QuickNotesHaptics.selection();
    final updated = await RecentSearchesService.instance.removeSearch(term);
    if (mounted) {
      _searchNotifier.value = _searchNotifier.value.copyWith(
        recentSearches: updated,
      );
    }
  }

  Future<void> _clearAllSearches() async {
    if (_searchNotifier.value.recentSearches.isEmpty) return;
    await RecentSearchesService.instance.clearAll();
    if (mounted) {
      _searchNotifier.value = _searchNotifier.value.copyWith(
        recentSearches: [],
      );
      QuickNotesHaptics.destructiveAction();
    }
  }

  Future<void> _commitQueryIfEligible() async {
    final trimmed = _queryCtrl.text.trim();
    if (trimmed.length >= 2) {
      await _saveSearch(trimmed);
    }
  }

  // ── Query & Search Logic ──────────────────────────────────────────────────

  void _onQueryChanged() {
    final rawText = _queryCtrl.text;
    final trimmed = rawText.trim();

    _debounce?.cancel();

    // G-09: Fewer than 2 characters immediately leaves result state
    if (trimmed.length < 2) {
      _clearResults();
      _searchNotifier.value = _searchNotifier.value.copyWith(
        query: rawText,
        uiState: _UiState.empty,
        isLoading: false,
        noteResults: const [],
        taskResults: const [],
        folderResults: const [],
        categoryResults: const [],
        folderNoteCounts: const {},
        categoryNoteCounts: const {},
      );
      return;
    }

    // G-04 & G-09: Transition to typing state
    _searchNotifier.value = _searchNotifier.value.copyWith(
      query: rawText,
      uiState: _UiState.typing,
      isLoading: true,
    );

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(trimmed);
    });
  }

  void _clearResults() {
    _allNoteResults = [];
    _allTaskResults = [];
    _allFolderResults = [];
    _allCategoryResults = [];
    _allFolderNoteCounts = {};
    _allCategoryNoteCounts = {};
  }

  // G-06: Capture active notes snapshot once and calculate counts O(N)
  // G-10: Normalized query handling
  void _runSearch(String query) {
    if (!mounted) return;
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);

    final q = query.trim().toLowerCase();
    if (q.length < 2) {
      _clearResults();
      _searchNotifier.value = _searchNotifier.value.copyWith(
        query: _queryCtrl.text,
        uiState: _UiState.empty,
        isLoading: false,
        noteResults: const [],
        taskResults: const [],
        folderResults: const [],
        categoryResults: const [],
        folderNoteCounts: const {},
        categoryNoteCounts: const {},
      );
      return;
    }

    // Single active notes snapshot
    final allNotes = notesProvider.allActiveNotes;

    // Filter active notes
    final notes = allNotes
        .where((n) =>
            n.title.toLowerCase().contains(q) ||
            n.previewText.toLowerCase().contains(q))
        .toList();

    // Standalone Tasks
    final tasks = tasksProvider.tasks
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q))
        .toList();

    // Folders
    final folders = notesProvider.folders
        .where((f) => f.name.toLowerCase().contains(q))
        .toList();

    // Precalculate folder and category counts in a single O(N) pass
    final folderNoteCounts = <String, int>{};
    final categoryNoteCounts = <String, int>{};
    final allCats = <String>{...NotesProvider.categories};

    for (final n in allNotes) {
      if (n.folderId != null && n.folderId!.isNotEmpty) {
        folderNoteCounts[n.folderId!] =
            (folderNoteCounts[n.folderId!] ?? 0) + 1;
      }
      categoryNoteCounts[n.category] =
          (categoryNoteCounts[n.category] ?? 0) + 1;
      allCats.add(n.category);
    }

    final categories =
        allCats.where((c) => c.toLowerCase().contains(q)).toList();

    if (!mounted) return;

    _allNoteResults = notes;
    _allTaskResults = tasks;
    _allFolderResults = folders;
    _allCategoryResults = categories;
    _allFolderNoteCounts = folderNoteCounts;
    _allCategoryNoteCounts = categoryNoteCounts;
    _resultGeneration++;

    _publishFilteredResults();
    // G-08: Debounce DOES NOT persist searches
  }

  void _publishFilteredResults() {
    var notes = List<Note>.from(_allNoteResults);
    var tasks = List<TaskItem>.from(_allTaskResults);
    var folders = List<Folder>.from(_allFolderResults);
    var cats = List<String>.from(_allCategoryResults);

    if (_filterFolderId != null) {
      notes = notes.where((n) => n.folderId == _filterFolderId).toList();
      tasks = tasks.where((t) => t.folderId == _filterFolderId).toList();
    }

    if (_filterCategory != null) {
      notes = notes.where((n) => n.category == _filterCategory).toList();
      tasks = tasks
          .where((t) => (t.categoryId == _filterCategory ||
              t.priority == _filterCategory))
          .toList();
    }

    final now = DateTime.now();
    notes = _applyDateFilter(notes, now);
    tasks = _applyTaskDateFilter(tasks, now);

    final currentScope = _scopeNotifier.value;
    switch (currentScope) {
      case _Scope.all:
        break;
      case _Scope.notes:
        tasks = [];
        folders = [];
        cats = [];
        break;
      case _Scope.tasks:
        notes = [];
        folders = [];
        cats = [];
        break;
      case _Scope.folders:
        notes = [];
        tasks = [];
        cats = [];
        break;
      case _Scope.categories:
        notes = [];
        tasks = [];
        folders = [];
        break;
    }

    final hasResults = notes.isNotEmpty ||
        tasks.isNotEmpty ||
        folders.isNotEmpty ||
        cats.isNotEmpty;

    _searchNotifier.value = _searchNotifier.value.copyWith(
      query: _queryCtrl.text,
      uiState: hasResults ? _UiState.results : _UiState.noResults,
      isLoading: false,
      resultGeneration: _resultGeneration,
      noteResults: notes,
      taskResults: tasks,
      folderResults: folders,
      categoryResults: cats,
      folderNoteCounts: _allFolderNoteCounts,
      categoryNoteCounts: _allCategoryNoteCounts,
    );
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
        return list
            .where((n) =>
                n.updatedAt.year == now.year && n.updatedAt.month == now.month)
            .toList();
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
    QuickNotesHaptics.selection();
    _scopeNotifier.value = scope;
    final currentState = _searchNotifier.value.uiState;
    if (currentState == _UiState.results || currentState == _UiState.noResults) {
      _publishFilteredResults();
    }
  }

  void _closeOrClearSearch() {
    if (_queryCtrl.text.isNotEmpty) {
      _queryCtrl.clear();
      _focusNode.requestFocus();
    } else {
      _debounce?.cancel();
      Navigator.of(context).pop();
    }
  }

  void _popSearch() {
    _debounce?.cancel();
    Navigator.of(context).pop();
  }

  // G-08: IME Search explicitly submitted
  void _onSubmitted(String v) {
    final trimmed = v.trim();
    if (trimmed.length >= 2) {
      _saveSearch(trimmed);
      _focusNode.unfocus();
      _debounce?.cancel();
      _runSearch(trimmed);
    }
  }

  // ── Navigation (G-05 Async Route Awaiting & Refresh) ──────────────────────

  Future<void> _openNote(Note note) async {
    await _commitQueryIfEligible();
    if (!mounted) return;
    await Navigator.push(
      context,
      buildPageRoute(
        NoteEditorScreen(note: note),
      ),
    );
    if (mounted && _queryCtrl.text.trim().isNotEmpty) {
      _runSearch(_queryCtrl.text);
    }
  }

  Future<void> _openTask(TaskItem task) async {
    await _commitQueryIfEligible();
    if (!mounted) return;
    await Navigator.push(
      context,
      buildPageRoute(
        TaskEditorScreen(
          initialDate: task.dueDate.toLocal(),
          taskToEdit: task,
        ),
      ),
    );
    if (mounted && _queryCtrl.text.trim().isNotEmpty) {
      _runSearch(_queryCtrl.text);
    }
  }

  Future<void> _openFolder(Folder folder) async {
    await _commitQueryIfEligible();
    if (!mounted) return;
    await Navigator.push(
      context,
      buildPageRoute(
        FolderNotesScreen(folder: folder),
      ),
    );
    if (mounted && _queryCtrl.text.trim().isNotEmpty) {
      _runSearch(_queryCtrl.text);
    }
  }

  Future<void> _openCategory(String category) async {
    await _commitQueryIfEligible();
    QuickNotesHaptics.navigationSelection();
    if (!mounted) return;
    await Navigator.push(
      context,
      buildPageRoute(
        CategoryDetailsScreen(category: category),
      ),
    );
    if (mounted && _queryCtrl.text.trim().isNotEmpty) {
      _runSearch(_queryCtrl.text);
    }
  }

  // G-02: Title propagation to NoteEditorScreen
  // G-08: Save search before navigation
  Future<void> _createNoteWithTitle(String title) async {
    final trimmed = title.trim();
    if (trimmed.length >= 2) {
      await _saveSearch(trimmed);
    }
    QuickNotesHaptics.navigationSelection();
    if (!mounted) return;
    await Navigator.push(
      context,
      buildPageRoute(
        NoteEditorScreen(
          defaultCategory: 'Uncategorized',
          initialTitle: trimmed,
        ),
      ),
    );
    if (mounted && _queryCtrl.text.trim().isNotEmpty) {
      _runSearch(_queryCtrl.text);
    }
  }

  void _tapRecentSearch(String term) {
    QuickNotesHaptics.selection();
    _queryCtrl.text = term;
    _queryCtrl.selection = TextSelection.collapsed(offset: term.length);
  }

  _Scope _scopeFromString(String s) {
    switch (s) {
      case 'notes':
        return _Scope.notes;
      case 'tasks':
        return _Scope.tasks;
      case 'folders':
        return _Scope.folders;
      case 'categories':
        return _Scope.categories;
      default:
        return _Scope.all;
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : _kGroupedBg,
      body: SafeArea(
        child: Column(
          children: [
            _headerBar,
            const SizedBox(height: 12),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: disableAnimations
                    ? Duration.zero
                    : QuickNotesMotion.kMotionSheetPresent,
                curve: QuickNotesMotion.kMotionAppleEase,
                builder: (context, value, child) {
                  final effectiveValue = disableAnimations ? 1.0 : value;
                  return Transform.translate(
                    offset: Offset(0, 36.0 * (1.0 - effectiveValue)),
                    child: Opacity(
                      opacity: effectiveValue,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    _SearchScopeSelector(
                      scopeNotifier: _scopeNotifier,
                      onScopeChanged: _onScopeChanged,
                      disableAnimations: disableAnimations,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _SearchBodySheet(
                        searchNotifier: _searchNotifier,
                        entryFade: _entryFade,
                        scrollCtrl: _scrollCtrl,
                        onTapRecent: _tapRecentSearch,
                        onDeleteRecent: _removeSearch,
                        onClearAllRecent: _clearAllSearches,
                        onOpenNote: _openNote,
                        onOpenTask: _openTask,
                        onOpenFolder: _openFolder,
                        onOpenCategory: _openCategory,
                        onCreateNoteWithTitle: _createNoteWithTitle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. AppHeader Bar (Liquid Glass) — Isolated Rebuild Surface (G-04)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchHeaderBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onBack;
  final VoidCallback onCloseOrClear;
  final ValueChanged<String> onSubmitted;

  const _SearchHeaderBar({
    required this.controller,
    required this.focusNode,
    required this.onBack,
    required this.onCloseOrClear,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0.0),
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
                  onTap: onBack,
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/angle_left.svg',
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(
                        isDark ? Colors.white : _kInk,
                        BlendMode.srcIn,
                      ),
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
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: true,
                        cursorColor: isDark
                            ? const Color(0xFFFFCC00)
                            : const Color(0xFF1C1C1E),
                        keyboardAppearance:
                            isDark ? Brightness.dark : Brightness.light,
                        textInputAction: TextInputAction.search,
                        onSubmitted: onSubmitted,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: isDark ? Colors.white : _kInk,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Search notes, tasks, folders...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 15,
                            color: isDark
                                ? const Color(0xFF8E8E93)
                                : _kPlaceholder,
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
                  onTap: onCloseOrClear,
                  child: Center(
                    child: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white : _kInk,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Scope Pill Bar — Isolated Rebuild Surface (G-04)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchScopeSelector extends StatelessWidget {
  final ValueNotifier<_Scope> scopeNotifier;
  final ValueChanged<_Scope> onScopeChanged;
  final bool disableAnimations;

  const _SearchScopeSelector({
    required this.scopeNotifier,
    required this.onScopeChanged,
    required this.disableAnimations,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: ValueListenableBuilder<_Scope>(
        valueListenable: scopeNotifier,
        builder: (context, currentScope, _) {
          const scopes = _Scope.values;
          return SizedBox(
            height: 40.0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: scopes.map((s) {
                  final isActive = currentScope == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: GestureDetector(
                      onTap: () => onScopeChanged(s),
                      child: AnimatedContainer(
                        duration: disableAnimations
                            ? Duration.zero
                            : QuickNotesMotion.kMotionSelection,
                        curve: QuickNotesMotion.kMotionAppleEase,
                        height: 40.0,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _kAmberYellow
                              : (isDark
                                  ? const Color(0xFF38383A)
                                  : _kPillInactive),
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _scopeLabel(s),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight:
                                isActive ? FontWeight.w500 : FontWeight.w400,
                            color: isActive
                                ? Colors.white
                                : (isDark
                                    ? const Color(0xFF8E8E93)
                                    : _kLabelSecondary),
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
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Main Body Card Sheet (G-03, G-04, G-07, G-13)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBodySheet extends StatelessWidget {
  final ValueNotifier<_SearchState> searchNotifier;
  final Animation<double> entryFade;
  final ScrollController scrollCtrl;
  final ValueChanged<String> onTapRecent;
  final ValueChanged<String> onDeleteRecent;
  final VoidCallback onClearAllRecent;
  final ValueChanged<Note> onOpenNote;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<Folder> onOpenFolder;
  final ValueChanged<String> onOpenCategory;
  final ValueChanged<String> onCreateNoteWithTitle;

  const _SearchBodySheet({
    required this.searchNotifier,
    required this.entryFade,
    required this.scrollCtrl,
    required this.onTapRecent,
    required this.onDeleteRecent,
    required this.onClearAllRecent,
    required this.onOpenNote,
    required this.onOpenTask,
    required this.onOpenFolder,
    required this.onOpenCategory,
    required this.onCreateNoteWithTitle,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : _kSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
        boxShadow: const [
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
        child: ValueListenableBuilder<_SearchState>(
          valueListenable: searchNotifier,
          builder: (context, state, _) {
            switch (state.uiState) {
              case _UiState.empty:
                return FadeTransition(
                  opacity: entryFade,
                  child: _buildEmptyState(state, isDark: isDark),
                );
              case _UiState.typing:
                return _buildTypingState(state, isDark: isDark);
              case _UiState.results:
                return _buildResultsState(context, state, isDark: isDark);
              case _UiState.noResults:
                return _buildNoResultsState(state, isDark: isDark);
            }
          },
        ),
      ),
    );
  }

  // ── State 1: Empty (Recent Searches) ──────────────────────────────────────
  // G-03: Header and divider only appear here in empty state
  Widget _buildEmptyState(_SearchState state, {required bool isDark}) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: isDark ? const Color(0xFF8E8E93) : _kLabelSecondary,
                  letterSpacing: -0.43,
                ),
              ),
              GestureDetector(
                onTap: onClearAllRecent,
                child: Text(
                  'Clear all',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isDark ? const Color(0xFF8E8E93) : _kLabelSecondary,
                    letterSpacing: -0.43,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
            color: isDark ? const Color(0xFF38383A) : _kDivider, height: 1),
        const SizedBox(height: 12),
        if (state.recentSearches.isNotEmpty)
          ...state.recentSearches.map((term) => _RecentSearchRow(
                term: term,
                onTap: () => onTapRecent(term),
                onDelete: () => onDeleteRecent(term),
              )),
      ],
    );
  }

  // ── State 2: Typing (Shimmer Skeleton) ────────────────────────────────────
  Widget _buildTypingState(_SearchState state, {required bool isDark}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        if (state.isLoading) ...[
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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF757575) : _kPlaceholder,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        ...List.generate(
            5,
            (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ShimmerRow(index: i),
                )),
      ],
    );
  }

  // ── State 3: Results (G-07 True Lazy Sliver Architecture) ──────────────────
  Widget _buildResultsState(BuildContext context, _SearchState state,
      {required bool isDark}) {
    final gen = state.resultGeneration;
    final query = state.query;
    final noteResults = state.noteResults;
    final taskResults = state.taskResults;
    final folderResults = state.folderResults;
    final categoryResults = state.categoryResults;

    final List<Widget> slivers = [];
    int nextIndex = 0;

    // 1. NOTES Sliver
    if (noteResults.isNotEmpty) {
      final headerIdx = nextIndex++;
      final noteBaseIdx = nextIndex;
      nextIndex += noteResults.length;

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: AnimatedListEntrance(
              key: ValueKey('header_NOTES_$gen'),
              index: headerIdx,
              child: _SectionHeader(label: 'NOTES', count: noteResults.length),
            ),
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: noteResults.length,
            itemBuilder: (context, i) {
              final n = noteResults[i];
              return AnimatedListEntrance(
                key: ValueKey('note_${n.id}_$gen'),
                index: noteBaseIdx + i,
                child: SearchNoteCard(
                  note: n,
                  query: query,
                  onTap: () => onOpenNote(n),
                ),
              );
            },
          ),
        ),
      );
    }

    // 2. TASKS Sliver
    if (taskResults.isNotEmpty) {
      final headerIdx = nextIndex++;
      final taskBaseIdx = nextIndex;
      nextIndex += taskResults.length;

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, noteResults.isEmpty ? 8 : 0, 20, 0),
          sliver: SliverToBoxAdapter(
            child: AnimatedListEntrance(
              key: ValueKey('header_TASKS_$gen'),
              index: headerIdx,
              child: _SectionHeader(label: 'TASKS', count: taskResults.length),
            ),
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: taskResults.length,
            itemBuilder: (context, i) {
              final t = taskResults[i];
              return AnimatedListEntrance(
                key: ValueKey('task_${t.id}_$gen'),
                index: taskBaseIdx + i,
                child: SearchTaskCard(
                  task: t,
                  query: query,
                  onTap: () => onOpenTask(t),
                ),
              );
            },
          ),
        ),
      );
    }

    // 3. FOLDERS Sliver (G-01 Dark-mode Folder Title + G-06 O(1) Note Counts)
    if (folderResults.isNotEmpty) {
      final headerIdx = nextIndex++;
      final folderBaseIdx = nextIndex;
      nextIndex += folderResults.length;

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              20, (noteResults.isEmpty && taskResults.isEmpty) ? 8 : 0, 20, 0),
          sliver: SliverToBoxAdapter(
            child: AnimatedListEntrance(
              key: ValueKey('header_FOLDERS_$gen'),
              index: headerIdx,
              child: _SectionHeader(
                  label: 'FOLDERS', count: folderResults.length),
            ),
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 150.0 / 192.0,
            ),
            itemCount: folderResults.length,
            itemBuilder: (context, folderIndex) {
              final f = folderResults[folderIndex];
              final noteCount = state.folderNoteCounts[f.id] ?? 0;
              return AnimatedListEntrance(
                key: ValueKey('folder_${f.id}_$gen'),
                index: folderBaseIdx + folderIndex,
                child: FolderGridCard(
                  folder: f,
                  index: folderIndex,
                  noteCount: noteCount,
                  query: query,
                  onTap: () => onOpenFolder(f),
                ),
              );
            },
          ),
        ),
      );
    }

    // 4. CATEGORIES Sliver (G-06 O(1) Note Counts)
    if (categoryResults.isNotEmpty) {
      final headerIdx = nextIndex++;
      final catBaseIdx = nextIndex;
      nextIndex += categoryResults.length;

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              20,
              (noteResults.isEmpty &&
                      taskResults.isEmpty &&
                      folderResults.isEmpty)
                  ? 8
                  : 0,
              20,
              0),
          sliver: SliverToBoxAdapter(
            child: AnimatedListEntrance(
              key: ValueKey('header_CATEGORIES_$gen'),
              index: headerIdx,
              child: _SectionHeader(
                  label: 'CATEGORIES', count: categoryResults.length),
            ),
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: categoryResults.length,
            itemBuilder: (context, i) {
              final c = categoryResults[i];
              final noteCount = state.categoryNoteCounts[c] ?? 0;
              return AnimatedListEntrance(
                key: ValueKey('cat_${c}_$gen'),
                index: catBaseIdx + i,
                child: _CategoryResultRow(
                  category: c,
                  noteCount: noteCount,
                  query: query,
                  dotColor: _categoryDotColor(c),
                  onTap: () => onOpenCategory(c),
                ),
              );
            },
          ),
        ),
      );
    }

    // Bottom padding spacer
    slivers.add(
      const SliverToBoxAdapter(
        child: SizedBox(height: 32.0),
      ),
    );

    return CustomScrollView(
      controller: scrollCtrl,
      slivers: slivers,
    );
  }

  // ── State 4: No Results (G-13 Redundant FadeTransition Removed) ───────────
  Widget _buildNoResultsState(_SearchState state, {required bool isDark}) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF38383A) : _kGroupedBg,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.search_rounded,
                        size: 36,
                        color: isDark
                            ? const Color(0xFF8E8E93)
                            : _kLabelSecondary),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF2C2C2C) : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded,
                            size: 13,
                            color: isDark
                                ? const Color(0xFF8E8E93)
                                : _kLabelSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No results for "${state.query.trim()}"',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : _kInk),
              ),
              const SizedBox(height: 6),
              Text(
                'Try searching across all scopes or categories',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF757575) : _kPlaceholder),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Divider(color: isDark ? const Color(0xFF38383A) : _kDivider),
        const SizedBox(height: 16),
        Text(
          'CREATE NEW',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFF8E8E93) : _kLabelSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => onCreateNoteWithTitle(state.query.trim()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF38383A)
                  : const Color(0xFFF0EDD8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isDark ? const Color(0xFF48484A) : _kDivider),
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
                  child: Icon(Icons.add_rounded,
                      color: isDark
                          ? const Color(0xFFFFCC00)
                          : const Color(0xFFD49200),
                      size: 20),
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : _kInk),
                            ),
                            TextSpan(
                              text: state.query.trim(),
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFFFFCC00)
                                      : const Color(0xFFD49200)),
                            ),
                            TextSpan(
                              text: '"',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : _kInk),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Start a new note with this title',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF8E8E93)
                                : _kPlaceholder),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: isDark ? const Color(0xFF757575) : _kPlaceholder),
              ],
            ),
          ),
        ),
      ],
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF8E8E93) : _kLabelSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF38383A) : _kPillInactive,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF8E8E93) : _kLabelSecondary,
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(Icons.history_rounded,
                size: 18,
                color: isDark ? const Color(0xFF8E8E93) : _kLabelSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                term,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    color: isDark ? Colors.white : _kInk,
                    fontWeight: FontWeight.w400),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.close_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFF757575) : _kPlaceholder),
              ),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final base = GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white : _kInk);
    final hl = base.copyWith(
        color: isDark ? const Color(0xFFFFCC00) : const Color(0xFFD49200),
        fontWeight: FontWeight.w700);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFFDF7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark ? const Color(0xFF38383A) : _kDivider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                    children: _buildHighlightSpans(category, query,
                        base: base, highlight: hl)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$noteCount notes',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF8E8E93) : _kPlaceholder),
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
  bool _repeating = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      if (_repeating) {
        _ctrl.stop();
        _repeating = false;
      }
    } else {
      if (!_repeating) {
        _ctrl.repeat(reverse: true);
        _repeating = true;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor = isDark ? const Color(0xFF38383A) : _kPillInactive;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      return Container(
        height: 72,
        decoration: BoxDecoration(
          color: shimmerColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.3 + _anim.value * 0.35;
        return Opacity(
          opacity: opacity,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
    );
  }
}
