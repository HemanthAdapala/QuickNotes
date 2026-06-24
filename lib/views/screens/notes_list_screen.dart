import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../providers/notes_provider.dart';
import '../../models/note_summary.dart';
import 'note_editor_screen.dart';
import '../widgets/pin_lock_sheet.dart';
import '../widgets/note_card.dart';
import '../widgets/living_writing_experience.dart';
import 'package:flutter/rendering.dart';
import '../../core/animations/page_transitions.dart';
import '../../core/animations/dialog_transition.dart';
import '../../core/animations/bottom_sheet_transition.dart';
import '../../core/animations/animated_list_entrance.dart';
import '../../core/animations/animation_constants.dart';


class NotesListScreen extends StatefulWidget {
  final NotesViewType viewType;
  final VoidCallback onMenuTap;
  final ValueChanged<int>? onNavigateToTab;

  const NotesListScreen({
    super.key,
    required this.viewType,
    required this.onMenuTap,
    this.onNavigateToTab,
  });

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  bool _isSearchActive = false;
  bool _isGridView = true; // Default layout to show off colorful cards
  bool _isFabVisible = true;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _fabKey = GlobalKey();
  late ScrollController _scrollController;

  void _navigateToCreateNote(String type, NotesProvider provider) {
    final RenderBox? box = _fabKey.currentContext?.findRenderObject() as RenderBox?;
    Rect fabBounds = Rect.zero;
    if (box != null) {
      final position = box.localToGlobal(Offset.zero);
      fabBounds = Rect.fromLTWH(position.dx, position.dy, box.size.width, box.size.height);
    } else {
      final size = MediaQuery.of(context).size;
      fabBounds = Rect.fromLTWH(size.width - 80, size.height - 80, 56, 56);
    }

    Navigator.push(
      context,
      FabMorphPageRoute(
        fabBounds: fabBounds,
        builder: (context) => NoteEditorScreen(
          defaultCategory: provider.selectedCategory != "All"
              ? provider.selectedCategory
              : "Uncategorized",
          defaultNoteType: type,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<NotesProvider>(context, listen: false);
      provider.setViewType(widget.viewType);
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

  @override
  void didUpdateWidget(covariant NotesListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewType != widget.viewType) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final provider = Provider.of<NotesProvider>(context, listen: false);
          provider.setViewType(widget.viewType);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onNoteCardTapped(BuildContext context, NoteSummary note, NotesProvider provider) async {
    if (widget.viewType == NotesViewType.trash) {
      showAnimatedDialog(
        context: context,
        child: AlertDialog(
          title: Text("Restore Note?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: const Text("This note is in the Trash. You need to restore it to view or edit it."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                provider.restoreFromTrash(note.id);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Note restored")),
                );
              },
              child: const Text("Restore"),
            ),
          ],
        ),
      );
      return;
    }

