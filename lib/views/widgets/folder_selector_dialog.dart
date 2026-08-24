import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/notes_provider.dart';
import '../../models/folder.dart';

class FolderSelectorDialog extends StatefulWidget {
  final String? currentFolderId;
  final ValueChanged<String?> onFolderSelected;

  const FolderSelectorDialog({
    super.key,
    required this.currentFolderId,
    required this.onFolderSelected,
  });

  @override
  State<FolderSelectorDialog> createState() => _FolderSelectorDialogState();
}

class _FolderSelectorDialogState extends State<FolderSelectorDialog> {
  final TextEditingController _folderNameController = TextEditingController();

  void _showCreateFolderDialog() {
    String? selectedParentId = widget.currentFolderId;
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final provider = Provider.of<NotesProvider>(context, listen: false);
        final hierarchical =
            FolderUtils.getHierarchicalFolders(provider.folders);

        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Text(
              "New Folder",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _folderNameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: "Folder Name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _folderNameController.clear();
                  Navigator.pop(context);
                },
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = _folderNameController.text.trim();
                  if (name.isNotEmpty) {
                    Provider.of<NotesProvider>(context, listen: false)
                        .createFolder(
                      name,
                      parentId: null,
                    );
                    _folderNameController.clear();
                    Navigator.pop(context);
                  }
                },
                child: const Text("Create"),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notesProvider = Provider.of<NotesProvider>(context);
    final folders = notesProvider.folders;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      backgroundColor: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Move Note to Folder",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.create_new_folder_outlined,
                      color: theme.colorScheme.primary),
                  onPressed: _showCreateFolderDialog,
                  tooltip: "Create New Folder",
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Root level folder option
                    ListTile(
                      leading: Icon(
                        Icons.home_outlined,
                        color: widget.currentFolderId == null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        "Root (No Folder)",
                        style: GoogleFonts.inter(
                          fontWeight: widget.currentFolderId == null
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: widget.currentFolderId == null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      trailing: widget.currentFolderId == null
                          ? Icon(Icons.check_circle_rounded,
                              color: theme.colorScheme.primary)
                          : null,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onTap: () {
                        widget.onFolderSelected(null);
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(),
                    if (folders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(
                          "No folders created yet",
                          style: GoogleFonts.inter(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      ...FolderUtils.getHierarchicalFolders(folders)
                          .map((item) {
                        final folder = item.folder;
                        final depth = item.depth;
                        final isSelected = folder.id == widget.currentFolderId;
                        return Padding(
                          padding: EdgeInsets.only(left: depth * 16.0),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              depth > 0
                                  ? Icons.subdirectory_arrow_right_rounded
                                  : Icons.folder_open_rounded,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            title: Text(
                              folder.name,
                              style: GoogleFonts.inter(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded,
                                    color: theme.colorScheme.primary)
                                : null,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onTap: () {
                              widget.onFolderSelected(folder.id);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
