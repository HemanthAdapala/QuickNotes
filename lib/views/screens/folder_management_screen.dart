import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/notes_provider.dart';
import '../../models/folder.dart';
import '../../models/note.dart';
import 'note_editor_screen.dart';
import '../widgets/living_writing_experience.dart';
import 'folder_notes_screen.dart';


class FolderManagementScreen extends StatefulWidget {
  final VoidCallback onMenuTap;
  final ValueChanged<int>? onNavigateToTab;

  const FolderManagementScreen({
    super.key,
    required this.onMenuTap,
    this.onNavigateToTab,
  });

  @override
  State<FolderManagementScreen> createState() => _FolderManagementScreenState();
}

class _FolderManagementScreenState extends State<FolderManagementScreen> {
  final TextEditingController _folderController = TextEditingController();
  final Map<String, GlobalKey> _folderKeys = {};
  String? _tappedFolderId;

  GlobalKey _getKeyForFolder(String id) {
    return _folderKeys.putIfAbsent(id, () => GlobalKey());
  }

  void _handleFolderTap(Folder folder) async {
    if (_tappedFolderId != null) return;

    setState(() {
      _tappedFolderId = folder.id;
    });

    // Wait for the tap press-lift animation (150ms duration)
    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    // Retrieve bounds
    final key = _getKeyForFolder(folder.id);
    final RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
    Rect cardBounds = Rect.zero;
    if (box != null) {
      final position = box.localToGlobal(Offset.zero);
      cardBounds = Rect.fromLTWH(position.dx, position.dy, box.size.width, box.size.height);
    } else {
      // Fallback in case box is null
      final size = MediaQuery.of(context).size;
      cardBounds = Rect.fromLTWH(size.width / 4, size.height / 4, size.width / 2, size.height / 2);
    }

    // Reset tapped state after starting navigate so returning back doesn't show tapped state
    setState(() {
      _tappedFolderId = null;
    });

    // Navigate using custom FolderMorphPageRoute
    Navigator.of(context).push(
      FolderMorphPageRoute(
        cardBounds: cardBounds,
        builder: (context) => FolderNotesScreen(folder: folder),
      ),
    );
  }

