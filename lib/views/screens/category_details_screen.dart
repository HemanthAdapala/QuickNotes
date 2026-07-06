// ──────────────────────────────────────────────────────────────────────────────
// category_details_screen.dart — "Category Details Screen"
// Mockup source: "Category Details Screens" attached image
//
// Screens shown in mockup:
//   • Centre phone: category detail with note cards
//   • Right phone:  empty state with folder icon
//
// TYPOGRAPHY (project rules):
//   Screen title / card titles : GoogleFonts.playfairDisplay
//   Labels / body / chips      : GoogleFonts.inter
//   Section headers            : GoogleFonts.jetBrainsMono
//
// ALL spacing, colour, and size values read from the mockup image.
// ──────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../providers/notes_provider.dart';
import '../../models/note_summary.dart';
import '../../themes/app_theme.dart';
import '../../core/animations/animation_constants.dart';
import '../../core/animations/animated_list_entrance.dart';
import '../../core/animations/page_transitions.dart';
import '../../core/animations/search_route.dart';
import 'search_screen.dart';
import '../../core/animations/bottom_sheet_transition.dart';
import '../widgets/tactile_button.dart';
import '../widgets/app_header_bar.dart';
import '../widgets/living_writing_experience.dart';
import '../widgets/pin_lock_sheet.dart';
import 'note_editor_screen.dart';
import 'folder_notes_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MOCKUP TOKEN MAP
//
// Category accent colours — one per category (read from the mockup's
// category list: Personal=blue, Work=green, Ideas=yellow, Study=pink,
// Hobbies=purple, Recipes=blue-2, Uncategorized=grey).
// These are used for: the title dot, card tint, header soft tint.
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, Color> _kCategoryDotColors = {
  'Personal':      Color(0xFF4A90D9), // blue dot  — mockup
  'Work':          Color(0xFF4CAF50), // green dot
  'Ideas':         Color(0xFFFFB800), // yellow dot
  'Study':         Color(0xFFE91E63), // pink dot
  'Hobbies':       Color(0xFF9C27B0), // purple dot
  'Recipes':       Color(0xFF64B5F6), // light blue
  'Uncategorized': Color(0xFF9E9E9E), // grey
};

// Fallback dot colour for custom categories not in the map
Color _categoryDotColor(String category) {
  if (_kCategoryDotColors.containsKey(category)) {
    return _kCategoryDotColors[category]!;
  }
  // Deterministic colour from hash for custom categories
  final hue = (category.hashCode.abs() % 360).toDouble();
  return HSLColor.fromAHSL(1.0, hue, 0.55, 0.50).toColor();
}

// ─────────────────────────────────────────────────────────────────────────────
// CategoryDetailsScreen
// ─────────────────────────────────────────────────────────────────────────────

class CategoryDetailsScreen extends StatefulWidget {
  /// The category name to display (e.g. "Personal", "Work").
  final String category;

  /// Optional explicit accent colour override. Falls back to [_categoryDotColor].
  final Color? accentColor;

  const CategoryDetailsScreen({
    super.key,
    required this.category,
    this.accentColor,
  });

  @override
  State<CategoryDetailsScreen> createState() => _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends State<CategoryDetailsScreen>
    with TickerProviderStateMixin {

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isFabVisible = true;
  final GlobalKey _fabKey = GlobalKey();
  late ScrollController _scrollController;

  // Soft tint on the header area (category accent at ~12% opacity)
  late AnimationController _tintCtrl;
  late Animation<Color?>    _tintAnim;
  bool _tintReady = false;

  // Fade-in gate for the note list (waits for push-transition to finish)
  double _fadeProgress = 0.0;

  Color get _accent =>
      widget.accentColor ?? _categoryDotColor(widget.category);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);

    _tintCtrl = AnimationController(vsync: this, duration: kDurationNormal);
    _tintAnim = ColorTween(
      begin: AppColors.background,
      end:   AppColors.background,
    ).animate(_tintCtrl);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<NotesProvider>(context, listen: false);
      provider.setSelectedCategory(widget.category);
      
