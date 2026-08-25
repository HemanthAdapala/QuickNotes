import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/notes_provider.dart';
import '../../models/folder.dart';
import 'tactile_button.dart';

class FolderSelectionSheet extends StatefulWidget {
  final String? currentFolderId;
  final ValueChanged<String?> onFolderSelected;

  const FolderSelectionSheet({
    super.key,
    required this.currentFolderId,
    required this.onFolderSelected,
  });

  @override
  State<FolderSelectionSheet> createState() => _FolderSelectionSheetState();
}

class _FolderSelectionSheetState extends State<FolderSelectionSheet> {
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
            backgroundColor: const Color(0xFFF2F2EE),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              "New Folder",
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, color: Color(0xFF333333)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _folderNameController,
                  autofocus: true,
                  style: GoogleFonts.inter(color: Color(0xFF333333)),
                  decoration: InputDecoration(
                    labelText: "Folder Name",
                    labelStyle:
                        GoogleFonts.inter(color: const Color(0xFF8C8987)),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE6E3D2)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Color(0xFF222222), width: 1.5),
                    ),
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
                child: Text("Cancel",
                    style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C8987))),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF222222),
                  foregroundColor: const Color(0xFFF2F2EE),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: Text("Create",
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context);
    final folders = notesProvider.folders;
    final activeNotes = notesProvider.allActiveNotes;

    // Build the hierarchical folders list
    final List<FolderWithDepth> hierarchicalFolders =
        FolderUtils.getHierarchicalFolders(folders);

    // Get note counts
    int rootNoteCount =
        activeNotes.where((note) => note.folderId == null).length;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 402),
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2EE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 50,
            offset: Offset(0, -20),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header Row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Move to Folder",
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Choose where this note belongs",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: const Color(0xFF8C8987),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TactileButton(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEBE9D8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Folder List (Max Height constrained)
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  children: [
                    // Root Folder Item
                    _buildFolderItem(
                      id: null,
                      name: "Root (No Folder)",
                      depth: 0,
                      noteCount: rootNoteCount,
                      isSelected: widget.currentFolderId == null,
                    ),
                    const SizedBox(height: 8),
                    // Indented Hierarchical Folders
                    ...hierarchicalFolders.map((item) {
                      final folder = item.folder;
                      final depth = item.depth;
                      final noteCount = activeNotes
                          .where((note) => note.folderId == folder.id)
                          .length;
                      final isSelected = widget.currentFolderId == folder.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildFolderItem(
                          id: folder.id,
                          name: folder.name,
                          depth: depth,
                          noteCount: noteCount,
                          isSelected: isSelected,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Footer action
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color(0x1AD9D9D9),
                    width: 1.0,
                  ),
                ),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: TactileButton(
                onTap: _showCreateFolderDialog,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add,
                        size: 20,
                        color: Color(0xB3000000),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "New Folder",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xB3000000),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderItem({
    required String? id,
    required String name,
    required int depth,
    required int noteCount,
    required bool isSelected,
  }) {
    final paddingLeft = 16.0 + (depth * 16.0);

    return TactileButton(
      onTap: () {
        widget.onFolderSelected(id);
        // Delay pop slightly so the user sees selection state feedback
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(paddingLeft, 14, 16, 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF222222) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x26000000),
                    offset: Offset(0, 10),
                    blurRadius: 15,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.folder : Icons.folder_open_outlined,
              color: isSelected
                  ? const Color(0xFFF2F2EE)
                  : const Color(0xFF8C8987),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: isSelected ? const Color(0xFFF2F2EE) : Color(0xFF333333),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: Color(0xFFF2F2EE),
                size: 18,
              )
            else
              Text(
                "$noteCount",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8C8987).withOpacity(0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
