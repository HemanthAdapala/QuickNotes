// ──────────────────────────────────────────────────────────────────────────────
// folder_notes_screen.dart — "Folder Details Screen"
// Figma source: node #106:133  |  File: Quick Notes Design
//
// TYPOGRAPHY RULES (project-wide):
//   Headings / Folder name : GoogleFonts.playfairDisplay  Bold 700
//   Card titles            : GoogleFonts.playfairDisplay  SemiBold 600
//   Body / preview text    : GoogleFonts.inter            Regular 400
//   Labels / chips / meta  : GoogleFonts.inter            Medium 500 / SemiBold 600
//   Section labels         : GoogleFonts.jetBrainsMono    ExtraBold 800
//
// ALL spacing, colour, and size values are extracted directly from Figma.
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
import '../../models/folder.dart';
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

// ─────────────────────────────────────────────────────────────────────────────
// FIGMA TOKEN MAP
// ─────────────────────────────────────────────────────────────────────────────

// Screen background: fill_87407946 → #F9F6E5 (= AppColors.background)

// Card pastel fills (assigned cyclically via note index):
//   Card 1 → #FFBDE6  pink
//   Card 2 → #FFED94  yellow
//   Card 3 → #B9E9FF  blue
//   Card 4 → #E0F7C8  green
const List<Color> _kCardPastels = [
  Color(0xFFFFBDE6),
  Color(0xFFFFED94),
  Color(0xFFB9E9FF),
  Color(0xFFE0F7C8),
];

// Filter chip fills
// "All"        active  → fill_07144391 #F5A623   text #644000
// "Pinned"     inactive→ #E9E1D9                  text fill_3562f37a #524534
// "Checklists" inactive→ #EAE4DD                  text fill_3562f37a #524534
const Color _kChipAmber        = Color(0xFFF5A623); // fill_07144391
const Color _kChipAmberTxt     = Color(0xFF644000);
const Color _kChipPinnedFill   = Color(0xFFE9E1D9);
const Color _kChipCheckFill    = Color(0xFFEAE4DD);
const Color _kChipInactiveTxt  = Color(0xFF524534); // fill_3562f37a

// Card typography colours
const Color _kCardTitleColor = Color(0xFF211A12); // fill_0e10275f
const Color _kCardBodyColor  = Color(0xFF524534); // fill_3562f37a
const Color _kSubtitleGrey   = Color(0xFF828282); // "12 NOTES" text

// Category dot: EL-f1395e12 → 8×8 fill:#F5A623 radius:∞
const Color _kDotColor = Color(0xFFF5A623); // fill_07144391


// ─────────────────────────────────────────────────────────────────────────────
// FolderNotesScreen
// ─────────────────────────────────────────────────────────────────────────────

class FolderNotesScreen extends StatefulWidget {
  final Folder folder;

  const FolderNotesScreen({
    super.key,
    required this.folder,
  });

  @override
  State<FolderNotesScreen> createState() => _FolderNotesScreenState();
}