      final route = ModalRoute.of(context);
      if (route != null) {
        route.animation?.addListener(_onRouteAnim);
        route.animation?.addStatusListener(_onRouteStatus);
      } else {
        if (mounted) setState(() => _fadeProgress = 1.0);
      }
    });
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 700) {
      final provider = Provider.of<NotesProvider>(context, listen: false);
      if (provider.hasMoreNotes && !provider.isPageLoading) {
        provider.loadNextPage();
      }
    }
  }

  void _onRouteAnim() {
    final v = ModalRoute.of(context)?.animation?.value ?? 0.0;
    if (mounted) {
      setState(() {
        _fadeProgress = v >= 0.75 ? ((v - 0.75) / 0.25).clamp(0.0, 1.0) : 0.0;
      });
    }
  }

  void _onRouteStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && mounted) {
      setState(() => _fadeProgress = 1.0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tintReady) {
      final theme  = Theme.of(context);
      const isDark = false;
      final base   = isDark ? theme.scaffoldBackgroundColor : AppColors.background;
      final end    = Color.lerp(base, _accent, isDark ? 0.08 : 0.12)!;

      _tintAnim = ColorTween(begin: base, end: end)
          .animate(CurvedAnimation(parent: _tintCtrl, curve: kCurveDefault));
      _tintCtrl.forward();
      _tintReady = true;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _tintCtrl.dispose();
    final route = ModalRoute.of(context);
    route?.animation?.removeListener(_onRouteAnim);
    route?.animation?.removeStatusListener(_onRouteStatus);
    
    // Reset category selection safely
    try {
      Provider.of<NotesProvider>(context, listen: false).setSelectedCategory("All");
    } catch (_) {}
    
    super.dispose();
  }

  // ── Note tap ───────────────────────────────────────────────────────────────

  void _onNoteTap(NoteSummary note, NotesProvider provider) async {
    final fullNote = await provider.getNoteById(note.id);
    if (fullNote == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load note details')),
        );
      }
      return;
    }

    if (fullNote.isLocked && !provider.isVaultUnlocked) {
      showAnimatedBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: PinLockSheet(
          onPinSubmitted: (pin) async {
            final nav  = Navigator.of(context);
            final msng = ScaffoldMessenger.of(context);
            if (await provider.unlockVault(pin)) {
              final decryptedNote = await provider.getNoteById(note.id);
              if (mounted && decryptedNote != null) nav.push(buildPageRoute(NoteEditorScreen(note: decryptedNote)));
            } else {
              if (mounted) {
                msng
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(
                    content: Text('Incorrect PIN Code! Access Denied.'),
                    backgroundColor: Colors.red,
                  ));
              }
            }
          },
        ),
      );
    } else {
      Navigator.push(context, buildPageRoute(NoteEditorScreen(note: fullNote)));
    }
  }

  // ── Options sheet ──────────────────────────────────────────────────────────

  void _showOptions(NoteSummary note, NotesProvider provider) {
    showAnimatedBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Builder(builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Text(
                  note.title.isNotEmpty ? note.title : 'Untitled Note',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize:   16,
                    color:      theme.colorScheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  note.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                ),
                title: Text(note.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                onTap: () { Navigator.pop(ctx); provider.toggleFavorite(note.id); },
              ),
              ListTile(
                leading: Icon(
                  note.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(note.isArchived ? 'Unarchive Note' : 'Archive Note'),
                onTap: () {
                  Navigator.pop(ctx);
                  provider.toggleArchive(note.id);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content:  Text(note.isArchived ? 'Note unarchived' : 'Note archived'),
                      duration: const Duration(seconds: 1),
                    ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Delete (Move to Trash)'),
                onTap: () {
                  Navigator.pop(ctx);
                  provider.trashNote(note.id);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: const Text('Note moved to Trash'),
                      action: SnackBarAction(
                        label: 'UNDO',
                        onPressed: () => provider.restoreFromTrash(note.id),
                      ),
                    ));
                },
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── Swipe action backgrounds ───────────────────────────────────────────────

  Widget _swipeBg({required bool isSecondary}) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isSecondary
            ? theme.colorScheme.primaryContainer.withAlpha(80)
            : theme.colorScheme.secondaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFFAF8F5) : AppColors.ink,
          width: 1.5,
        ),
      ),
      padding:   const EdgeInsets.symmetric(horizontal: 24),
      alignment: isSecondary ? Alignment.centerRight : Alignment.centerLeft,
      child: Icon(
        isSecondary ? Icons.more_horiz_rounded : Icons.push_pin_rounded,
        color: theme.colorScheme.onSurface,
        size: 28,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TITLE BLOCK
  //
  // Mockup:
  //   Row: category name (Playfair Bold ~34px) + small accent dot (~10px)
  //   Below: "ACROSS X FOLDERS · Y NOTES"
  //          Inter Regular ~11px  #828282  uppercase  letterSpacing ~1.2
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTitleBlock(
    BuildContext context,
    List<NoteSummary> catNotes,
    NotesProvider provider,
    bool isDark,
  ) {
    // Count unique folders these notes belong to
    final folderIds = catNotes
        .map((n) => n.folderId)
        .where((id) => id != null)
        .toSet();
    final folderCount = folderIds.length;
    final noteCount   = catNotes.length;

    return Padding(
      // Matches nav bar horizontal margin: 30px sides, top: 12px below nav bar
      padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category name + accent dot inline
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.category,
                  style: GoogleFonts.playfairDisplay(    // project rule: Playfair for titles
                    fontSize:      34,
                    fontWeight:    FontWeight.w700,       // Bold
                    color:         isDark ? Colors.white : const Color(0xFF333333),
                    letterSpacing: 0.0,
                    height:        1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Accent dot — mockup shows ~10px circle after the title
              Container(
                width:  10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Subtitle "ACROSS X FOLDERS · Y NOTES"
          // Mockup: Inter Regular, ~11px, #828282, uppercase, letterSpacing ~1.2
          Text(
            'ACROSS $folderCount ${folderCount == 1 ? 'FOLDER' : 'FOLDERS'} · $noteCount ${noteCount == 1 ? 'NOTE' : 'NOTES'}',
            style: GoogleFonts.inter(               // project rule: Inter for labels
              fontSize:      11,
              fontWeight:    FontWeight.w400,       // Regular
              color:         isDark ? Colors.white54 : const Color(0xFF828282),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NOTE LIST
  //
  // Mockup measurements:
  //   cards  : full width, 24px horizontal padding
  //   radius : 16px
  //   gap    : 12px between cards
  //   top gap from title block to first card: 16px
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNoteList(List<NoteSummary> notes, NotesProvider provider, ThemeData theme) {
    return ListView.builder(
      controller:  _scrollController,
      physics:     const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(
        left:   24,
        right:  24,
        top:    0,
        bottom: 120,
      ),
      itemCount:   notes.length + (provider.isPageLoading ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == notes.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          );
        }
        final note = notes[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0), // mockup gap
          child: AnimatedListEntrance(
            key:   ValueKey(note.id),
            index: i,
            child: Dismissible(
              key:       Key('cat_${note.id}'),
              direction: DismissDirection.horizontal,
              background:          _swipeBg(isSecondary: false),
              secondaryBackground: _swipeBg(isSecondary: true),
              confirmDismiss: (dir) async {
                if (dir == DismissDirection.startToEnd) {
                  provider.togglePin(note.id);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content:  Text(note.isPinned ? 'Note unpinned' : 'Note pinned'),
                      duration: const Duration(seconds: 1),
                    ));
                } else {
                  _showOptions(note, provider);
                }
                return false;
              },
              child: _CategoryNoteCard(
                note:        note,
                provider:    provider,
                onTap:       () => _onNoteTap(note, provider),
                onPinToggle: () => provider.togglePin(note.id),
                onDelete:    () {
                  provider.trashNote(note.id);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: const Text('Note moved to Recycle Bin'),
                      action:  SnackBarAction(
                        label:     'UNDO',
                        onPressed: () => provider.restoreFromTrash(note.id),
                      ),
                    ));
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMPTY STATE
  //
  // Mockup (right phone):
  //   Large rounded card, sage-green bg, ~20px radius, 24px margins
  //   Folder icon outline ~72px + decorative dots
  //   Title  : "No notes tagged [Category] yet"
  //             Playfair Display Bold ~20px  #211A12  centered
  //   Subtitle: "Assign this category from the note editor"
  //              Inter Regular ~13px  #524534  centered
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final cardBg = isDark
        ? const Color(0xFF1E3A2F)   // dark sage
        : const Color(0xFFD4ECDD);  // light sage — Sage pastcl from provider (index 4)

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        decoration: BoxDecoration(
          color:         cardBg,
          borderRadius:  BorderRadius.circular(20), // mockup radius
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Folder illustration + decorative dots
            SizedBox(
              width:  120,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Main folder icon
                  Icon(
                    Icons.folder_open_outlined,
                    size:  72,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFF524534).withValues(alpha: 0.6),
                  ),
                  // Decorative dot top-right
                  Positioned(
                    top:   4,
                    right: 8,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent.withValues(alpha: 0.80),
                      ),
                    ),
                  ),
                  // Decorative dot top-left
                  Positioned(
                    top:  14,
                    left: 14,
                    child: Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent.withValues(alpha: 0.50),
                      ),
                    ),
                  ),
                  // Decorative dot bottom-right
                  Positioned(
                    bottom: 10,
                    right:  12,
                    child: Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent.withValues(alpha: 0.60),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Empty state title — Playfair Display Bold ~20px
            Text(
              'No notes tagged\n${widget.category} yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(    // project rule: Playfair for headings
                fontSize:   20,
                fontWeight: FontWeight.w700,          // Bold
                color: isDark ? Colors.white : const Color(0xFF211A12),
                height: 1.3,
              ),
            ),

            const SizedBox(height: 8),

            // Empty state subtitle — Inter Regular ~13px
            Text(
              'Assign this category from the note editor',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(              // project rule: Inter for body
                fontSize:   13,
                fontWeight: FontWeight.w400,          // Regular
                color: isDark
                    ? Colors.white60
                    : const Color(0xFF524534).withValues(alpha: 0.75),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    const isDark   = false;
    final provider = Provider.of<NotesProvider>(context);

    // All active notes belonging to this category
    final catNotes = provider.notesSummary
        .where((n) => n.categoryName == widget.category)
        .toList();

    // Sort: pinned first, then newest
    catNotes.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    final scaffoldBg = isDark ? theme.scaffoldBackgroundColor : AppColors.background;

    return Scaffold(
      backgroundColor: scaffoldBg,

      // ── FAB ───────────────────────────────────────────────────────────────
      // Opens NoteEditorScreen with this category pre-selected
      floatingActionButton: AnimatedScale(
        scale:    _isFabVisible ? 1.0 : 0.0,
        duration: kDurationFast,
        curve:    _isFabVisible ? kCurveEnter : kCurveExit,
        child: AnimatedOpacity(
          opacity:  _isFabVisible ? 1.0 : 0.0,
          duration: kDurationFast,
          curve:    _isFabVisible ? kCurveEnter : kCurveExit,
          child: LivingFloatingActionButton(
            key:             _fabKey,
            backgroundColor: AppColors.amber,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              side: BorderSide(
                color: isDark ? Color(0xFFFAF8F5) : AppColors.ink,
                width: 1.5,
              ),
            ),
            elevation: 4,
            onPressed: () => Navigator.push(
              context,
              buildPageRoute(NoteEditorScreen(
                defaultCategory: widget.category,
              )),
            ),
            child: const Icon(Icons.add, size: 32),
          ),
        ),
      ),

      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is UserScrollNotification) {
            final show = n.direction != ScrollDirection.reverse;
            if (show != _isFabVisible) setState(() => _isFabVisible = show);
          }
          return false;
        },

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── HEADER ─────────────────────────────────────────────────────
            // Same nav-bar pattern as folder_notes_screen.dart:
            //   back arrow  ←  (angle_left.svg)  |  spacer  |  search icon Q
            //   h:38  margin:30px  top:24
            // Below nav bar: title block (title + dot + subtitle)
            // Total header area height: SafeArea + navBar(24+38) + titleBlock
            AnimatedBuilder(
              animation: _tintAnim,
              builder: (_, child) => Container(
                width:      double.infinity,
                decoration: BoxDecoration(color: _tintAnim.value),
                child:      child,
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nav bar row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                      child: AppHeaderBar(
                        leftWidth: 44.0,
                        onLeftTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).maybePop();
                        },
                        leftChild: SvgPicture.asset(
                          'assets/icons/angle_left.svg',
                          width: 22,
                          height: 22,
                          colorFilter: ColorFilter.mode(
                            isDark ? Colors.white : AppColors.ink,
                            BlendMode.srcIn,
                          ),
                        ),
                        rightWidth: 44.0,
                        rightChild: TactileButton(
                          useAppleSpring: true,
                          compressionScale: 0.7,
                          settleDuration: const Duration(milliseconds: 1000),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(SearchRoute(
                              builder: (_) => SearchScreen(
                                initialScope: 'notes',
                                presetCategory: widget.category,
                              ),
                            ));
                          },
                          child: Center(
                            child: Icon(
                              Icons.search_rounded,
                              size: 22,
                              color: isDark ? Colors.white : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Title block
                    _buildTitleBlock(context, catNotes, provider, isDark),

                    // Gap: title block bottom → first card top (mockup ~16px)
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── NOTE CARDS / EMPTY STATE ────────────────────────────────────
            // cards at x:24  gap:12px  radius:16px
            Expanded(
              child: Opacity(
                opacity: _fadeProgress,
                child: IgnorePointer(
                  ignoring: _fadeProgress < 0.5,
                  child: catNotes.isEmpty
                      ? SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 120),
                            child: _buildEmptyState(context, isDark),
                          ),
                        )
                      : Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: _buildNoteList(catNotes, provider, theme),
                          ),
                        ),
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
// _CategoryNoteCard
//
// Matches the card layout shown in the centre phone mockup.
//
// MOCKUP MEASUREMENTS
// ───────────────────
// Card width      : full column (screen width - 48px padding)
// Card height     : content-driven (~130-150px)
// Corner radius   : 16px  (slightly tighter than folder cards)
// Background      : note's pastel color (NotesProvider.getNoteColor)
// Inner padding   : 16px all sides
//
// TOP ROW (mockup):
//   left  → weight label "Inter 500" or "Inter 400"
//            Inter Regular ~11px  #524534 @ 70%
//   right → folder name pill e.g. "WEEKDAYS"
//            Inter Medium 10px  uppercase  pill bg = card color darkened ~20%
//            pill padding: 3px vertical / 8px horizontal  radius: 4px
//
// TITLE:
//   Playfair Display SemiBold 600  ~20px  #211A12  (project rule)
//
// BODY:
//   Inter Regular 400  ~13px  #524534  1 line  (project rule)
//
// FOOTER ROW:
//   left  → 8px circle dot (#524534 @ 60%) + "Color" label Inter 12px #828282
//   right → date "Jan 15, 2022"  Inter Regular 12px  #828282
//   footer padding-top: 12px
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryNoteCard extends StatefulWidget {
  final NoteSummary  note;
  final NotesProvider provider;
  final VoidCallback onTap;
  final VoidCallback onPinToggle;
  final VoidCallback onDelete;

  const _CategoryNoteCard({
    required this.note,
    required this.provider,
    required this.onTap,
    required this.onPinToggle,
    required this.onDelete,
  });

  @override
  State<_CategoryNoteCard> createState() => _CategoryNoteCardState();
}

class _CategoryNoteCardState extends State<_CategoryNoteCard>
    with SingleTickerProviderStateMixin {

  late AnimationController _press;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: kDurationCardPress);
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _press, curve: kCurveExit));
  }

  @override
  void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cardColor = NotesProvider.getNoteColor(widget.note.colorValue, context);
    final date      = DateFormat('MMM d, yyyy').format(widget.note.updatedAt);

    final folderName = widget.note.folderName?.toUpperCase();

    // Pill badge background: card color blended toward ink (~20% darker)
    final pillBg = Color.lerp(
      cardColor,
      const Color(0xFF524534),
      0.18,
    )!;

    return GestureDetector(
      behavior:    HitTestBehavior.opaque,
      onTapDown:   (_) => _press.animateTo(1.0, duration: kDurationCardPress,   curve: kCurveExit),
      onTapUp:     (_) { _press.animateTo(0.0, duration: kDurationCardRelease, curve: kCurveEnter); widget.onTap(); },
      onTapCancel: ()  => _press.animateTo(0.0, duration: kDurationCardRelease, curve: kCurveEnter),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: _buildCard(context, cardColor, date, folderName, pillBg),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Color cardColor,
    String date,
    String? folderName,
    Color pillBg,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration:    kDurationNormal,
      width:       double.infinity,
      decoration:  BoxDecoration(
        color:        cardColor,
        borderRadius: BorderRadius.circular(16), // mockup: 16px
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      // Inner padding: 16px all sides (mockup)
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:       MainAxisSize.min,
          children: [

            // ── TOP ROW ────────────────────────────────────────────────────
            // Left:  weight label "Inter 500" / "Inter 400"
            // Right: folder name pill "WEEKDAYS"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Note weight label — mockup shows "Inter 500" or "Inter 400"
                // This is the font-weight of the note's type label
                Text(
                  widget.note.isPinned
                      ? 'Pinned'
                      : (widget.note.noteType == 'checklist' ? 'Checklist' : 'Inter ${widget.note.colorValue > 0 ? '500' : '400'}'),
                  style: GoogleFonts.inter(        // project rule: Inter for labels
                    fontSize:   11,
                    fontWeight: FontWeight.w400,   // Regular
                    color:      const Color(0xFF524534).withValues(alpha: 0.70),
                    letterSpacing: 0.2,
                  ),
                ),

                // Folder name pill (only shown if note belongs to a folder)
                if (folderName != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final noteFolder = widget.provider.folders.firstWhere((f) => f.id == widget.note.folderId);
                      Navigator.of(context).push(
                        buildPageRoute(FolderNotesScreen(folder: noteFolder)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),    // mockup pill padding
                      decoration: BoxDecoration(
                        color:        pillBg,
                        borderRadius: BorderRadius.circular(4), // mockup: small radius
                      ),
                      child: Text(
                        folderName,
                        style: GoogleFonts.inter(    // project rule: Inter for labels
                          fontSize:      10,         // mockup: ~10px
                          fontWeight:    FontWeight.w500, // Medium
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF524534).withValues(alpha: 0.85),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            // ── TITLE ──────────────────────────────────────────────────────
            // Playfair Display SemiBold 600 · 20px · #211A12
            Text(
              widget.note.isLocked
                  ? 'Locked Note'
                  : (widget.note.title.isNotEmpty ? widget.note.title : 'Untitled'),
              style: GoogleFonts.playfairDisplay(   // project rule: Playfair for titles
                fontSize:   20,
                fontWeight: FontWeight.w600,         // SemiBold
                color:      isDark ? Colors.white : const Color(0xFF211A12),
                height:     1.25,
              ),
              maxLines:  2,
              overflow:  TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            // ── BODY ───────────────────────────────────────────────────────
            // Inter Regular 400 · 13px · #524534  (mockup: 1 line snippet)
            Text(
              widget.note.isLocked
                  ? '••••••••••••••••'
                  : (widget.note.previewText.isNotEmpty
                      ? widget.note.previewText
                      : 'No additional text'),
              style: GoogleFonts.inter(             // project rule: Inter for body
                fontSize:   13,
                fontWeight: FontWeight.w400,        // Regular
                color: widget.note.previewText.isNotEmpty
                    ? (isDark
                        ? Colors.white70
                        : const Color(0xFF524534))
                    : const Color(0xFF524534).withValues(alpha: 0.45),
                height:     1.5,
              ),
              maxLines:  1,
              overflow:  TextOverflow.ellipsis,
            ),

            // ── FOOTER ROW ─────────────────────────────────────────────────
            // padding-top: 12px  (mockup)
            // left:  8px dot + "Color" label
            // right: date "Jan 15, 2022"
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: dot + color label
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 8px circle dot — #524534 @ 60% (mockup)
                    Container(
                      width:  8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white38
                            : const Color(0xFF524534).withValues(alpha: 0.60),
                      ),
                    ),
                    const SizedBox(width: 5),
                    // "Color" label — Inter Regular 12px #828282
                    Text(
                      NotesProvider.colorNames.length > widget.note.colorValue
                          ? NotesProvider.colorNames[widget.note.colorValue]
                          : 'Default',
                      style: GoogleFonts.inter(
                        fontSize:   12,
                        fontWeight: FontWeight.w400,
                        color:      isDark ? Colors.white38 : const Color(0xFF828282),
                      ),
                    ),
                    if (widget.note.isPinned) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.push_pin,
                          size:  11,
                          color: const Color(0xFF524534).withValues(alpha: 0.5)),
                    ],
                  ],
                ),

                // Right: date — Inter Regular 12px #828282
                Text(
                  date,
                  style: GoogleFonts.inter(
                    fontSize:   12,
                    fontWeight: FontWeight.w400,
                    color:      isDark ? Colors.white38 : const Color(0xFF828282),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
