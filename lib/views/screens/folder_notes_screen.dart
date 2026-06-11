import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../providers/notes_provider.dart';
import '../../models/note.dart';
import '../../models/folder.dart';
import 'note_editor_screen.dart';
import '../widgets/pin_lock_sheet.dart';
import '../widgets/note_card.dart';

class FolderNotesScreen extends StatefulWidget {
  final Folder folder;

  const FolderNotesScreen({
    super.key,
    required this.folder,
  });

  @override
  State<FolderNotesScreen> createState() => _FolderNotesScreenState();
}

class _FolderNotesScreenState extends State<FolderNotesScreen> {
  bool _isGridView = true;
  double _fadeProgress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route != null) {
        route.animation?.addListener(_onRouteAnimUpdate);
        route.animation?.addStatusListener(_onRouteStatusUpdate);
      } else {
        setState(() {
          _fadeProgress = 1.0;
        });
      }
    });
  }

  void _onRouteAnimUpdate() {
    final route = ModalRoute.of(context);
    if (route != null && route.animation != null) {
      final val = route.animation!.value;
      if (mounted) {
        setState(() {
          // Fade in ONLY near the end of the transition (0.75 -> 1.0)
          if (val >= 0.75) {
            _fadeProgress = ((val - 0.75) / 0.25).clamp(0.0, 1.0);
          } else {
            _fadeProgress = 0.0;
          }
        });
      }
    }
  }

  void _onRouteStatusUpdate(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (mounted) {
        setState(() {
          _fadeProgress = 1.0;
        });
      }
    }
  }

  @override
  void dispose() {
    final route = ModalRoute.of(context);
    route?.animation?.removeListener(_onRouteAnimUpdate);
    route?.animation?.removeStatusListener(_onRouteStatusUpdate);
    super.dispose();
  }

  void _onNoteCardTapped(BuildContext context, Note note, NotesProvider provider) {
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NoteEditorScreen(note: note),
        ),
      );
    }
  }

  void _trashNote(BuildContext context, Note note, NotesProvider provider) {
    provider.trashNote(note.id);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Note moved to Recycle Bin"),
        action: SnackBarAction(
          label: "UNDO",
          onPressed: () => provider.restoreFromTrash(note.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<NotesProvider>(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    // Filter notes for this specific folder
    final folderNotes = provider.notes.where((note) => note.folderId == widget.folder.id).toList();
    final pinnedNotes = folderNotes.where((note) => note.isPinned).toList();
    final recentNotes = folderNotes.where((note) => !note.isPinned).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textTheme.titleLarge?.color),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Opacity(
          opacity: _fadeProgress,
          child: Text(
            widget.folder.name,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        actions: [
          Opacity(
            opacity: _fadeProgress,
            child: IgnorePointer(
              ignoring: _fadeProgress < 0.5,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
                    tooltip: _isGridView ? "List View" : "Grid View",
                    onPressed: () {
                      setState(() {
                        _isGridView = !_isGridView;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Opacity(
          opacity: _fadeProgress,
          child: IgnorePointer(
            ignoring: _fadeProgress < 0.5,
            child: folderNotes.isEmpty
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
    );
  }

  Widget _buildNotesLayout(List<Note> notesList, NotesProvider provider, bool isDesktop) {
    Widget wrapWithDismissible(Note note) {
      return Dismissible(
        key: Key('folder_note_dismissible_${note.id}'),
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
          onDelete: () => _trashNote(context, note, provider),
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

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withAlpha(50),
            ),
            const SizedBox(height: 16),
            Text(
              "No Notes Found in Folder",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
