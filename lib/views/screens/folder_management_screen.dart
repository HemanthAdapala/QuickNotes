import 'dart:math' show pi;
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
import '../../core/animations/animation_constants.dart';
import '../../core/animations/tactile_card_wrapper.dart';
import '../../core/animations/dialog_transition.dart';
import '../../core/animations/animated_list_entrance.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/blurred_bottom_sheet.dart';
import '../widgets/folder_card.dart';
import '../widgets/primary_screen_surface.dart';
import '../../themes/app_theme.dart';
import '../../core/animations/page_transitions.dart';
import 'search_screen.dart';
import '../../core/animations/search_transition_routes.dart';
import '../../premium/premium.dart';

class FolderManagementScreen extends StatefulWidget {
  final VoidCallback onMenuTap;
  final ValueChanged<int>? onNavigateToTab;

  const FolderManagementScreen({
    super.key,
    required this.onMenuTap,
    required this.onNavigateToTab,
  });

  @override
  State<FolderManagementScreen> createState() => FolderManagementScreenState();
}

class FolderManagementScreenState extends State<FolderManagementScreen> {
  final TextEditingController _folderController = TextEditingController();
  final Map<String, GlobalKey> _folderKeys = {};
  String? _tappedFolderId;

  // Bottom Control States
  bool _isGridView = true;
  bool _isSearchExpanded = false;
  String _searchQuery = "";

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

