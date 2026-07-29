// ──────────────────────────────────────────────────────────────────────────────
// folder_notes_screen.dart — "Specific Folder Screen"
// Implemented directly from DesignCode specifications:
// - DesignCode/FolderScreen/SpecificFolderScreen.txt
// - DesignCode/Widgets/FolderNote.txt
// ──────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../providers/notes_provider.dart';
import '../../models/note_summary.dart';
import '../../models/folder.dart';
import '../../themes/app_theme.dart';
import '../../core/animations/animated_list_entrance.dart';
import '../../core/animations/page_transitions.dart';
import '../../core/animations/search_route.dart';
import 'search_screen.dart';
import '../../core/animations/bottom_sheet_transition.dart';
import '../../core/animations/dialog_transition.dart';
import '../widgets/tactile_button.dart';
import '../widgets/app_header_bar.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/folder_note_card.dart';
import '../widgets/folder_options_popup.dart';
import '../widgets/pin_lock_sheet.dart';
import 'note_editor_screen.dart';

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
  FolderSortOption _currentSort = FolderSortOption.newest;
  bool _isSelectionMode = false;
  bool _isFolderOptionsOpen = false;
  bool _isSortSubmenuActive = false;
  final Set<String> _selectedNoteIds = {};
  final TextEditingController _folderNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<NotesProvider>(context, listen: false);
      provider.setSelectedFolder(widget.folder.id);
    });
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    try {
      Provider.of<NotesProvider>(context, listen: false).setSelectedFolder(null);
    } catch (_) {}
    super.dispose();
  }

  // ── Sort notes helper ──────────────────────────────────────────────────────
  List<NoteSummary> _sortNotes(List<NoteSummary> list) {
    final sorted = List<NoteSummary>.from(list);
    switch (_currentSort) {
      case FolderSortOption.newest:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case FolderSortOption.oldest:
        sorted.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case FolderSortOption.alphabetical:
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }
    return sorted;
  }

  // ── Note tap (handles selection mode & locked vault) ─────────────────────
  void _onNoteTap(NoteSummary note, NotesProvider provider) async {
    if (_isFolderOptionsOpen) {
      setState(() => _isFolderOptionsOpen = false);
      return;
    }

    if (_isSelectionMode) {
      HapticFeedback.selectionClick();
      setState(() {
        if (_selectedNoteIds.contains(note.id)) {
          _selectedNoteIds.remove(note.id);
          if (_selectedNoteIds.isEmpty) {
            _isSelectionMode = false;
          }
        } else {
          _selectedNoteIds.add(note.id);
        }
      });
      return;
    }

    final fullNote = await provider.getNoteById(note.id);
    if (fullNote == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load note details')),
        );
      }
      return;
    }

    if (fullNote.isLocked && !provider.isVaultUnlocked) {
      showAnimatedBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: PinLockSheet(
          onPinSubmitted: (pin) async {
            final nav = Navigator.of(context);
            final msng = ScaffoldMessenger.of(context);
            if (await provider.unlockVault(pin)) {
              final decryptedNote = await provider.getNoteById(note.id);
              if (mounted && decryptedNote != null) nav.push(buildPageRoute(NoteEditorScreen(note: decryptedNote)));
            } else {
              if (mounted) {
                msng
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(
                    content: Text('Incorrect PIN Code! Access Denied.'),
                    backgroundColor: Colors.red,
                  ));
              }
            }
          },
        ),
      );
    } else {
      Navigator.push(context, buildPageRoute(NoteEditorScreen(note: fullNote)));
    }
  }

  void _onNoteLongPress(NoteSummary note) {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedNoteIds.add(note.id);
    });
  }

  // ── Rename Folder Dialog ──────────────────────────────────────────────────
  void _showRenameFolderDialog(NotesProvider provider) {
    _folderNameController.text = widget.folder.name;
    showAnimatedDialog(
      context: context,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Rename Folder", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _folderNameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Folder Name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final newName = _folderNameController.text.trim();
              if (newName.isNotEmpty) {
                await provider.updateFolder(Folder(
                  id: widget.folder.id,
                  name: newName,
                  parentId: widget.folder.parentId,
                  createdAt: widget.folder.createdAt,
                ));
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ── Sort Picker Sheet ──────────────────────────────────────────────────────
  void _showSortPicker() {
    showAnimatedBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Sort Notes By',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Date Modified (Newest First)'),
              trailing: _currentSort == FolderSortOption.newest ? const Icon(Icons.check, color: Color(0xFF1C1C1E)) : null,
              onTap: () {
                setState(() => _currentSort = FolderSortOption.newest);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Date Modified (Oldest First)'),
              trailing: _currentSort == FolderSortOption.oldest ? const Icon(Icons.check, color: Color(0xFF1C1C1E)) : null,
              onTap: () {
                setState(() => _currentSort = FolderSortOption.oldest);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Title (Alphabetical)'),
              trailing: _currentSort == FolderSortOption.alphabetical ? const Icon(Icons.check, color: Color(0xFF1C1C1E)) : null,
              onTap: () {
                setState(() => _currentSort = FolderSortOption.alphabetical);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete Folder Confirmation ────────────────────────────────────────────
  void _confirmDeleteFolder(NotesProvider provider) {
    showAnimatedDialog(
      context: context,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete Folder?", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: const Text("Deleting this folder will move its notes to Uncategorized. Notes will not be deleted."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteFolder(widget.folder.id);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Pop screen back to Folders tab
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Bulk Actions: Move, Pin, Delete Selected ──────────────────────────────
  void _bulkMoveNotes(NotesProvider provider) {
    final availableFolders = provider.folders.where((f) => f.id != widget.folder.id).toList();

    showAnimatedBottomSheet(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.20),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 402.0, maxHeight: 485.0),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 12.0, 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Move ${_selectedNoteIds.length} ${_selectedNoteIds.length == 1 ? 'Note' : 'Notes'} To',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                        letterSpacing: -0.43,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF828282), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x1F000000)),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Uncategorized Option
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0),
                        leading: SvgPicture.asset(
                          'assets/icons/bottom_navigation/folder-open.svg',
                          width: 22,
                          height: 22,
                          colorFilter: const ColorFilter.mode(Color(0xFF828282), BlendMode.srcIn),
                        ),
                        title: Text(
                          'Uncategorized (No Folder)',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF333333),
                            letterSpacing: -0.43,
                            height: 1.0,
                          ),
                        ),
                        onTap: () async {
                          for (final id in _selectedNoteIds) {
                            final note = await provider.getNoteById(id);
                            if (note != null) {
                              await provider.updateNote(note.copyWith(clearFolder: true));
                            }
                          }
                          if (mounted) {
                            Navigator.pop(context);
                            setState(() {
                              _selectedNoteIds.clear();
                              _isSelectionMode = false;
                            });
                          }
                        },
                      ),
                      // Folder List
                      for (final folder in availableFolders)
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0),
                          leading: SvgPicture.asset(
                            'assets/icons/bottom_navigation/folder-open.svg',
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(Color(0xFFFFCC00), BlendMode.srcIn),
                          ),
                          title: Text(
                            folder.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF333333),
                              letterSpacing: -0.43,
                              height: 1.0,
                            ),
                          ),
                          onTap: () async {
                            for (final id in _selectedNoteIds) {
                              final note = await provider.getNoteById(id);
                              if (note != null) {
                                await provider.updateNote(note.copyWith(folderId: folder.id));
                              }
                            }
                            if (mounted) {
                              Navigator.pop(context);
                              setState(() {
                                _selectedNoteIds.clear();
                                _isSelectionMode = false;
                              });
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _bulkPinNotes(NotesProvider provider) async {
    for (final id in _selectedNoteIds) {
      await provider.togglePin(id);
    }
    setState(() {
      _selectedNoteIds.clear();
      _isSelectionMode = false;
    });
  }

  void _bulkDeleteNotes(NotesProvider provider) async {
    for (final id in _selectedNoteIds) {
      await provider.trashNote(id);
    }
    setState(() {
      _selectedNoteIds.clear();
      _isSelectionMode = false;
    });
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/bottom_navigation/folder-open.svg',
              width: 56,
              height: 56,
              colorFilter: ColorFilter.mode(
                const Color(0xFF1C1C1E).withValues(alpha: 0.3),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No notes in this folder yet",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C1C1E).withValues(alpha: 0.5),
                letterSpacing: -0.43,
              ),
            ),
            const SizedBox(height: 16),
            TactileButton(
              useAppleSpring: true,
              compressionScale: 0.9,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  buildPageRoute(NoteEditorScreen(defaultFolderId: widget.folder.id)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC00), // Vibrant Yellow pill
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Create Note",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1C1C1E),
                    letterSpacing: -0.43,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double panelTop = MediaQuery.paddingOf(context).top + 69.0;
    final provider = Provider.of<NotesProvider>(context);

    final allFolderNotes = provider.notesSummary
        .where((n) => n.folderId == widget.folder.id && !n.isDeleted)
        .toList();

    final pinnedNotes = _sortNotes(allFolderNotes.where((n) => n.isPinned).toList());
    final unpinnedNotes = _sortNotes(allFolderNotes.where((n) => !n.isPinned).toList());

    return PopScope(
      canPop: !_isSelectionMode && !_isFolderOptionsOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_isFolderOptionsOpen) {
            setState(() => _isFolderOptionsOpen = false);
            return;
          }
          if (_isSelectionMode) {
            setState(() {
              _selectedNoteIds.clear();
              _isSelectionMode = false;
            });
            return;
          }
        }
        if (didPop) {
          try {
            Provider.of<NotesProvider>(context, listen: false).setSelectedFolder(null);
          } catch (_) {}
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // White Bottom Sheet Content Panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: screenWidth.clamp(0.0, 402.0),
                  height: (screenHeight - panelTop).clamp(0.0, 754.0),
                  decoration: const ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x3F000000),
                        blurRadius: 16,
                        offset: Offset(0, 0),
                        spreadRadius: 0,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: allFolderNotes.isEmpty
                        ? _buildEmptyState()
                        : CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              // ── Folder header (name + note count) ─────────────
                              // Uses SliverPadding so the viewport stays at the full
                              // panel width — card shadows are never clipped by the
                              // viewport's hard-edge clip during scroll.
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(24.0, 17.0, 24.0, 24.0),
                                sliver: SliverToBoxAdapter(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.folder.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF333333),
                                          height: 0.75,
                                          letterSpacing: -0.43,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 9),
                                      Text(
                                        '${allFolderNotes.length} ${allFolderNotes.length == 1 ? 'NOTE' : 'NOTES'}',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0x993C3C43),
                                          height: 1.0,
                                          letterSpacing: -0.43,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ── Pinned section ─────────────────────────────────
                              if (pinnedNotes.isNotEmpty) ...[
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 8.0),
                                  sliver: SliverToBoxAdapter(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.push_pin_rounded, size: 12, color: Color(0xFFF5A623)),
                                        const SizedBox(width: 4),
                                        Text(
                                          "PINNED",
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                            color: const Color(0xFF828282),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 16.0),
                                  sliver: SliverGrid(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 22.0,
                                      mainAxisSpacing: 24.0,
                                      childAspectRatio: 150.0 / 157.0,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final note = pinnedNotes[index];
                                        final isSelected = _selectedNoteIds.contains(note.id);
                                        return AnimatedListEntrance(
                                          key: ValueKey(note.id),
                                          index: index,
                                          child: FolderNoteCard(
                                            note: note,
                                            isSelectionMode: _isSelectionMode,
                                            isSelected: isSelected,
                                            onTap: () => _onNoteTap(note, provider),
                                            onLongPressStart: (_) => _onNoteLongPress(note),
                                          ),
                                        );
                                      },
                                      childCount: pinnedNotes.length,
                                    ),
                                  ),
                                ),
                                if (unpinnedNotes.isNotEmpty)
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 8.0),
                                    sliver: SliverToBoxAdapter(
                                      child: Text(
                                        "NOTES",
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                          color: const Color(0xFF828282),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],

                              // ── Unpinned / Regular grid ─────────────────────────
                              if (unpinnedNotes.isNotEmpty)
                                SliverPadding(
                                  padding: EdgeInsets.only(
                                    left: 24.0,
                                    right: 24.0,
                                    bottom: 80.0 + MediaQuery.paddingOf(context).bottom,
                                  ),
                                  sliver: SliverGrid(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 22.0,
                                      mainAxisSpacing: 24.0,
                                      childAspectRatio: 150.0 / 157.0,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final note = unpinnedNotes[index];
                                        final isSelected = _selectedNoteIds.contains(note.id);
                                        return AnimatedListEntrance(
                                          key: ValueKey(note.id),
                                          index: index,
                                          child: FolderNoteCard(
                                            note: note,
                                            isSelectionMode: _isSelectionMode,
                                            isSelected: isSelected,
                                            onTap: () => _onNoteTap(note, provider),
                                            onLongPressStart: (_) => _onNoteLongPress(note),
                                          ),
                                        );
                                      },
                                      childCount: unpinnedNotes.length,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            // Dismissal Overlay for Morphing Options Popup
            if (_isFolderOptionsOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _isFolderOptionsOpen = false),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _isFolderOptionsOpen ? 1.0 : 0.0,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),

            // Glassmorphic FAB in bottom right corner (hidden during selection mode / popup open)
            if (!_isSelectionMode && !_isFolderOptionsOpen)
              Positioned(
                bottom: 24.0 + MediaQuery.paddingOf(context).bottom,
                right: 24.0,
                child: BottomBarGlassSurface(
                  width: 52.0,
                  height: 52.0,
                  borderRadius: BorderRadius.circular(26.0),
                  child: TactileButton(
                    useAppleSpring: true,
                    compressionScale: 0.7,
                    settleDuration: const Duration(milliseconds: 1000),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        buildPageRoute(NoteEditorScreen(defaultFolderId: widget.folder.id)),
                      );
                    },
                    child: const Center(
                      child: Icon(
                        Icons.add_rounded,
                        color: Color(0xFF1C1C1E),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),

            // Multi-select Bulk Actions Bar at bottom of screen
            if (_isSelectionMode)
              Positioned(
                left: 20,
                right: 20,
                bottom: 24.0 + MediaQuery.paddingOf(context).bottom,
                child: BottomBarGlassSurface(
                  width: double.infinity,
                  height: 56.0,
                  borderRadius: BorderRadius.circular(28.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedNoteIds.length} Selected',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.drive_file_move_outlined, color: Color(0xFF333333)),
                              tooltip: 'Move to Folder',
                              onPressed: () => _bulkMoveNotes(provider),
                            ),
                            IconButton(
                              icon: const Icon(Icons.push_pin_outlined, color: Color(0xFF333333)),
                              tooltip: 'Pin/Unpin',
                              onPressed: () => _bulkPinNotes(provider),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              tooltip: 'Delete Selected',
                              onPressed: () => _bulkDeleteNotes(provider),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.grey),
                              tooltip: 'Cancel',
                              onPressed: () {
                                setState(() {
                                  _selectedNoteIds.clear();
                                  _isSelectionMode = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Floating Glass Header Row with Dual Glass Buttons on Top Right (Search + MoreOptions)
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: SizedBox(
                      width: screenWidth.clamp(0.0, 402.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        child: AppHeaderBar(
                          leftHeroTag: 'hero_profile_header',
                          rightHeroTag: 'hero_more_options',
                          leftWidth: 44.0,
                          onLeftTap: () {
                            HapticFeedback.lightImpact();
                            if (_isFolderOptionsOpen) {
                              setState(() => _isFolderOptionsOpen = false);
                            } else if (_isSelectionMode) {
                              setState(() {
                                _selectedNoteIds.clear();
                                _isSelectionMode = false;
                              });
                            } else {
                              Navigator.of(context).maybePop();
                            }
                          },
                          leftChild: SvgPicture.asset(
                            'assets/icons/angle_left.svg',
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF1C1C1E),
                              BlendMode.srcIn,
                            ),
                          ),
                          rightWidth: _isFolderOptionsOpen ? 192.0 : 88.0,
                          isExpanded: _isFolderOptionsOpen,
                          expandedWidth: 192.0,
                          expandedHeight: _isSortSubmenuActive ? 200.0 : 150.0,
                          expandedChild: FolderOptionsPopup(
                            currentSort: _currentSort,
                            isSortSubmenuOpen: _isSortSubmenuActive,
                            onSubmenuToggle: (open) {
                              setState(() {
                                _isSortSubmenuActive = open;
                              });
                            },
                            onRenameFolder: () {
                              setState(() {
                                _isFolderOptionsOpen = false;
                                _isSortSubmenuActive = false;
                              });
                              _showRenameFolderDialog(provider);
                            },
                            onSortSelect: (newSort) {
                              setState(() {
                                _currentSort = newSort;
                                _isFolderOptionsOpen = false;
                                _isSortSubmenuActive = false;
                              });
                            },
                            onDeleteFolder: () {
                              setState(() {
                                _isFolderOptionsOpen = false;
                                _isSortSubmenuActive = false;
                              });
                              _confirmDeleteFolder(provider);
                            },
                          ),
                          rightChild: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Search Icon
                              SizedBox(
                                width: 44.0,
                                height: 44.0,
                                child: TactileButton(
                                  useAppleSpring: true,
                                  compressionScale: 0.7,
                                  settleDuration: const Duration(milliseconds: 1000),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context).push(SearchRoute(
                                      builder: (_) => SearchScreen(
                                        initialScope: 'notes',
                                        presetFolder: widget.folder.id,
                                      ),
                                    ));
                                  },
                                  child: const Center(
                                    child: Icon(
                                      Icons.search_rounded,
                                      size: 20,
                                      color: Color(0xFF1C1C1E),
                                    ),
                                  ),
                                ),
                              ),

                              // 2. MoreOptions (3-dots) Icon
                              SizedBox(
                                width: 44.0,
                                height: 44.0,
                                child: TactileButton(
                                  useAppleSpring: true,
                                  compressionScale: 0.7,
                                  settleDuration: const Duration(milliseconds: 1000),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _isFolderOptionsOpen = !_isFolderOptionsOpen;
                                    });
                                  },
                                  child: const Center(
                                    child: Icon(
                                      Icons.more_horiz_rounded,
                                      size: 20,
                                      color: Color(0xFF1C1C1E),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
