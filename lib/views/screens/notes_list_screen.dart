import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../providers/notes_provider.dart';
import '../../models/note.dart';
import 'note_editor_screen.dart';
import '../widgets/pin_lock_sheet.dart';
import '../widgets/note_card.dart';
import '../widgets/living_writing_experience.dart';


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
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _fabKey = GlobalKey();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<NotesProvider>(context, listen: false);
      provider.setViewType(widget.viewType);
      provider.loadNotes();
      provider.loadFolders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNoteCardTapped(BuildContext context, Note note, NotesProvider provider) {
    if (widget.viewType == NotesViewType.trash) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Restore Note?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: const Text("This note is in the Trash. You need to restore it to view or edit it."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                provider.restoreFromTrash(note.id);
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

    if (note.isLocked && !provider.isVaultUnlocked) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
        ),
        builder: (context) => PinLockSheet(
          onPinSubmitted: (pin) async {
            if (await provider.unlockVault(pin)) {
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NoteEditorScreen(note: note),
                  ),
                );
              }
            } else {
              if (context.mounted) {
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NoteEditorScreen(note: note),
        ),
      );
    }
  }

  String _getScreenTitle() {
    switch (widget.viewType) {
      case NotesViewType.feed:
        return "Gravity";
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

    final allNotes = provider.notes;
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
          if (widget.viewType == NotesViewType.trash)
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded),
              tooltip: "Empty Trash",
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text("Empty Trash?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    content: const Text("All notes in Trash will be permanently deleted. This action cannot be undone."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
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
        child: Column(
          children: [
            // Search Input Row if Active
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

            // Horizontal Category Pills (Only for main feed)
            if (widget.viewType == NotesViewType.feed)
              _buildCategoryPills(context, provider),

            // Main Notes list rows
            Expanded(
              child: allNotes.isEmpty
                  ? _buildEmptyState(context)
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (pinnedNotes.isNotEmpty) ...[
                                _buildSectionTitle("PINNED"),
                                const SizedBox(height: 8),
                                _buildNotesLayout(pinnedNotes, provider, isDesktop),
                                const SizedBox(height: 24),
                              ],
                              if (recentNotes.isNotEmpty) ...[
                                _buildSectionTitle(pinnedNotes.isNotEmpty ? "RECENT" : "ALL NOTES"),
                                const SizedBox(height: 8),
                                _buildNotesLayout(recentNotes, provider, isDesktop),
                              ],
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.viewType == NotesViewType.trash
          ? null
          : LivingFloatingActionButton(
              key: _fabKey,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit_note_rounded),
                          title: const Text("New Text Note"),
                          onTap: () {
                            Navigator.pop(context);
                            _navigateToCreateNote('text', provider);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.playlist_add_check_rounded),
                          title: const Text("New Checklist Note"),
                          onTap: () {
                            Navigator.pop(context);
                            _navigateToCreateNote('checklist', provider);
                          },
                        ),
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

  void _showSwipeOptionsSheet(BuildContext context, Note note, NotesProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
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
    );
  }

  // Builder to switch dynamically between grid (staggered) and list format
  Widget _buildNotesLayout(List<Note> notesList, NotesProvider provider, bool isDesktop) {
    Widget wrapWithDismissible(Note note) {
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
      return MasonryGridView.count(
        crossAxisCount: isDesktop ? 3 : 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: notesList.length,
        itemBuilder: (context, index) {
          final note = notesList[index];
          return wrapWithDismissible(note);
        },
      );
    } else {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: notesList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final note = notesList[index];
          return wrapWithDismissible(note);
        },
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