  void showCreateFolderDialog() {
    String? selectedParentId;
    _folderController.clear();
    showAnimatedDialog(
      context: context,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          final provider = Provider.of<NotesProvider>(context, listen: false);
          final hierarchical =
              FolderUtils.getHierarchicalFolders(provider.folders);

          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return AnimatedPadding(
            padding: EdgeInsets.only(
              bottom: bottomInset > 0 ? bottomInset + 16.0 : 0.0,
            ),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 280.0,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFDFD),
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3F000000),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.only(top: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "New Folder",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D1D1D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Enter a name for this folder",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF8E8E93),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEFF4),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _folderController,
                                autofocus: true,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: const Color(0xFF1C1C1E),
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 10.0),
                                  hintText: "Folder Name",
                                  hintStyle: GoogleFonts.inter(
                                      color: const Color(0xFFAEAEB2)),
                                ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                            if (_folderController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setDialogState(() {
                                    _folderController.clear();
                                  });
                                },
                                child: const Icon(
                                  Icons.cancel,
                                  size: 18,
                                  color: Color(0xFFC7C7CC),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFD1D1D6)),
                    Row(
                      children: [
                        Expanded(
                          child: TactileButton(
                            onTap: () {
                              _folderController.clear();
                              Navigator.pop(context);
                            },
                            child: Container(
                              height: 44.0,
                              alignment: Alignment.center,
                              child: Text(
                                "cancel",
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: const Color(0xFF8E8E93),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1.0,
                          height: 44.0,
                          color: const Color(0xFFD1D1D6),
                        ),
                        Expanded(
                          child: TactileButton(
                            onTap: () {
                              final name = _folderController.text.trim();
                              if (name.isNotEmpty) {
                                Provider.of<NotesProvider>(context,
                                        listen: false)
                                    .createFolder(
                                  name,
                                  parentId: null,
                                );
                                _folderController.clear();
                                Navigator.pop(context);
                              }
                            },
                            child: Container(
                              height: 44.0,
                              alignment: Alignment.center,
                              child: Text(
                                "save",
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: const Color(0xFFFFCC00),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteFolder(Folder folder) {
    final screenContext = context;
    showAnimatedDialog(
      context: context,
      child: Builder(
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              "Delete Folder?",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            content: Text(
              "Are you sure you want to delete '${folder.name}'? Internal notes will be moved to the root level. They will NOT be deleted.",
              style: GoogleFonts.inter(
                  color: const Color(0xFF1C1C1E).withValues(alpha: 0.8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8C8987),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  final success = await Provider.of<NotesProvider>(
                          screenContext,
                          listen: false)
                      .deleteFolder(folder.id);
                  if (screenContext.mounted) {
                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? "Folder '${folder.name}' deleted successfully"
                            : "Failed to delete folder: Database error"),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error),
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
      ),
    );
  }

  void _showFolderContextMenu(
      BuildContext context, Folder folder, Offset position) async {
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    final RelativeRect positionRect = RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 40, 40),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<String>(
      context: context,
      position: positionRect,
      color: const Color(0xFFF2F2EE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'customize',
          child: Row(
            children: [
              const Icon(Icons.color_lens_outlined,
                  color: Color(0xFF1C1C1E), size: 20),
              const SizedBox(width: 10),
              Text(
                "Customize",
                style: GoogleFonts.inter(color: const Color(0xFF1C1C1E)),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 20),
              const SizedBox(width: 10),
              Text(
                "Delete",
                style: GoogleFonts.inter(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );

    if (result == 'customize') {
      _showCustomizationBottomSheet(folder);
    } else if (result == 'delete') {
      _confirmDeleteFolder(folder);
    }
  }

  void _showCustomizationBottomSheet(Folder folder) {
    openFolderCustomization(context, folder);
  }

  Color _getFolderCardBg(int index) {
    final colors = [
      const Color(0xFFB0B0A8), // Grey
      const Color(0xFFFFBDE6), // Pink
      const Color(0xFFD6C8FF), // Purple
      const Color(0xFFA8DADC), // Cyan
      const Color(0xFFD4ECDD), // Green
      const Color(0xFFFFC6FF), // Pink
    ];
    return colors[index % colors.length];
  }

  Widget _buildHeaderBar() {
    return SizedBox(
      height: 44.0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _isSearchExpanded
            ? Row(
                key: const ValueKey('search_active_header'),
                children: [
                  BottomBarGlassSurface(
                    width: 44.0,
                    height: 44.0,
                    borderRadius: BorderRadius.circular(22.0),
                    useFrost: true,
                    child: TactileButton(
                      useAppleSpring: true,
                      compressionScale: 0.7,
                      settleDuration: const Duration(milliseconds: 1000),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isSearchExpanded = false;
                          _searchQuery = "";
                        });
                      },
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/angle_left.svg',
                          width: 22,
                          height: 22,
                          colorFilter: const ColorFilter.mode(
                              Color(0xFF1C1C1E), BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BottomBarGlassSurface(
                      width: double.infinity,
                      height: 44.0,
                      borderRadius: BorderRadius.circular(22.0),
                      useFrost: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          autofocus: true,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: const Color(0xFF1C1C1E),
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Search folders...",
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFF8C8987),
                            ),
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10.0),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  BottomBarGlassSurface(
                    width: 44.0,
                    height: 44.0,
                    borderRadius: BorderRadius.circular(22.0),
                    useFrost: true,
                    child: TactileButton(
                      useAppleSpring: true,
                      compressionScale: 0.7,
                      settleDuration: const Duration(milliseconds: 1000),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isSearchExpanded = false;
                          _searchQuery = "";
                        });
                      },
                      child: const Center(
                        child: Icon(
                          Icons.close_rounded,
                          color: Color(0xFF1C1C1E),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Stack(
                key: const ValueKey('search_inactive_header'),
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: 44.0,
                    height: 44.0,
                    child: BottomBarGlassSurface(
                      width: 44.0,
                      height: 44.0,
                      borderRadius: BorderRadius.circular(22.0),
                      useFrost: true,
                      child: TactileButton(
                        useAppleSpring: true,
                        compressionScale: 0.7,
                        settleDuration: const Duration(milliseconds: 1000),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onNavigateToTab?.call(0);
                        },
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/angle_left.svg',
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                                Color(0xFF1C1C1E), BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    width: 44.0,
                    height: 44.0,
                    child: Hero(
                      tag: 'hero_folders_search',
                      child: BottomBarGlassSurface(
                        width: 44.0,
                        height: 44.0,
                        borderRadius: BorderRadius.circular(22.0),
                        useFrost: true,
                        child: TactileButton(
                          useAppleSpring: true,
                          compressionScale: 0.7,
                          settleDuration: const Duration(milliseconds: 1000),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              buildSearchTransitionRoute(
                                builder: (_) =>
                                    const SearchScreen(initialScope: 'notes'),
                              ),
                            );
                          },
                          child: const Center(
                            child: Icon(
                              Icons.search_rounded,
                              color: Color(0xFF1C1C1E),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 30,
                    left: 15,
                    width: 150,
                    height: 133,
                    child: CustomPaint(
                      painter: FolderBgPainter(color: const Color(0xFFE6E3D2)),
                    ),
                  ),
                  Positioned(
                    left: 28,
                    top: 15,
                    child: Transform.rotate(
                      angle: -10.0 * pi / 180.0,
                      alignment: Alignment.topLeft,
                      child: const DecorativeNoteCard(),
                    ),
                  ),
                  Positioned(
                    left: 88,
                    top: 5,
                    child: Transform.rotate(
                      angle: 10.0 * pi / 180.0,
                      alignment: Alignment.topLeft,
                      child: const DecorativeNoteCard(),
                    ),
                  ),
                  Positioned(
                    top: 30,
                    left: 15,
                    width: 150,
                    height: 133,
                    child: CustomPaint(
                      painter: FolderFgPainter(color: const Color(0xFFF2F2EE)),
                    ),
                  ),
                  Positioned(
                    right: 25.0,
                    bottom: 25.0,
                    width: 32.0,
                    height: 32.0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFCC00),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6.0,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF1C1C1E),
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Your Folders are Empty",
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1C1C1E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Organize your thoughts and notes in elegant style. Create your first folder to begin.",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF8E8E93),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            BottomBarGlassSurface(
              width: 200.0,
              height: 50.0,
              borderRadius: BorderRadius.circular(25.0),
              useFrost: true,
              child: TactileButton(
                useAppleSpring: true,
                compressionScale: 0.9,
                onTap: showCreateFolderDialog,
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    "Create Folder",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotesProvider>(context);
    final folders = provider.folders;
    final orderedFolders = FolderUtils.getHierarchicalFolders(folders);
    final activeNotes = provider.allActiveNotes;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double panelTop = MediaQuery.paddingOf(context).top + 69.0;

    final filteredFolders = orderedFolders.where((item) {
      if (_searchQuery.trim().isEmpty) return true;
      return item.folder.name
          .toLowerCase()
          .contains(_searchQuery.trim().toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          if (_isSearchExpanded)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isSearchExpanded = false;
                  });
                },
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),

          // White rounded bottom sheet panel for Folders Screen
          Positioned.fill(
            top: panelTop,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3F000000),
                    blurRadius: 16,
                    offset: Offset(0, 0),
                    spreadRadius: 0,
                  )
                ],
              ),
              child: PrimaryScreenSurface(
                child: Center(
                  child: SizedBox(
                    width: screenWidth.clamp(0.0, 402.0),
                    child: folders.isEmpty
                      ? _buildEmptyState()
                      : filteredFolders.isEmpty
                          ? Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 40.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.folder_open_rounded,
                                      size: 48,
                                      color: const Color(0xFF1C1C1E)
                                          .withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "No folders match search",
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1C1C1E)
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0,
                                  80.0 + MediaQuery.paddingOf(context).bottom),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8.0,
                                mainAxisSpacing: 0.0,
                                childAspectRatio: 150.0 / 192.0,
                              ),
                              itemCount: filteredFolders.length,
                              itemBuilder: (context, index) {
                                final item = filteredFolders[index];
                                final folder = item.folder;
                                final noteCount = activeNotes
                                    .where((n) => n.folderId == folder.id)
                                    .length;
                                final key = _getKeyForFolder(folder.id);

                                return AnimatedListEntrance(
                                  key: key,
                                  index: index,
                                  child: FolderGridCard(
                                    folder: folder,
                                    index: index,
                                    noteCount: noteCount,
                                    onTap: () => _handleFolderTap(folder),
                                    onLongPressStart: (details) {
                                      _showFolderContextMenu(context, folder,
                                          details.globalPosition);
                                    },
                                    onCustomizeTap: () {
                                      _showCustomizationBottomSheet(folder);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ),
            ),

          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: SizedBox(
                    width: screenWidth.clamp(0.0, 402.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 12.0),
                      child: _buildHeaderBar(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Redesigned Grid Folder Card
// ─────────────────────────────────────────────────────────────────────────────
class FolderGridCard extends StatelessWidget {
  final Folder folder;
  final int index;
  final int noteCount;
  final VoidCallback onTap;
  final GestureLongPressStartCallback onLongPressStart;
  final VoidCallback onCustomizeTap;

  const FolderGridCard({
    super.key,
    required this.folder,
    required this.index,
    required this.noteCount,
    required this.onTap,
    required this.onLongPressStart,
    required this.onCustomizeTap,
  });

  Color _darken(Color color, [double amount = .08]) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color bgColorDark;
    if (folder.colorHex != null) {
      final parsed = Color(int.parse(folder.colorHex!));
      bgColor = parsed;
      bgColorDark = _darken(parsed);
    } else {
      bgColor = const Color(0xFFB0B0A8);
      bgColorDark = const Color(0xFF9E9E96);
    }

    return TactileButton(
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      compressionScale: 0.95,
      useAppleSpring: true,
      playSelectionHaptic: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 150.0,
                height: 154.0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 20.916,
                      left: 0,
                      width: 150.0,
                      height: 133.0,
                      child: CustomPaint(
                        painter: FolderBgPainter(color: bgColorDark),
                      ),
                    ),
                    Positioned(
                      left: 13.9,
                      top: 9.5,
                      child: Transform.rotate(
                        angle: -10.0 * pi / 180.0,
                        alignment: Alignment.topLeft,
                        child: const DecorativeNoteCard(),
                      ),
                    ),
                    Positioned(
                      left: 73.5,
                      top: -1.5,
                      child: Transform.rotate(
                        angle: 10.0 * pi / 180.0,
                        alignment: Alignment.topLeft,
                        child: const DecorativeNoteCard(),
                      ),
                    ),
                    Positioned(
                      top: 20.916,
                      left: 0,
                      width: 150.0,
                      height: 133.0,
                      child: CustomPaint(
                        painter: FolderFgPainter(color: bgColor),
                      ),
                    ),
                    Positioned(
                      right: 8.0,
                      bottom: 8.0,
                      width: 36.0,
                      height: 36.0,
                      child: folder.sticker != null
                          ? Image.asset(
                              "assets/stickers/${folder.sticker}",
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox.shrink();
                              },
                            )
                          : TactileButton(
                              onTap: onCustomizeTap,
                              compressionScale: 0.8,
                              useAppleSpring: true,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4.0,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: Color(0xFF8E8E93),
                                  size: 20,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  folder.name,
                  style: GoogleFonts.inter(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1C1C1E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6.0),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: const Color(0x1A787880),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  "$noteCount",
                  style: GoogleFonts.inter(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF555558),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Decorative peeking notepad
// ─────────────────────────────────────────────────────────────────────────────
class DecorativeNoteCard extends StatelessWidget {
  const DecorativeNoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64.0,
      height: 86.0,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: 64.0,
            height: 86.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF333333).withValues(alpha: 0.18),
                    blurRadius: 16.0,
                    offset: Offset.zero,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            width: 64.0,
            height: 41.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ),
          Positioned(
            top: 11.0,
            left: 0,
            width: 64.0,
            height: 75.0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF333333).withValues(alpha: 0.10),
                    blurRadius: 6.0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 10.0, 8.0, 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    5,
                    (i) => Container(
                      height: 1.5,
                      margin: EdgeInsets.only(right: i == 4 ? 14.0 : 0.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E2DF),
                        borderRadius: BorderRadius.circular(1.0),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Folder Background Painter
// ─────────────────────────────────────────────────────────────────────────────
class FolderBgPainter extends CustomPainter {
  final Color color;

  const FolderBgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20.0),
    );

    final shadowPaint = Paint()
      ..color = Color(0xFF333333).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawRRect(rrect, shadowPaint);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant FolderBgPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Folder Foreground Flap Painter
// ─────────────────────────────────────────────────────────────────────────────
class FolderFgPainter extends CustomPainter {
  final Color color;

  const FolderFgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 150.0;
    final double sy = size.height / 133.0;

    Path _svg() {
      final p = Path();
      p.moveTo(0, 20.0007);
      p.cubicTo(0, 8.95454, 8.94541, 0, 19.9916, 0);
      p.cubicTo(34.3373, 0, 53.6809, 0, 68.5554, 0);
      p.cubicTo(72.7535, 0, 77.0289, 1.23472, 79.298, 4.7667);
      p.cubicTo(81.9393, 8.87798, 83.7342, 14.0167, 86.4703, 18.0011);
      p.cubicTo(88.7081, 21.2597, 92.7727, 22.3273, 96.7258, 22.3273);
      p.cubicTo(108.31, 22.3273, 120.325, 22.3273, 130.007, 22.3273);
      p.cubicTo(141.052, 22.3273, 150, 31.2816, 150, 42.3273);
      p.lineTo(150, 112.999);
      p.cubicTo(150, 124.045, 141.046, 133, 130, 133);
      p.lineTo(20, 133);
      p.cubicTo(8.9543, 133, 0, 124.045, 0, 113);
      p.lineTo(0, 20.0007);
      p.close();
      return p;
    }

    final svgPath = _svg();
    final matrix = Matrix4.identity()..scale(sx, sy, 1.0);
    final scaledPath = svgPath.transform(matrix.storage);

    canvas.drawShadow(
        scaledPath, Color(0xFF333333).withValues(alpha: 0.18), 3.0, true);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(scaledPath, paint);

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(scaledPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant FolderFgPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Folder Customization Entry Point & Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Authoritative capability boundary for opening Folder Customization.
/// Gated by [PremiumFeature.folderCustomization].
Future<void> openFolderCustomization(BuildContext context, Folder folder) async {
  try {
    final featureAccess = Provider.of<FeatureAccess>(context, listen: false);
    if (!featureAccess.canAccess(PremiumFeature.folderCustomization)) {
      await showPremiumGate(
        context: context,
        feature: PremiumFeature.folderCustomization,
      );
      return;
    }
  } catch (_) {
    // Graceful fallback if FeatureAccess provider is not in context
    await showPremiumGate(
      context: context,
      feature: PremiumFeature.folderCustomization,
    );
    return;
  }

  if (!context.mounted) return;

  showBlurredBottomSheet(
    context: context,
    child: FolderCustomizationSheet(
      folder: folder,
      onApply: (updatedFolder) {
        Provider.of<NotesProvider>(context, listen: false)
            .updateFolder(updatedFolder);
      },
    ),
  );
}

class FolderCustomizationSheet extends StatefulWidget {
  final Folder folder;
  final ValueChanged<Folder> onApply;

  const FolderCustomizationSheet({
    super.key,
    required this.folder,
    required this.onApply,
  });

  @override
  State<FolderCustomizationSheet> createState() =>
      _FolderCustomizationSheetState();
}

class _FolderCustomizationSheetState extends State<FolderCustomizationSheet> {
  String? _selectedColorHex;
  String? _selectedSticker;

  @override
  void initState() {
    super.initState();
    _selectedColorHex = widget.folder.colorHex;
    _selectedSticker = widget.folder.sticker;
  }

  void _showFullColorPicker() {
    final initialColor = _selectedColorHex != null
        ? Color(int.parse(_selectedColorHex!))
        : const Color(0xFFB0B0A8);
    showDialog(
      context: context,
      builder: (context) => IosColorPickerDialog(
        initialColor: initialColor,
        onColorSelected: (color) {
          setState(() {
            _selectedColorHex =
                "0x${color.value.toRadixString(16).toUpperCase()}";
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> defaultColorHexes = [
      "0xFFB0B0A8", // Grey
      "0xFFFFBDE6", // Pink
      "0xFFD6C8FF", // Purple
      "0xFFA8DADC", // Cyan
      "0xFFD4ECDD", // Green
      "0xFFFFC6FF", // Light Pink
    ];

    final List<String> stickers = [
      "birds.png",
      "customer-service.png",
      "kiss (1).png",
      "kiss.png",
      "love.png",
      "nurse.png",
    ];

    // Issue #1 Fix: dynamically prepend or append the selected custom color if it's not one of default presets
    final List<String> displayColorHexes = List<String>.from(defaultColorHexes);
    if (_selectedColorHex != null &&
        !defaultColorHexes.contains(_selectedColorHex)) {
      displayColorHexes.add(_selectedColorHex!);
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F7),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32.0),
          topRight: Radius.circular(32.0),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36.0,
              height: 5.0,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Customize Folder",
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Folder Color",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        ...displayColorHexes.map((hex) {
                          final color = Color(int.parse(hex));
                          final isSelected = _selectedColorHex == hex ||
                              (_selectedColorHex == null &&
                                  hex == "0xFFB0B0A8");
                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: TactileButton(
                              onTap: () {
                                setState(() {
                                  _selectedColorHex = hex;
                                });
                              },
                              compressionScale: 0.9,
                              child: Container(
                                width: 38.0,
                                height: 38.0,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF1C1C1E)
                                        : const Color(0x1F000000),
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Color(0xFF1C1C1E), size: 18)
                                    : null,
                              ),
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: TactileButton(
                            onTap: _showFullColorPicker,
                            compressionScale: 0.8,
                            child: Container(
                              width: 38.0,
                              height: 38.0,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFEFF4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.colorize_rounded,
                                color: Color(0xFF1C1C1E),
                                size: 18.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Sticker Store",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Visual Changes: Vertical layout grid for stickers store
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12.0,
                      mainAxisSpacing: 12.0,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: stickers.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isSelected = _selectedSticker == null;
                        return TactileButton(
                          onTap: () {
                            setState(() {
                              _selectedSticker = null;
                            });
                          },
                          compressionScale: 0.9,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFEFF4),
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF1C1C1E)
                                    : Colors.transparent,
                                width: 2.0,
                              ),
                            ),
                            child: const Icon(
                              Icons.block_rounded,
                              color: Color(0xFF8E8E93),
                              size: 24,
                            ),
                          ),
                        );
                      }
                      final sticker = stickers[index - 1];
                      final isSelected = _selectedSticker == sticker;
                      return TactileButton(
                        onTap: () {
                          setState(() {
                            _selectedSticker = sticker;
                          });
                        },
                        compressionScale: 0.9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1C1C1E)
                                  : Colors.transparent,
                              width: 2.0,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(6.0),
                          child: Image.asset(
                            "assets/stickers/$sticker",
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          BottomBarGlassSurface(
            width: double.infinity,
            height: 50.0,
            borderRadius: BorderRadius.circular(25.0),
            useFrost: true,
            child: TactileButton(
              useAppleSpring: true,
              compressionScale: 0.95,
              onTap: () {
                final updatedFolder = widget.folder.copyWith(
                  colorHex: _selectedColorHex,
                  sticker: _selectedSticker,
                  clearSticker: _selectedSticker == null,
                );
                widget.onApply(updatedFolder);
                Navigator.pop(context);
              },
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  "Apply Customization",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// iOS System Color Picker Dialog
// ─────────────────────────────────────────────────────────────────────────────
class IosColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const IosColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<IosColorPickerDialog> createState() => _IosColorPickerDialogState();
}

class _IosColorPickerDialogState extends State<IosColorPickerDialog> {
  int _activeTabIndex = 0; // 0 = Grid, 1 = Spectrum, 2 = Sliders
  late Color _currentColor;
  late double _currentOpacity;

  static final List<Color> _gridColors = [
    // Grayscale
    Colors.white, const Color(0xFFE5E5EA), const Color(0xFFD1D1D6),
    const Color(0xFFC7C7CC),
    const Color(0xFFAEAEB2), const Color(0xFF8E8E93), const Color(0xFF636366),
    const Color(0xFF48484A),
    const Color(0xFF323235), Color(0xFF333333),
    // Reds
    const Color(0xFFFFD6D6), const Color(0xFFFFADAD), const Color(0xFFFF7A7A),
    const Color(0xFFFF4D4D),
    const Color(0xFFFF2E2E), const Color(0xFFE60000), const Color(0xFFB30000),
    const Color(0xFF800000),
    const Color(0xFF4D0000), const Color(0xFF260000),
    // Oranges
    const Color(0xFFFFE3D6), const Color(0xFFFFC4A3), const Color(0xFFFF9E66),
    const Color(0xFFFF7B33),
    const Color(0xFFFF5500), const Color(0xFFD64700), const Color(0xFFA33600),
    const Color(0xFF702500),
    const Color(0xFF471700), const Color(0xFF260C00),
    // Yellows
    const Color(0xFFFFF9D6), const Color(0xFFFFF2A3), const Color(0xFFFFE966),
    const Color(0xFFFFE033),
    const Color(0xFFFFD700), const Color(0xFFD6B400), const Color(0xFFA38900),
    const Color(0xFF705E00),
    const Color(0xFF473C00), const Color(0xFF262000),
    // Greens
    const Color(0xFFD6FAD6), const Color(0xFFADF5AD), const Color(0xFF7AF07A),
    const Color(0xFF4DEB4D),
    const Color(0xFF2EE62E), const Color(0xFF00CC00), const Color(0xFF009900),
    const Color(0xFF006600),
    const Color(0xFF004000), const Color(0xFF002000),
    // Teals
    const Color(0xFFD6FAF6), const Color(0xFFADF5EC), const Color(0xFF7AF0DF),
    const Color(0xFF4DEBD0),
    const Color(0xFF2EE6C0), const Color(0xFF00CC9C), const Color(0xFF009975),
    const Color(0xFF00664E),
    const Color(0xFF004031), const Color(0xFF002018),
    // Blues
    const Color(0xFFD6E4FA), const Color(0xFFADC4F5), const Color(0xFF7A9EF0),
    const Color(0xFF4D7BEB),
    const Color(0xFF2E5EE6), const Color(0xFF0038CC), const Color(0xFF002A99),
    const Color(0xFF001C66),
    const Color(0xFF001240), const Color(0xFF000920),
    // Purples
    const Color(0xFFEAD6FA), const Color(0xFFD0ADF5), const Color(0xFFB37AF0),
    const Color(0xFF974DEB),
    const Color(0xFF7B2EE6), const Color(0xFF5C00CC), const Color(0xFF450099),
    const Color(0xFF2E0066),
    const Color(0xFF1D0040), const Color(0xFF0F0020),
    // Pinks
    const Color(0xFFFAD6EA), const Color(0xFFF5ADD0), const Color(0xFFF07AB3),
    const Color(0xFFEB4D97),
    const Color(0xFFE62E7B), const Color(0xFFCC005C), const Color(0xFF990045),
    const Color(0xFF66002E),
    const Color(0xFF40001D), const Color(0xFF20000F),
  ];

  static final List<Color> _userPresets = [
    const Color(0xFF4CD964), // Green
    const Color(0xFFFFCC00), // Yellow
    const Color(0xFFFF9500), // Orange
    const Color(0xFFFF3B30), // Red
    const Color(0xFFFF2D55), // Pink
    const Color(0xFF007AFF), // Blue
    const Color(0xFF5856D6), // Purple
    const Color(0xFF8E8E93), // Grey
    const Color(0xFFFFFFFF), // White
  ];

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _currentOpacity = widget.initialColor.opacity;
  }

  void _updateColor(Color newColor) {
    setState(() {
      _currentColor = newColor;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF9F9F7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28.0),
      ),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Container(
        width: 320.0,
        padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(
                  Icons.colorize_rounded,
                  color: Color(0xFF1C1C1E),
                  size: 20.0,
                ),
                Text(
                  "Colors",
                  style: GoogleFonts.inter(
                    fontSize: 17.0,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF1C1C1E),
                    size: 20.0,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFF4),
                borderRadius: BorderRadius.circular(9.0),
              ),
              padding: const EdgeInsets.all(2.0),
              child: Row(
                children: [
                  _buildTabItem(0, "Grid"),
                  _buildTabItem(1, "Spectrum"),
                  _buildTabItem(2, "Sliders"),
                ],
              ),
            ),
            const SizedBox(height: 20.0),
            SizedBox(
              height: 200.0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildActiveTabContent(),
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              "OPACITY",
              style: GoogleFonts.inter(
                fontSize: 11.0,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8E8E93),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8.0),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 20.0,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onPanDown: (details) {
                            final double x = details.localPosition.dx
                                .clamp(0.0, constraints.maxWidth);
                            setState(() {
                              _currentOpacity = x / constraints.maxWidth;
                            });
                          },
                          onPanUpdate: (details) {
                            final double x = details.localPosition.dx
                                .clamp(0.0, constraints.maxWidth);
                            setState(() {
                              _currentOpacity = x / constraints.maxWidth;
                            });
                          },
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: CheckerboardPainter(),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                _currentColor.withValues(
                                                    alpha: 0.0),
                                                _currentColor.withValues(
                                                    alpha: 1.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: (_currentOpacity *
                                        (constraints.maxWidth - 20.0))
                                    .clamp(0.0, constraints.maxWidth - 20.0),
                                child: Container(
                                  width: 20.0,
                                  height: 20.0,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black38,
                                        blurRadius: 4.0,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Container(
                  width: 54.0,
                  height: 30.0,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    border:
                        Border.all(color: const Color(0xFFEFEFF4), width: 1.0),
                  ),
                  child: Text(
                    "${(_currentOpacity * 100).round()}%",
                    style: GoogleFonts.inter(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20.0),
            const Divider(height: 1, color: Color(0xFFE5E5EA)),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Container(
                  width: 44.0,
                  height: 44.0,
                  decoration: BoxDecoration(
                    color: _currentColor.withValues(alpha: _currentOpacity),
                    borderRadius: BorderRadius.circular(10.0),
                    border:
                        Border.all(color: const Color(0xFFE5E5EA), width: 1.5),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        ..._userPresets.map((color) {
                          final isSelected = _currentColor.value == color.value;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: TactileButton(
                              onTap: () {
                                _updateColor(color);
                              },
                              compressionScale: 0.9,
                              child: Container(
                                width: 28.0,
                                height: 28.0,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF1C1C1E)
                                        : const Color(0x1F000000),
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        TactileButton(
                          onTap: () {
                            if (!_userPresets
                                .any((c) => c.value == _currentColor.value)) {
                              setState(() {
                                _userPresets.add(_currentColor);
                              });
                            }
                          },
                          compressionScale: 0.8,
                          child: Container(
                            width: 28.0,
                            height: 28.0,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFEFF4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Color(0xFF1C1C1E),
                              size: 18.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20.0),
            BottomBarGlassSurface(
              width: double.infinity,
              height: 48.0,
              borderRadius: BorderRadius.circular(20.0),
              useFrost: true,
              child: TactileButton(
                useAppleSpring: true,
                compressionScale: 0.95,
                onTap: () {
                  widget.onColorSelected(
                      _currentColor.withValues(alpha: _currentOpacity));
                  Navigator.pop(context);
                },
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    "Select Color",
                    style: GoogleFonts.inter(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = _activeTabIndex == index;
    return Expanded(
      child: TactileButton(
        onTap: () {
          setState(() {
            _activeTabIndex = index;
          });
        },
        compressionScale: 0.95,
        child: Container(
          height: 32.0,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7.0),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 3.0,
                      offset: Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.0,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTabIndex) {
      case 0:
        return _buildGridTab();
      case 1:
        return _buildSpectrumTab();
      case 2:
        return _buildSlidersTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGridTab() {
    return GridView.builder(
      key: const ValueKey('grid_tab'),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
        mainAxisSpacing: 6.0,
        crossAxisSpacing: 6.0,
      ),
      itemCount: _gridColors.length,
      itemBuilder: (context, index) {
        final color = _gridColors[index];
        final isSelected = _currentColor.value == color.value;
        return TactileButton(
          onTap: () => _updateColor(color),
          compressionScale: 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(
                color: isSelected ? Colors.white : const Color(0x1F000000),
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 2.0,
                        offset: Offset(0, 1),
                      )
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpectrumTab() {
    return LayoutBuilder(
      key: const ValueKey('spectrum_tab'),
      builder: (context, constraints) {
        return GestureDetector(
          onPanDown: (details) => _handleSpectrumTouch(details.localPosition,
              Size(constraints.maxWidth, constraints.maxHeight)),
          onPanUpdate: (details) => _handleSpectrumTouch(details.localPosition,
              Size(constraints.maxWidth, constraints.maxHeight)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: CustomPaint(
                painter: SpectrumPainter(),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleSpectrumTouch(Offset localPos, Size size) {
    final double x = localPos.dx.clamp(0.0, size.width);
    final double y = localPos.dy.clamp(0.0, size.height);
    final double hue = (x / size.width) * 360.0;
    final double saturation = (1.0 - y / size.height).clamp(0.0, 1.0);
    _updateColor(HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor());
  }

  Widget _buildSlidersTab() {
    return Column(
      key: const ValueKey('sliders_tab'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSliderRow("R", _currentColor.red, Colors.red, (val) {
          _updateColor(Color.fromARGB(_currentColor.alpha, val.round(),
              _currentColor.green, _currentColor.blue));
        }),
        _buildSliderRow("G", _currentColor.green, Colors.green, (val) {
          _updateColor(Color.fromARGB(_currentColor.alpha, _currentColor.red,
              val.round(), _currentColor.blue));
        }),
        _buildSliderRow("B", _currentColor.blue, Colors.blue, (val) {
          _updateColor(Color.fromARGB(_currentColor.alpha, _currentColor.red,
              _currentColor.green, val.round()));
        }),
      ],
    );
  }

  Widget _buildSliderRow(String label, int value, Color activeColor,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 20.0,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: activeColor,
              inactiveTrackColor: const Color(0xFFE5E5EA),
              thumbColor: Colors.white,
              overlayColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 10.0, elevation: 2.0),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0.0,
              max: 255.0,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 12.0),
        Container(
          width: 44.0,
          height: 28.0,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: const Color(0xFFEFEFF4), width: 1.0),
          ),
          child: Text(
            "$value",
            style: GoogleFonts.inter(
              fontSize: 13.0,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Checkerboard Painter
// ─────────────────────────────────────────────────────────────────────────────
class CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE5E5EA);
    const double squareSize = 6.0;
    for (double y = 0; y < size.height; y += squareSize) {
      final bool startWithWhite = (y / squareSize).round() % 2 == 0;
      for (double x = 0; x < size.width; x += squareSize) {
        final bool isWhite = (x / squareSize).round() % 2 == 0;
        if (startWithWhite != isWhite) {
          canvas.drawRect(Rect.fromLTWH(x, y, squareSize, squareSize), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CheckerboardPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Spectrum Painter
// ─────────────────────────────────────────────────────────────────────────────
class SpectrumPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFF0000),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF00FFFF),
          Color(0xFF0000FF),
          Color(0xFFFF00FF),
          Color(0xFFFF0000),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    final whiteValPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white,
          Colors.transparent,
          Color(0xFF333333),
        ],
      ).createShader(rect)
      ..blendMode = BlendMode.multiply;
    canvas.drawRect(rect, whiteValPaint);
  }

  @override
  bool shouldRepaint(covariant SpectrumPainter oldDelegate) => false;
}
