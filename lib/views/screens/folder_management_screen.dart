import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/notes_provider.dart';
import '../../models/folder.dart';
import '../widgets/tactile_button.dart';
import '../widgets/living_writing_experience.dart';
import 'folder_notes_screen.dart';

class FolderManagementScreen extends StatefulWidget {
  final VoidCallback onMenuTap;
  final ValueChanged<int>? onNavigateToTab;

  const FolderManagementScreen({
    super.key,
    required this.onMenuTap,
    required this.onNavigateToTab,
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
      cardBounds = Rect.fromLTWH(
          position.dx, position.dy, box.size.width, box.size.height);
    } else {
      final size = MediaQuery.of(context).size;
      cardBounds = Rect.fromLTWH(
          size.width / 4, size.height / 4, size.width / 2, size.height / 2);
    }

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
        final provider = Provider.of<NotesProvider>(context, listen: false);
        final hierarchical = FolderUtils.getHierarchicalFolders(provider.folders);

        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF9F6E5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              "New Folder",
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _folderController,
                  autofocus: true,
                  style: GoogleFonts.inter(color: const Color(0xFF1C1C1E)),
                  decoration: InputDecoration(
                    labelText: "Folder Name",
                    labelStyle: GoogleFonts.inter(color: const Color(0xFF8C8987)),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE6E3D2)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF1C1C1E), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: selectedParentId,
                  dropdownColor: const Color(0xFFF9F6E5),
                  style: GoogleFonts.inter(color: const Color(0xFF1C1C1E)),
                  decoration: InputDecoration(
                    labelText: "Parent Folder (Optional)",
                    labelStyle: GoogleFonts.inter(color: const Color(0xFF8C8987)),
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE6E3D2)),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE6E3D2)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                child: Text(
                  "Cancel",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8C8987),
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF222222),
                  foregroundColor: const Color(0xFFF9F6E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  "Create",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  void _confirmDeleteFolder(Folder folder) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: const Color(0xFFF9F6E5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            "Delete Folder?",
            style: GoogleFonts.playfairDisplay(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          content: Text(
            "Are you sure you want to delete '${folder.name}'? Internal notes will be moved to the root level. They will NOT be deleted.",
            style: GoogleFonts.inter(color: const Color(0xFF1C1C1E).withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.inter(
                  color: const Color(0xFF8C8987),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Provider.of<NotesProvider>(context, listen: false).deleteFolder(folder.id);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: Text(
                "Delete",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getMockDescription(String folderName) {
    final nameLower = folderName.toLowerCase();
    if (nameLower.contains("journal") || nameLower.contains("diary")) {
      return "Daily reflections and thoughts";
    } else if (nameLower.contains("study") || nameLower.contains("guide")) {
      return "Exam notes and reading lists";
    } else if (nameLower.contains("work") || nameLower.contains("task")) {
      return "Client calls & project updates";
    } else if (nameLower.contains("travel") || nameLower.contains("plan")) {
      return "Itineraries, tickets, packing";
    } else {
      return "Structured notes and documents";
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'ideas':
        return Icons.lightbulb_outline_rounded;
      case 'personal':
        return Icons.person_outline_rounded;
      case 'work':
        return Icons.assignment_outlined;
      case 'study':
        return Icons.book_outlined;
      case 'uncategorized':
      default:
        return Icons.tag_rounded;
    }
  }

  Color _getFolderCardBg(int index) {
    final colors = [
      const Color(0xFFFFBDE6), // Pink
      const Color(0xFFFFED94), // Yellow
      const Color(0xFFB9E9FF), // Blue
      const Color(0xFFC5FFB7), // Green
      const Color(0xFFEFE3B8), // Beige
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotesProvider>(context);
    final folders = provider.folders;
    final orderedFolders = FolderUtils.getHierarchicalFolders(folders);
    final activeNotes = provider.allActiveNotes;

    // Get categories dynamically
    final Set<String> allCategoriesSet = {
      ...NotesProvider.categories,
      ...activeNotes.map((n) => n.category),
    };
    final categoriesList = allCategoriesSet.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6E5),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 24.0, bottom: 120.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Bar
              Container(
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 30),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 0,
                      child: TactileButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onNavigateToTab?.call(0);
                        },
                        child: SizedBox(
                          width: 38,
                          height: 38,
                          child: SvgPicture.asset(
                            'assets/icons/angle_left.svg',
                            colorFilter: const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
                            fit: BoxFit.scaleDown,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      "My Notes",
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: TactileButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onNavigateToTab?.call(0);
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: Color(0xFF222222),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Your Categories Carousel Title
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(
                  "Your Categories",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Categories Carousel
              SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  itemCount: categoriesList.length,
                  itemBuilder: (context, index) {
                    final category = categoriesList[index];
                    final noteCount = activeNotes.where((n) => n.category == category).length;
                    final icon = _getCategoryIcon(category);

                    return Padding(
                      padding: const EdgeInsets.only(right: 15.0),
                      child: TactileButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          provider.setSelectedCategory(category);
                          provider.setSelectedTag("");
                          widget.onNavigateToTab?.call(0);
                        },
                        child: Container(
                          width: 100,
                          height: 150,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFE3B8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              Positioned(
                                top: 20,
                                child: Icon(
                                  icon,
                                  size: 26,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                              Positioned(
                                top: 68,
                                left: 4,
                                right: 4,
                                child: Text(
                                  category,
                                  style: GoogleFonts.inter(
                                    fontSize: category.length > 10 ? 15 : 17,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF1C1C1E),
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Positioned(
                                top: 110,
                                child: Text(
                                  "$noteCount notes",
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF1C1C1E).withOpacity(0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Section Header Background full width
              Container(
                height: 51,
                width: double.infinity,
                color: const Color(0xFFEFE3B8).withOpacity(0.6),
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "My Folders",
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1C1C1E),
                        height: 1.0,
                      ),
                    ),
                    TactileButton(
                      onTap: _showCreateFolderDialog,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "+",
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "New Folder",
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Folders List Area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: orderedFolders.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.folder_open_rounded,
                                size: 48,
                                color: const Color(0xFF1C1C1E).withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No Folders Created",
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1C1C1E).withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: List.generate(orderedFolders.length, (index) {
                          final item = orderedFolders[index];
                          final folder = item.folder;
                          final depth = item.depth;
                          final noteCount = activeNotes.where((n) => n.folderId == folder.id).length;
                          final bg = _getFolderCardBg(index);
                          final key = _getKeyForFolder(folder.id);
                          final isTapped = _tappedFolderId == folder.id;

                          return Padding(
                            key: key,
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: TactileButton(
                              onTap: () => _handleFolderTap(folder),
                              child: GestureDetector(
                                onLongPress: () {
                                  HapticFeedback.mediumImpact();
                                  _confirmDeleteFolder(folder);
                                },
                                child: AnimatedScale(
                                  scale: isTapped ? 1.02 : 1.0,
                                  duration: const Duration(milliseconds: 150),
                                  curve: Curves.easeOutCubic,
                                  child: Container(
                                    width: double.infinity,
                                    height: 74,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Icon(
                                                depth > 0 ? Icons.folder_open_outlined : Icons.folder_outlined,
                                                size: 24,
                                                color: const Color(0xFF1C1C1E),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      folder.name,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w600,
                                                        color: const Color(0xFF1C1C1E),
                                                        height: 1.25,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      _getMockDescription(folder.name),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w400,
                                                        color: const Color(0xFF1C1C1E).withOpacity(0.8),
                                                        height: 1.3,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          "$noteCount",
                                          style: GoogleFonts.inter(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF1C1C1E),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