class _FolderNotesScreenState extends State<FolderNotesScreen>
    with TickerProviderStateMixin {

  // ── State ─────────────────────────────────────────────────────────────────
  String _activeFilter = 'All'; // 'All' | 'Pinned'
  bool   _isFabVisible = true;
  final  GlobalKey _fabKey = GlobalKey();
  late   ScrollController _scrollController;

  // Animated soft tint on the header (folder accent colour at ~15 % opacity)
  late AnimationController _tintCtrl;
  late Animation<Color?>    _tintAnim;
  bool _tintReady = false;

  // Fade-in gate for the note list (waits for page-push transition to finish)
  double _fadeProgress = 0.0;

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
      provider.setSelectedFolder(widget.folder.id);
      
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
      final theme   = Theme.of(context);
      const isDark  = false;
      final provider = Provider.of<NotesProvider>(context, listen: false);
      final accent  = _folderAccentColor(provider);
      final base    = isDark ? theme.scaffoldBackgroundColor : AppColors.background;
      final end     = Color.lerp(base, accent, isDark ? 0.08 : 0.15)!;

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
    
    // Reset folder selection safely
    try {
      Provider.of<NotesProvider>(context, listen: false).setSelectedFolder(null);
    } catch (_) {}
    
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _folderAccentColor(NotesProvider provider) {
    final i = provider.folders.indexWhere((f) => f.id == widget.folder.id);
    final seed = i == -1 ? widget.folder.id.hashCode.abs() : i;
    return _kCardPastels[seed % _kCardPastels.length];
  }

  // ── Note tap (handles locked vault) ───────────────────────────────────────

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

  // ── Swipe action backgrounds ───────────────────────────────────────────────

  Widget _swipeBg({required bool isSecondary}) {
    final theme  = Theme.of(context);
    const isDark = false;
    return Container(
      decoration: BoxDecoration(
        color: isSecondary
            ? theme.colorScheme.primaryContainer.withAlpha(80)
            : theme.colorScheme.secondaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(20), // matches card radius
        border: Border.all(
          color: isDark ? const Color(0xFFFAF8F5) : AppColors.ink,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: isSecondary ? Alignment.centerRight : Alignment.centerLeft,
      child: Icon(
        isSecondary ? Icons.more_horiz_rounded : Icons.push_pin_rounded,
        color: theme.colorScheme.onSurface,
        size: 28,
      ),
    );
  }

  // ── Options bottom sheet ───────────────────────────────────────────────────

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
                  maxLines:  1,
                  overflow:  TextOverflow.ellipsis,
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
                      content: Text(note.isArchived ? 'Note unarchived' : 'Note archived'),
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

  // ─────────────────────────────────────────────────────────────────────────
  // FILTER CHIPS
  //
  // Figma: Section - Filter Chips Area  (#106:135)
  //   y:177  h:62  overflowScroll:x,y
  //   chips at internal y:18 (vertically centred in 62)
  //   chip gap: 4 px
  //   chips start at x:24
  //
  // "All"        #106:136  w:50   h:35  fill:#F5A623  text:#644000
  //              padding: 4.5px top / 16px sides / 5.09px bottom
  // "Pinned"     #106:138  w:80   h:35  fill:#E9E1D9  text:#524534
  //              padding: 4px top / 16px sides / 4px bottom
  // "Checklists" #106:140  hug    h:35  fill:#EAE4DD  text:#524534
  //              padding: 4px top / 16px sides / 4px bottom
  //
  // Chip font: Inter Medium 500 · 14px · letterSpacing:0.01em
  //            (style_25f6f1f5)
  // Chip radius: 9999px (pill)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return SizedBox(
      height: 62, // Figma exact — Section - Filter Chips Area height
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 24), // chips start at x:24
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _chip(label: 'All',        fixedW: null, inactiveFill: _kChipAmber,      padTop: 4.5, padBot: 5.09),
              const SizedBox(width: 4),  // Figma gap between chips: 4 px
              _chip(label: 'Pinned',     fixedW: null, inactiveFill: _kChipPinnedFill, padTop: 4.0, padBot: 4.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required double? fixedW,
    required Color  inactiveFill,
    required double padTop,
    required double padBot,
  }) {
    final isActive = _activeFilter == label;
    final fill     = isActive ? _kChipAmber : inactiveFill;
    final textCol  = isActive ? _kChipAmberTxt : _kChipInactiveTxt;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _activeFilter = label);
      },
      child: AnimatedContainer(
        duration:  kDurationFast,
        curve:     kCurveDefault,
        width:     fixedW,
        height:    35, // Figma exact chip height
        padding:   EdgeInsets.fromLTRB(16, padTop, 16, padBot), // Figma padding
        decoration: BoxDecoration(
          color:         fill,
          borderRadius:  BorderRadius.circular(9999), // Figma: pill radius
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(           // ← project font rule: Inter for labels
            fontSize:      14,               // Figma style_25f6f1f5
            fontWeight:    FontWeight.w500,  // Medium
            color:         textCol,
            letterSpacing: 0.01 * 14,       // 0.01em
            height:        1.0,             // tight so vertical centring is clean
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NOTE LIST
  //
  // Figma: Note List Scroll Area (#106:142)
  //   y:249.59  h:714.41  overflowScroll:x,y
  //   cards at x:24  w:342  gap between cards: 16 px
  //   staggered entrance: AnimatedListEntrance → fade + translateY 12→0, 40ms/card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNoteList(List<NoteSummary> notes, NotesProvider provider, ThemeData theme) {
    return ListView.builder(
      controller:  _scrollController,
      physics:     const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(
        left:   24,  // Figma x:24
        right:  24,
        top:    0,
        bottom: 120, // clearance for FAB
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
          padding: const EdgeInsets.only(bottom: 16.0), // Figma gap: 16px
          child: AnimatedListEntrance(
            key:   ValueKey('${note.id}_$_activeFilter'),
            index: i,
            child: Dismissible(
              key:       Key('fn_${note.id}'),
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
              child: _FigmaFolderCard(
                note:        note,
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

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final msg = switch (_activeFilter) {
      'Pinned'     => 'No pinned notes in this folder',
      'Checklists' => 'No checklists in this folder',
      _            => 'No notes in this folder yet',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined,
                size:  64,
                color: _kCardBodyColor.withValues(alpha: 0.18)),
            const SizedBox(height: 16),
            // Empty-state label — Inter Medium 16px (body label rule)
            Text(msg,
                style: GoogleFonts.inter(
                  fontSize:   16,
                  fontWeight: FontWeight.w500,
                  color:      _kCardBodyColor.withValues(alpha: 0.45),
                )),
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

    final allFolderNotes = provider.notesSummary
        .where((n) => n.folderId == widget.folder.id && !n.isDeleted)
        .toList();

    final displayed = switch (_activeFilter) {
      'Pinned'     => allFolderNotes.where((n) => n.isPinned).toList(),
      _            => allFolderNotes,
    };

    final scaffoldBg = isDark ? theme.scaffoldBackgroundColor : AppColors.background;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          try {
            Provider.of<NotesProvider>(context, listen: false).setSelectedFolder(null);
          } catch (_) {}
        }
      },
      child: Scaffold(
      backgroundColor: scaffoldBg,

      // ── FAB ───────────────────────────────────────────────────────────────
      // Figma: Bottom Bar at y:751 in 884px screen — FAB lives in the bottom bar SVG.
      // Since this is a detail screen (no bottom bar SVG), FAB is a standard
      // FloatingActionButton that hides/shows on scroll.
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
            backgroundColor: AppColors.amber, // Figma: FAB fill amber #F5A623
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
              buildPageRoute(NoteEditorScreen(defaultFolderId: widget.folder.id)),
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

            // ── HEADER ───────────────────────────────────────────────────────
            // Figma: Header frame #106:186  y:0  h:176  fill:#F9F6E5
            //        backdropFilter: blur(2px)
            //
            // Nav bar (SVG "Header Bar" at y:84, h:35):
            //   back arrow + search icon — inherited exactly from every other screen
            //
            // Folder name #107:281:  x:24 y:119
            //   Playfair Display Bold 700  36px  #333333  letterSpacing:0.0039em
            //
            // Note count #108:284:  x:24 y:154
            //   Inter Regular 400  16px  #828282  letterSpacing:0.0088em
            AnimatedBuilder(
              animation: _tintAnim,
              builder: (_, child) => Container(
                width:      double.infinity,
                decoration: BoxDecoration(color: _tintAnim.value),
                child:      child,
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 176, // Figma exact: header frame h:176
                  child: Stack(
                    children: [
                      // Nav bar row — exact same pattern as Home Screen / Note Editor
                      Positioned(
                        top: 12,
                        left: 24,
                        right: 24,
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
                                  presetFolder: widget.folder.id,
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

                      // Folder name — #107:281
                      // Playfair Display Bold 700 · 36px · #333333
                      Positioned(
                        left:  24,
                        top:   119, // Figma y:119 within header frame
                        right: 24,
                        child: Text(
                          widget.folder.name,
                          style: GoogleFonts.playfairDisplay( // ← Typography rule: Playfair for titles
                            fontSize:      36,
                            fontWeight:    FontWeight.w700,           // Bold
                            color:         isDark ? Colors.white : const Color(0xFF333333),
                            letterSpacing: 0.0039 * 36,              // Figma 0.0039em
                            height:        19.6 / 36,                // Figma lineHeight 19.6px
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Note count — #108:284
                      // Inter Regular 400 · 16px · #828282
                      Positioned(
                        left:  24,
                        top:   154, // Figma y:154 within header frame
                        child: Text(
                          '${allFolderNotes.length} ${allFolderNotes.length == 1 ? 'NOTE' : 'NOTES'}',
                          style: GoogleFonts.inter(            // ← Typography rule: Inter for labels
                            fontSize:      16,
                            fontWeight:    FontWeight.w400,   // Regular
                            color:         isDark ? Colors.white54 : _kSubtitleGrey,
                            letterSpacing: 0.0088 * 16,      // Figma 0.0088em
                            height:        19.6 / 16,        // Figma lineHeight 19.6px
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── FILTER CHIPS ─────────────────────────────────────────────────
            // Figma: Section - Filter Chips Area  y:177  h:62
            _buildFilterChips(),

            // ── GAP: chips bottom → first card top ───────────────────────────
            // Figma: Note List Scroll Area y:249.59
            // 249.59 - (177 + 62) = 10.59 px → reduced 75% → 3 px
            const SizedBox(height: 3),

            // ── NOTE CARDS ───────────────────────────────────────────────────
            // Cards: x:24  w:342  radius:20px  gap:16px
            Expanded(
              child: Opacity(
                opacity: _fadeProgress,
                child: IgnorePointer(
                  ignoring: _fadeProgress < 0.5,
                  child: displayed.isEmpty
                      ? _buildEmptyState()
                      : Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: _buildNoteList(displayed, provider, theme),
                          ),
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
// _FigmaFolderCard
//
// Self-contained note card whose layout exactly matches Figma
// "Article - Note Card" frames (#106:143, 155, 164, 173).
//
// FIGMA MEASUREMENTS
// ──────────────────
// Card dimensions   : w:342  h:147.39 (content-driven)
// Border radius     : 20 px
// Background        : note's pastel color
//
// Inner content frame "Heading 2" (EL-34309135):
//   x:17  y:16   w:308  layout:column  sizing:hug
//
// Title text (#106:145 etc.):
//   Playfair Display SemiBold 600 · 24px · fill #211A12
//   lineHeight: 31.2px   (style_2953e7cd)
//
// Body container "Container" (EL-178d0989):
//   x:17  y:52   w:308  layout:column  sizing:hug
//
// Body text (#106:147 etc.):
//   Inter Regular 400 · 16px · fill #524534 · lineHeight: 24px
//   (style_c04dd2db)
//
// Footer row (#106:148 etc.):
//   padding: 12px 0px 0px    justifyContent: space-between
//   left child : Container (#106:149) — row, gap:4px
//     ↳ category dot EL-f1395e12 : 8×8 · fill:#F5A623 · radius:∞
//   right child: Container (#106:153) — date text box  w:41.27 h:14.39
//
// TYPOGRAPHY (follows project rules):
//   Title : GoogleFonts.playfairDisplay  SemiBold 600  24px  #211A12
//   Body  : GoogleFonts.inter            Regular  400  16px  #524534  lH:24px
//   Date  : GoogleFonts.inter            Regular  400  12px  #524534@75%
// ─────────────────────────────────────────────────────────────────────────────

class _FigmaFolderCard extends StatefulWidget {
  final NoteSummary  note;
  final VoidCallback onTap;
  final VoidCallback onPinToggle;
  final VoidCallback onDelete;

  const _FigmaFolderCard({
    required this.note,
    required this.onTap,
    required this.onPinToggle,
    required this.onDelete,
  });

  @override
  State<_FigmaFolderCard> createState() => _FigmaFolderCardState();
}

class _FigmaFolderCardState extends State<_FigmaFolderCard>
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
    // Figma: footer date Container is w:41.27 h:14.39 — format accordingly
    final date = DateFormat('MMM d, h:mm a').format(widget.note.updatedAt);

    return GestureDetector(
      behavior:    HitTestBehavior.opaque,
      onTapDown:   (_) => _press.animateTo(1.0, duration: kDurationCardPress,   curve: kCurveExit),
      onTapUp:     (_) { _press.animateTo(0.0, duration: kDurationCardRelease, curve: kCurveEnter); widget.onTap(); },
      onTapCancel: ()  => _press.animateTo(0.0, duration: kDurationCardRelease, curve: kCurveEnter),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: _card(context, cardColor, date),
      ),
    );
  }

  Widget _card(BuildContext context, Color cardColor, String date) {
    // ── Card shell ──────────────────────────────────────────────────────────
    // Figma: borderRadius 20px, fill = note's pastel
    // Subtle white translucent border for glassmorphic depth (not explicit in
    // Figma but consistent with the project's light-mode card aesthetic)
    return AnimatedContainer(
      duration:    kDurationNormal,
      width:       double.infinity, // fills the 342px column
      decoration:  BoxDecoration(
        color:        cardColor,
        borderRadius: BorderRadius.circular(20), // Figma exact
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset:     const Offset(0, 3),
          ),
        ],
      ),

      // ── Inner padding ───────────────────────────────────────────────────
      // Figma: "Heading 2" frame at x:17, y:16 inside card
      // → left/right = 17px, top = 16px
      // bottom inferred from symmetric look = 16px
      child: Padding(
        padding: const EdgeInsets.only(left: 17, right: 17, top: 16, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:       MainAxisSize.min,
          children: [

            // ── TITLE (EL-34309135 / style_2953e7cd) ────────────────────────
            // Playfair Display SemiBold 600 · 24px · #211A12 · lH:31.2px
            // Typography rule: Playfair Display for card titles ✓
            Text(
              widget.note.isLocked
                  ? 'Locked Note'
                  : (widget.note.title.isNotEmpty ? widget.note.title : 'Untitled'),
              style: GoogleFonts.playfairDisplay(
                fontSize:      24,              // Figma style_2953e7cd fontSize:24
                fontWeight:    FontWeight.w600, // SemiBold
                color:         _kCardTitleColor,// #211A12
                height:        31.2 / 24,       // Figma lineHeight:31.2px
              ),
              maxLines:  2,
              overflow:  TextOverflow.ellipsis,
            ),

            // Gap between title frame bottom and body frame top:
            // Title frame: y:16, height ~31.2px → bottom at y≈47
            // Body frame (EL-178d0989): y:52 → gap = 52 - 47 = 5px ≈ 4px
            const SizedBox(height: 4),

            // ── BODY TEXT (EL-178d0989 / style_c04dd2db) ────────────────────
            // Inter Regular 400 · 16px · #524534 · lineHeight:24px
            // Typography rule: Inter for body text ✓
            Text(
              widget.note.isLocked
                  ? '••••••••••••••••••••'
                  : (widget.note.previewText.isNotEmpty
                      ? widget.note.previewText
                      : 'No additional text'),
              style: GoogleFonts.inter(
                fontSize:   16,              // Figma style_c04dd2db fontSize:16
                fontWeight: FontWeight.w400, // Regular
                color: widget.note.previewText.isNotEmpty
                    ? _kCardBodyColor        // #524534
                    : _kCardBodyColor.withValues(alpha: 0.5),
                height:     24 / 16,         // Figma lineHeight:24px
              ),
              maxLines:  2,
              overflow:  TextOverflow.ellipsis,
            ),

            // ── FOOTER ROW (#106:148) ─────────────────────────────────────────
            // Figma padding: "12px 0px 0px" = 12px top only
            // justifyContent: space-between
            // alignItems: center
            const SizedBox(height: 12), // Figma footer row padding-top: 12px

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // LEFT: Container #106:149  row  gap:4px
                //   ↳ category dot EL-f1395e12: 8×8 · fill:#F5A623 · radius:∞
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category dot — Figma EL-f1395e12
                    Container(
                      width:  8,  // Figma exact: 8px
                      height: 8,  // Figma exact: 8px
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kDotColor,  // #F5A623 fill_07144391
                      ),
                    ),
                    // Pin indicator (functional addition, minimal footprint)
                    if (widget.note.isPinned) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.push_pin,
                          size:  11,
                          color: _kCardBodyColor.withValues(alpha: 0.7)),
                    ],
                  ],
                ),

                // RIGHT: date container #106:153  w:41.27  h:14.39
                // Typography rule: Inter Regular for metadata ✓
                Text(
                  date,
                  style: GoogleFonts.inter(
                    fontSize:   12,             // fits Figma container h:14.39
                    fontWeight: FontWeight.w400, // Regular
                    color:      _kCardBodyColor.withValues(alpha: 0.75),
                    height:     14.39 / 12,     // matches Figma container h ratio
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