  void _showCreateFolderDialog() {
    String? selectedParentId;
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final provider = Provider.of<NotesProvider>(context, listen: false);
        final hierarchical = FolderUtils.getHierarchicalFolders(provider.folders);

        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                    controller: _folderController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: "Folder Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedParentId,
                    decoration: const InputDecoration(
                      labelText: "Parent Folder (Optional)",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text("None (Root Folder)"),
                      ),
                      ...hierarchical.map((item) {
                        final folder = item.folder;
                        final depth = item.depth;
                        final indent = "  " * depth;
                        final prefix = depth > 0 ? "└─ " : "";
                        return DropdownMenuItem<String?>(
                          value: folder.id,
                          child: Text(
                            "$indent$prefix${folder.name}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedParentId = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _folderController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = _folderController.text.trim();
                    if (name.isNotEmpty) {
                      Provider.of<NotesProvider>(context, listen: false).createFolder(
                        name,
                        parentId: selectedParentId,
                      );
                      _folderController.clear();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Create"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _confirmDeleteFolder(Folder folder) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            "Delete Folder?",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to delete '${folder.name}'? Internal notes will be moved to the root level. They will NOT be deleted.",
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Provider.of<NotesProvider>(context, listen: false).deleteFolder(folder.id);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  String _getMockDescription(String folderName) {
    final nameLower = folderName.toLowerCase();
    if (nameLower.contains("journal") || nameLower.contains("diary")) {
      return "Reflections and morning pages.";
    } else if (nameLower.contains("research") || nameLower.contains("study")) {
      return "Interviews, transcripts, and methodology.";
    } else if (nameLower.contains("creative") || nameLower.contains("write") || nameLower.contains("novel")) {
      return "Short stories and novel drafts.";
    } else if (nameLower.contains("work") || nameLower.contains("job") || nameLower.contains("project")) {
      return "Client projects and synthesis sheets.";
    } else {
      return "Structured notes and documents.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<NotesProvider>(context);
    final folders = provider.folders;
    final orderedFolders = FolderUtils.getHierarchicalFolders(folders);

    final width = MediaQuery.of(context).size.width;
    final gridCols = width > 600 ? 2 : 1;

    // Fetch recently modified notes (sorted by update date desc)
    final recentNotes = provider.notes.take(5).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Folder management header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "WORKSPACE",
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF91918E),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Folders",
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              "Organize your thoughts into distinct intellectual containers.",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withAlpha(150),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _showCreateFolderDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.create_new_folder, size: 18),
                        label: Text(
                          "New Folder",
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFEBEBE8)),
                  const SizedBox(height: 24),

                  // Bento Grid
                  if (folders.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.folder_open_rounded,
                              size: 48,
                              color: theme.colorScheme.onSurface.withAlpha(50),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No Folders Created",
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withAlpha(120),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCols,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: orderedFolders.length,
                      itemBuilder: (context, index) {
                        final item = orderedFolders[index];
                        final folder = item.folder;
                        final depth = item.depth;
                        final noteCount = provider.notes.where((n) => n.folderId == folder.id).length;

                        return _buildFolderBentoCard(context, folder, noteCount, depth);
                      },
                    ),

                  // Recent Activity horizontal scroll
                  const SizedBox(height: 32),
                  Text(
                    "RECENTLY MODIFIED",
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF91918E),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (recentNotes.isEmpty)
                    Text(
                      "No modifications recorded.",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                    )
                  else
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: recentNotes.length,
                        itemBuilder: (context, index) {
                          final note = recentNotes[index];
                          return _buildRecentNoteCard(context, note);
                        },
                      ),
                    ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Folder bento card design (with parent nesting depth indicators)
  Widget _buildFolderBentoCard(BuildContext context, Folder folder, int noteCount, int depth) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Playful folder colors mapping
    final folderColors = [
      const Color(0xFFFFAAA6), // Coral
      const Color(0xFFFFD3B6), // Peach
      const Color(0xFFFFFFA6), // Lemon
      const Color(0xFFD4ECDD), // Sage
      const Color(0xFFA8DADC), // Sky
      const Color(0xFFD6C8FF), // Lavender
      const Color(0xFFFFC6FF), // Blush
    ];
    final folderColorsDark = [
      const Color(0xFF8C3232),
      const Color(0xFF965228),
      const Color(0xFF7D7D28),
      const Color(0xFF23443B),
      const Color(0xFF162E4A),
      const Color(0xFF4C2791),
      const Color(0xFF6A073D),
    ];

    final colorIdx = folder.name.hashCode.abs() % folderColors.length;
    final cardBg = isDark ? folderColorsDark[colorIdx] : folderColors[colorIdx];
    final strokeColor = isDark ? const Color(0xFFFAF8F5) : const Color(0xFF1E1B4B);

    final key = _getKeyForFolder(folder.id);
    final isTapped = _tappedFolderId == folder.id;

    return Padding(
      key: key,
      padding: const EdgeInsets.all(0),
      child: AnimatedScale(
        scale: isTapped ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: strokeColor,
              width: 1.5,
            ),
            boxShadow: [
              if (isTapped)
                BoxShadow(
                  color: strokeColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              else
                BoxShadow(
                  color: strokeColor,
                  blurRadius: 0,
                  offset: const Offset(3, 3),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleFolderTap(folder),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              depth > 0 ? Icons.folder_open_rounded : Icons.folder_rounded,
                              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                              size: 20,
                            ),
                            if (depth > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                "└─ Sub",
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withAlpha(150),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          "$noteCount items",
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      folder.name,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _getMockDescription(folder.name),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withAlpha(150),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: isDark ? Colors.white : theme.colorScheme.error,
                          onPressed: () => _confirmDeleteFolder(folder),
                          tooltip: "Delete Folder",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
}

  // Horizontal Card item for recently modified notes
  Widget _buildRecentNoteCard(BuildContext context, Note note) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final strokeColor = isDark ? const Color(0xFFFAF8F5) : const Color(0xFF1E1B4B);
    final timeStr = _getRelativeTimeString(note.updatedAt);
    final cardColor = NotesProvider.getNoteColor(note.colorValue, context);
    final textColor = NotesProvider.getNoteTextColor(note.colorValue, context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoteEditorScreen(note: note),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: strokeColor,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: strokeColor.withAlpha(50),
              blurRadius: 0,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_rounded, size: 18, color: textColor.withAlpha(200)),
            const SizedBox(height: 6),
            Text(
              note.title.isNotEmpty ? note.title : "Untitled",
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              timeStr,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRelativeTimeString(DateTime dt) {
    final difference = DateTime.now().difference(dt);
    if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else {
      return DateFormat('MMM d').format(dt);
    }
  }
}
