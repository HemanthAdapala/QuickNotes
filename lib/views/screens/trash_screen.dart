import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/quick_notes_theme.dart';
import '../../providers/notes_provider.dart';
import '../../models/note.dart';
import '../widgets/empty_state.dart';

class TrashScreen extends StatelessWidget {
  final VoidCallback onMenuTap;

  const TrashScreen({
    super.key,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: QuickNotesTheme.background,
      appBar: AppBar(
        backgroundColor: QuickNotesTheme.background,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: onMenuTap,
        ),
        title: Text(
          "Recycle Bin",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Consumer<NotesProvider>(
            builder: (context, provider, child) {
              final trashNotes = provider.trashNotes; // Double check
              if (trashNotes.isEmpty) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () => _confirmEmptyTrash(context, provider, trashNotes),
                icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.red),
                label: const Text(
                  "EMPTY",
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotesProvider>(
        builder: (context, provider, child) {
          // Wait, the notes list is filtered inside the provider based on currentView.
          // Since we might be inside TrashScreen but the provider's active view isn't trash,
          // let's fetch all notes directly from the provider and filter isTrash manually!
          // This is extremely safe and doesn't require modifying active shell state.
          final trashNotes = provider.trashNotes;
          
          if (trashNotes.isEmpty) {
            return const Center(
              child: EmptyState(
                title: "Trash is Empty",
                subtitle: "Notes you delete will appear here before being permanently purged.",
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trashNotes.length,
            itemBuilder: (context, index) {
              final note = trashNotes[index];
              return _buildTrashCard(context, provider, note);
            },
          );
        },
      ),
    );
  }

  Widget _buildTrashCard(BuildContext context, NotesProvider provider, Note note) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: QuickNotesTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QuickNotesTheme.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          note.title.isNotEmpty ? note.title : "Untitled Note",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: QuickNotesTheme.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            note.noteType == 'checklist' ? "Checklist items" : note.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: QuickNotesTheme.textSecondary,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Restore action
            IconButton(
              icon: const Icon(Icons.restore_from_trash_rounded, color: QuickNotesTheme.accent),
              onPressed: () {
                provider.restoreNoteFromTrash(note.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Note restored")),
                );
              },
            ),
            // Permanent Delete action
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              onPressed: () => _confirmDeletePermanently(context, provider, note.id),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePermanently(BuildContext context, NotesProvider provider, String noteId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: QuickNotesTheme.surface,
        title: const Text("Delete Permanently?"),
        content: const Text("This action cannot be undone. The note will be permanently lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: QuickNotesTheme.textPrimary)),
          ),
          TextButton(
            onPressed: () {
              provider.deleteNote(noteId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Note permanently deleted")),
              );
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmEmptyTrash(BuildContext context, NotesProvider provider, List<Note> notes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: QuickNotesTheme.surface,
        title: const Text("Empty Recycle Bin?"),
        content: Text("Are you sure you want to permanently delete all ${notes.length} notes in the trash?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: QuickNotesTheme.textPrimary)),
          ),
          TextButton(
            onPressed: () {
              for (var note in notes) {
                provider.deleteNote(note.id);
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Recycle bin emptied")),
              );
            },
            child: const Text("EMPTY ALL", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