    final fullNote = await provider.getNoteById(note.id);
    if (fullNote == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load note details")),
        );
      }
      return;
    }

    if (fullNote.isLocked && !provider.isVaultUnlocked) {
      showAnimatedBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
        ),
        child: PinLockSheet(
          onPinSubmitted: (pin) async {
            if (await provider.unlockVault(pin)) {
              final decryptedNote = await provider.getNoteById(note.id);
              if (context.mounted && decryptedNote != null) {
                Navigator.push(
                  context,
                  buildPageRoute(NoteEditorScreen(note: decryptedNote)),
                );
              }
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Incorrect PIN Code! Access Denied."),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      );
    } else {
      if (context.mounted) {
        Navigator.push(
          context,
          buildPageRoute(NoteEditorScreen(note: fullNote)),
        );
      }
    }
  }

  String _getScreenTitle() {
    switch (widget.viewType) {
      case NotesViewType.feed:
        return "QuickNotes";
      case NotesViewType.favorites:
        return "Favorites";
      case NotesViewType.archive:
        return "Archive";
      case NotesViewType.trash:
        return "Trash";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<NotesProvider>(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    final allNotes = provider.notesSummary;
    final pinnedNotes = allNotes.where((note) => note.isPinned).toList();
    final recentNotes = allNotes.where((note) => !note.isPinned).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: isDesktop
            ? null
            : IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: widget.onMenuTap,
              ),
        title: Text(
          _getScreenTitle(),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded),
            tooltip: "Empty Trash",
            onPressed: () {
              showAnimatedDialog(
                context: context,
                child: AlertDialog(
                  title: Text("Empty Trash?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  content: const Text("All notes in Trash will be permanently deleted. This action cannot be undone."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        provider.emptyTrash();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      ),
                      child: const Text("Empty Trash"),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            tooltip: _isGridView ? "List View" : "Grid View",
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          IconButton(
            icon: Icon(_isSearchActive ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchActive = !_isSearchActive;
                if (!_isSearchActive) {
                  _searchController.clear();
                  provider.setSearchQuery("");
                }
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is UserScrollNotification) {
              if (notification.direction == ScrollDirection.reverse) {
                if (_isFabVisible) {
                  setState(() {
                    _isFabVisible = false;
                  });
                }
              } else if (notification.direction == ScrollDirection.forward) {
                if (!_isFabVisible) {
                  setState(() {
                    _isFabVisible = true;
                  });
                }
              }
            }
            return false;
          },
          child: Column(
            children: [
              if (_isSearchActive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Search notes, tags, or contents...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        filled: true,
                        fillColor: theme.cardColor,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (val) {
                        provider.setSearchQuery(val);
                      },
                    ),
                  ),
                ),
  
              if (widget.viewType == NotesViewType.feed)
                _buildCategoryPills(context, provider),
  
              Expanded(
                child: provider.isLoading && allNotes.isEmpty
                    ? CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            sliver: SliverToBoxAdapter(
                              child: _buildSectionTitle("LOADING NOTES..."),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            sliver: _buildSliverSkeletonLayout(context, isDesktop),
                          ),
                        ],
                      )
                    : allNotes.isEmpty
                        ? CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: _buildEmptyState(context),
                              ),
                            ],
                          )
                        : CustomScrollView(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              if (pinnedNotes.isNotEmpty) ...[
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  sliver: SliverToBoxAdapter(
                                    child: _buildSectionTitle("PINNED"),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  sliver: _buildSliverNotesLayout(pinnedNotes, provider, isDesktop),
                                ),
                              ],
                              if (recentNotes.isNotEmpty) ...[
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  sliver: SliverToBoxAdapter(
                                    child: _buildSectionTitle(pinnedNotes.isNotEmpty ? "RECENT" : "ALL NOTES"),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  sliver: _buildSliverNotesLayout(recentNotes, provider, isDesktop),
                                ),
                              ],
                              if (provider.isPageLoading)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24.0),
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
                                  ),
                                ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 100),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: widget.viewType == NotesViewType.trash
          ? null
          : AnimatedScale(
              scale: _isFabVisible ? 1.0 : 0.0,
              duration: kDurationFast,
              curve: _isFabVisible ? kCurveEnter : kCurveExit,
              child: AnimatedOpacity(
                opacity: _isFabVisible ? 1.0 : 0.0,
                duration: kDurationFast,
                curve: _isFabVisible ? kCurveEnter : kCurveExit,
                child: LivingFloatingActionButton(
                  key: _fabKey,
                  onPressed: () {
                    showAnimatedBottomSheet(
                      context: context,
                      backgroundColor: theme.scaffoldBackgroundColor,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: theme.dividerColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                "Create New",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Quick Note (Prioritized Default Action)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 6.0),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  _navigateToCreateNote('text', provider);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: theme.brightness == Brightness.dark 
                                          ? const Color(0xFFFAF8F5) 
                                          : const Color(0xFF1E1B4B),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_note_rounded,
                                        color: theme.colorScheme.onPrimary,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Quick Note",
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: theme.colorScheme.onPrimary,
                                              ),
                                            ),
                                            Text(
                                              "Jot down your thoughts instantly",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                color: theme.colorScheme.onPrimary.withOpacity(0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Checklist (Secondary Action)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 6.0),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  _navigateToCreateNote('checklist', provider);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: theme.brightness == Brightness.dark 
                                          ? const Color(0xFFFAF8F5).withOpacity(0.3) 
                                          : const Color(0xFF1E1B4B).withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.playlist_add_check_rounded,
                                        color: theme.colorScheme.primary,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Checklist",
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            Text(
                                              "Track tasks, habits, and to-dos",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    );
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.brightness == Brightness.dark ? const Color(0xFFFAF8F5) : const Color(0xFF1E1B4B),
                      width: 1.5,
                    ),
                  ),
                  elevation: 4,
                  child: const Icon(Icons.add),
                ),
              ),
            ),
    );
  }

  Widget _buildSwipeBackground(bool isLeftSwipe, Color baseCardColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final strokeColor = isDark ? const Color(0xFFFAF8F5) : const Color(0xFF1E1B4B);

    return Container(
      decoration: BoxDecoration(
        color: isLeftSwipe 
            ? theme.colorScheme.primaryContainer.withAlpha(80) 
            : theme.colorScheme.secondaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: strokeColor, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      alignment: isLeftSwipe ? Alignment.centerRight : Alignment.centerLeft,
      child: Icon(
        isLeftSwipe ? Icons.more_horiz_rounded : Icons.push_pin_rounded,
        color: theme.colorScheme.onSurface,
        size: 28,
      ),
    );
  }

  void _showSwipeOptionsSheet(BuildContext context, NoteSummary note, NotesProvider provider) {
    showAnimatedBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                  child: Text(
                    note.title.isNotEmpty ? note.title : "Untitled Note",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(note.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber),
                  title: Text(note.isFavorite ? "Remove from Favorites" : "Add to Favorites"),
                  onTap: () {
                    Navigator.pop(context);
                    provider.toggleFavorite(note.id);
                  },
                ),
                ListTile(
                  leading: Icon(note.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, color: theme.colorScheme.primary),
                  title: Text(note.isArchived ? "Unarchive Note" : "Archive Note"),
                  onTap: () {
                    Navigator.pop(context);
                    provider.toggleArchive(note.id);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(note.isArchived ? "Note unarchived" : "Note archived"),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text("Delete (Move to Trash)"),
                  onTap: () {
                    Navigator.pop(context);
                    provider.trashNote(note.id);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Note moved to Trash"),
                        action: SnackBarAction(
                          label: "UNDO",
                          onPressed: () => provider.restoreFromTrash(note.id),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliverNotesLayout(List<NoteSummary> notesList, NotesProvider provider, bool isDesktop) {
    Widget wrapWithDismissible(NoteSummary note) {
      if (widget.viewType == NotesViewType.trash) {
        return NoteCard(
          note: note,
          onTap: () => _onNoteCardTapped(context, note, provider),
          onPinToggle: () => provider.togglePin(note.id),
          onFavoriteToggle: () => provider.toggleFavorite(note.id),
          onDelete: () => provider.deleteNote(note.id),
        );
      }
      return Dismissible(
        key: Key('note_dismissible_${note.id}'),
        direction: DismissDirection.horizontal,
        background: _buildSwipeBackground(false, NotesProvider.getNoteColor(note.colorValue, context)),
        secondaryBackground: _buildSwipeBackground(true, NotesProvider.getNoteColor(note.colorValue, context)),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            provider.togglePin(note.id);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(note.isPinned ? "Note unpinned" : "Note pinned"),
                duration: const Duration(seconds: 1),
              ),
            );
            return false;
          } else {
            _showSwipeOptionsSheet(context, note, provider);
            return false;
          }
        },
        child: NoteCard(
          note: note,
          onTap: () => _onNoteCardTapped(context, note, provider),
          onPinToggle: () => provider.togglePin(note.id),
          onFavoriteToggle: () => provider.toggleFavorite(note.id),
          onDelete: () {
            provider.trashNote(note.id);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Note moved to Trash"),
                action: SnackBarAction(
                  label: "UNDO",
                  onPressed: () => provider.restoreFromTrash(note.id),
                ),
              ),
            );
          },
        ),
      );
    }

    if (_isGridView) {
      return SliverMasonryGrid.count(
        crossAxisCount: isDesktop ? 3 : 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childCount: notesList.length,
        itemBuilder: (context, index) {
          final note = notesList[index];
          return AnimatedListEntrance(
            index: index,
            child: wrapWithDismissible(note),
          );
        },
      );
    } else {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final itemIndex = index ~/ 2;
            if (index.isEven) {
              final note = notesList[itemIndex];
              return AnimatedListEntrance(
                index: itemIndex,
                child: wrapWithDismissible(note),
              );
            }
            return const SizedBox(height: 16);
          },
          childCount: notesList.isEmpty ? 0 : notesList.length * 2 - 1,
        ),
      );
    }
  }

  Widget _buildSliverSkeletonLayout(BuildContext context, bool isDesktop) {
    final count = isDesktop ? 6 : 4;
    
    if (_isGridView) {
      return SliverMasonryGrid.count(
        crossAxisCount: isDesktop ? 3 : 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childCount: count,
        itemBuilder: (context, index) {
          return _buildSkeletonCard(context, index);
        },
      );
    } else {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final itemIndex = index ~/ 2;
            if (index.isEven) {
              return _buildSkeletonCard(context, itemIndex);
            }
            return const SizedBox(height: 16);
          },
          childCount: count * 2 - 1,
        ),
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isDark ? const Color(0xFFC7C6CA) : const Color(0xFF1E1B4B),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSkeletonCard(BuildContext context, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Shimmer colors matching the app's aesthetics
    final baseColor = isDark 
        ? const Color(0xFF1E1C2E).withOpacity(0.5) 
        : const Color(0xFFE2E8F0);
    final highlightColor = isDark 
        ? const Color(0xFF312E81).withOpacity(0.3) 
        : const Color(0xFFFFFDF9);

    // Stagger content lines to mock staggered grid card heights
    final contentLines = 2 + (index % 3);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.4),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Skeleton Header Accent Strip (simulating premium card color cover)
            if (index % 2 == 1) ...[
              Container(
                height: 45,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Skeleton Title
            Container(
              width: 100 + (index % 4) * 20.0,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            // Skeleton Content lines
            for (int i = 0; i < contentLines; i++) ...[
              Container(
                width: i == contentLines - 1 ? 120.0 + (index % 2) * 40.0 : double.infinity,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            // Skeleton Badges / Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (index % 2 == 0)
                      Container(
                        width: 40,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Centered empty state
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isTrash = widget.viewType == NotesViewType.trash;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isTrash ? Icons.delete_outline_rounded : Icons.description_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withAlpha(50),
            ),
            const SizedBox(height: 16),
            Text(
              isTrash ? "Trash is Empty" : "No Notes Found",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isTrash ? "Notes you delete will appear here." : "Your next great idea starts here.",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Playful Category Choice Chips
  Widget _buildCategoryPills(BuildContext context, NotesProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allCategories = ["All", ...NotesProvider.categories];
    final strokeColor = isDark ? const Color(0xFFFAF8F5) : const Color(0xFF1E1B4B);

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: allCategories.length,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final cat = allCategories[index];
          final isSelected = provider.selectedCategory == cat && provider.selectedTag.isEmpty;

          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected 
                    ? (isDark ? const Color(0xFF0B0D17) : Colors.white)
                    : theme.colorScheme.onSurface.withAlpha(180),
              ),
              selectedColor: theme.colorScheme.primary,
              checkmarkColor: isDark ? const Color(0xFF0B0D17) : Colors.white,
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? theme.colorScheme.primary : strokeColor,
                  width: 1.5,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  provider.setSelectedTag("");
                  provider.setSelectedCategory(cat);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
