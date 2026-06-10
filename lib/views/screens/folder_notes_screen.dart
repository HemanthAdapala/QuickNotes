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

  Widget _buildNotesLayout(List<Note> notesList, NotesProvider provider, bool isDesktop) {
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
          return NoteCard(
            note: note,
            onTap: () => _onNoteCardTapped(context, note, provider),
            onPinToggle: () => provider.togglePin(note.id),
            onFavoriteToggle: () => provider.toggleFavorite(note.id),
            onDelete: () => _trashNote(context, note, provider),
          );
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
          return NoteCard(
            note: note,
            onTap: () => _onNoteCardTapped(context, note, provider),
            onPinToggle: () => provider.togglePin(note.id),
            onFavoriteToggle: () => provider.toggleFavorite(note.id),
            onDelete: () => _trashNote(context, note, provider),
          );
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
