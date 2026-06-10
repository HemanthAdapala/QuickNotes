import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../models/folder.dart';
import '../../providers/notes_provider.dart';
import 'living_writing_experience.dart';


class NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onPinToggle;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onPinToggle,
    required this.onFavoriteToggle,
    required this.onDelete,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> with TickerProviderStateMixin {
  bool _isPressed = false;

  late AnimationController _deleteController;
  late Animation<double> _deleteAnimation;
  bool _isDeleting = false;

  late AnimationController _pinController;
  late Animation<double> _pinAnimation;
  bool _isPinning = false;

  @override
  void initState() {
    super.initState();
    _deleteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _deleteAnimation = CurvedAnimation(parent: _deleteController, curve: Curves.easeInOutCubic);

    _pinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pinAnimation = CurvedAnimation(parent: _pinController, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _deleteController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _handleDelete() {
    if (_isDeleting) return;
    setState(() {
      _isDeleting = true;
    });
    _deleteController.forward().then((_) {
      widget.onDelete();
    });
  }

  void _handlePinToggle() {
    if (_isPinning) return;
    setState(() {
      _isPinning = true;
    });
    _pinController.forward().then((_) {
      _pinController.reverse();
      setState(() {
        _isPinning = false;
      });
      widget.onPinToggle();
    });
  }

  String? _getFirstImagePath(Note note) {
    // 1. Look in note.attachments for image
    final Map<String, dynamic> firstImage = note.attachments.firstWhere(
      (a) => a['type'] == 'image',
      orElse: () => {},
    );
    if (firstImage.isNotEmpty && firstImage['path'] != null) {
      return firstImage['path'] as String;
    }
    // 2. Parse inline image markdown syntax: ![description](url)
    final regExp = RegExp(r'!\[.*?\]\((.*?)\)');
    final match = regExp.firstMatch(note.content);
    if (match != null) {
      String path = match.group(1) ?? '';
      if (path.startsWith('file://')) {
        try {
          return Uri.parse(path).toFilePath();
        } catch (_) {
          String p = path.substring(7);
          if (Platform.isWindows && p.startsWith('/')) {
            p = p.substring(1);
          }
          return p;
        }
      }
      return path;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Playful Pop borders & shadows
    final strokeColor = isDark ? const Color(0xFFFAF8F5) : const Color(0xFF1E1B4B);
    final shadowColor = isDark ? const Color(0xFF312E81) : const Color(0xFF1E1B4B);
    
    final cardColor = NotesProvider.getNoteColor(widget.note.colorValue, context);
    final textColor = NotesProvider.getNoteTextColor(widget.note.colorValue, context);
    final titleColor = NotesProvider.getNoteTitleColor(widget.note.colorValue, context);
    
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final folderList = notesProvider.folders.where((f) => f.id == widget.note.folderId).toList();
    final Folder? folder = folderList.isNotEmpty ? folderList.first : null;

    // Format timestamp
    final formattedDate = DateFormat('MMM d, h:mm a').format(widget.note.updatedAt);

    // Extract image attachment path (from attachments or inline markdown)
    final String? imagePath = _getFirstImagePath(widget.note);

    // Extract voice attachment presence
    final bool hasVoice = widget.note.attachments.any((a) => a['type'] == 'voice');

    if (_isDeleting) {
      final double progress = _deleteAnimation.value;
      final double scale = 1.0 - (0.05 * progress);
      final double opacity = 1.0 - progress;
      final double angle = 0.06 * progress; // ~3.5 degrees
      final double translateX = 120.0 * progress;

      return SizeTransition(
        sizeFactor: Tween<double>(begin: 1.0, end: 0.0).animate(_deleteAnimation),
        axis: Axis.vertical,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(translateX, 0),
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(
                scale: scale,
                child: _buildCardContent(context, theme, strokeColor, shadowColor, cardColor, textColor, titleColor, folder, formattedDate, imagePath, hasVoice),
              ),
            ),
          ),
        ),
      );
    }

    return TactileFlipWrapper(
      id: widget.note.id,
      child: Hero(
        tag: 'note_card_${widget.note.id}',
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: widget.onTap,
            child: Transform.scale(
              scale: _isPinning 
                  ? 1.0 - (0.03 * _pinAnimation.value)
                  : (_isPressed ? 0.97 : 1.0),
              child: _buildCardContent(context, theme, strokeColor, shadowColor, cardColor, textColor, titleColor, folder, formattedDate, imagePath, hasVoice),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    ThemeData theme,
    Color strokeColor,
    Color shadowColor,
    Color cardColor,
    Color textColor,
    Color titleColor,
    Folder? folder,
    String formattedDate,
    String? imagePath,
    bool hasVoice,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.note.isPinned
            ? theme.colorScheme.primary.withOpacity(0.08)
            : cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.note.isPinned
              ? theme.colorScheme.primary
              : strokeColor,
          width: widget.note.isPinned ? 2.0 : 1.5,
        ),
        boxShadow: [
          if (_isPinning)
            BoxShadow(
              color: shadowColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          else
            BoxShadow(
              color: shadowColor,
              blurRadius: 0,
              offset: _isPressed ? const Offset(1, 1) : const Offset(4, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
                  // Render image thumbnail preview or subtle gradient cover at the top of the card
                  if (imagePath != null && !widget.note.isLocked)
                    Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      height: 120,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    )
                  else if (widget.note.colorValue > 0 && !widget.note.isLocked)
                    Container(
                      height: 60,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            strokeColor.withAlpha(50),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row: Title & Action Toggles
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.note.isLocked
                                        ? "Locked Note"
                                        : (widget.note.title.isNotEmpty ? widget.note.title : "Untitled"),
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: titleColor,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.note.isHabit && !widget.note.isLocked) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withAlpha(30),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.orange.withAlpha(80), width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.local_fire_department_rounded,
                                            size: 12,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            "${widget.note.habitStreak} day streak",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!widget.note.isDeleted) ...[
                              const SizedBox(width: 8),
                              // Favorite Toggle Button
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  widget.note.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 20,
                                  color: widget.note.isFavorite 
                                      ? Colors.amber 
                                      : titleColor.withAlpha(120),
                                ),
                                onPressed: widget.onFavoriteToggle,
                                tooltip: widget.note.isFavorite ? "Remove favorite" : "Add favorite",
                              ),
                              const SizedBox(width: 6),
                              // Pin Toggle Button
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: RotationTransition(
                                  turns: Tween<double>(
                                    begin: 0.0, 
                                    end: widget.note.isPinned ? -0.125 : 0.125,
                                  ).animate(_pinAnimation),
                                  child: Icon(
                                    widget.note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                    size: 20,
                                    color: widget.note.isPinned 
                                        ? theme.colorScheme.primary 
                                        : titleColor.withAlpha(120),
                                  ),
                                ),
                                onPressed: _handlePinToggle,
                                tooltip: widget.note.isPinned ? "Unpin note" : "Pin note",
                              ),
                            ],
                          ],
                        ),
                        
                        // Category & Folder Badges Tag Wrap
                        if (!widget.note.isLocked && ((widget.note.category.isNotEmpty && widget.note.category != 'Uncategorized') || folder != null))
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 4),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (widget.note.category.isNotEmpty && widget.note.category != 'Uncategorized')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: NotesProvider.getCategoryTagColor(widget.note.colorValue, context),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: strokeColor.withAlpha(60), width: 0.8),
                                    ),
                                    child: Text(
                                      widget.note.category,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: textColor.withAlpha(220),
                                      ),
                                    ),
                                  ),
                                if (folder != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: NotesProvider.getCategoryTagColor(widget.note.colorValue, context).withAlpha(120),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: strokeColor.withAlpha(80),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.folder_open_rounded,
                                          size: 11,
                                          color: textColor.withAlpha(180),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          folder.name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: textColor.withAlpha(220),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                        const SizedBox(height: 10),
                        
                        // Body Content / Locked Mockup / Checklist preview
                        if (widget.note.isLocked)
                          _buildLockedContent(context, textColor)
                        else if (widget.note.noteType == 'checklist')
                          _buildChecklistPreview(context, widget.note.content, textColor)
                        else
                          Text(
                            widget.note.content.isNotEmpty ? widget.note.content : "No additional text",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: widget.note.content.isNotEmpty ? textColor : textColor.withAlpha(120),
                              height: 1.4,
                            ),
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                        
                        // Multi-Tags Pill Row
                        if (widget.note.tags.isNotEmpty && !widget.note.isLocked) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: widget.note.tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: NotesProvider.getCategoryTagColor(widget.note.colorValue, context).withAlpha(100),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: strokeColor.withAlpha(50), width: 0.8),
                                ),
                                child: Text(
                                  "#$tag",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: textColor.withAlpha(200),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 16),
                        
                        // Footer Row: Date / Icons & Delete Action
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  formattedDate,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: textColor.withAlpha(150),
                                  ),
                                ),
                                if (hasVoice && !widget.note.isLocked) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.mic_rounded,
                                    size: 14,
                                    color: textColor.withAlpha(150),
                                  ),
                                ],
                                if (widget.note.reminderTime != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.alarm_rounded,
                                    size: 14,
                                    color: theme.colorScheme.primary.withAlpha(200),
                                  ),
                                ],
                              ],
                            ),
                            if (widget.note.isDeleted) ...[
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  Icons.restore_rounded,
                                  size: 18,
                                  color: widget.note.colorValue == 0
                                      ? theme.colorScheme.primary
                                      : textColor.withAlpha(180),
                                ),
                                onPressed: () {
                                  Provider.of<NotesProvider>(context, listen: false).restoreFromTrash(widget.note.id);
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Note restored"),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                tooltip: "Restore note",
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.delete_forever_rounded,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text("Delete Note Permanently?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                      content: const Text("This action cannot be undone. Are you sure you want to permanently delete this note?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("Cancel"),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _handleDelete();
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: theme.colorScheme.error,
                                            foregroundColor: theme.colorScheme.onError,
                                          ),
                                          child: const Text("Delete"),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                tooltip: "Delete permanently",
                              ),
                            ] else ...[
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: widget.note.colorValue == 0 
                                      ? theme.colorScheme.error.withAlpha(180) 
                                      : textColor.withAlpha(150),
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text("Delete Note?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                      content: const Text("This note will be moved to the Trash. You can restore it later."),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("Cancel"),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _handleDelete();
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: theme.colorScheme.error,
                                            foregroundColor: theme.colorScheme.onError,
                                          ),
                                          child: const Text("Delete"),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                tooltip: "Delete note",
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

  // Locked Card layout mockup builder
  Widget _buildLockedContent(BuildContext context, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 28,
            color: textColor.withAlpha(80),
          ),
          const SizedBox(height: 8),
          Text(
            "Note is locked",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor.withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }

  // Checklist completion overview widget
  Widget _buildChecklistPreview(BuildContext context, String contentJson, Color textColor) {
    List<dynamic> items = [];
    try {
      items = jsonDecode(contentJson) as List<dynamic>;
    } catch (e) {
      return Text(
        contentJson,
        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: textColor),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (items.isEmpty) {
      return Text(
        "Empty checklist",
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: textColor.withAlpha(120),
        ),
      );
    }

    final totalCount = items.length;
    final doneCount = items.where((e) => (e['done'] ?? false) == true || (e['checked'] ?? false) == true).length;
    final fractionText = "$doneCount of $totalCount items completed";

    // Show first 3 checklist item previews
    final previewItems = items.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...previewItems.map((item) {
          final bool isDone = item['done'] == true || item['checked'] == true;
          final String itemText = item['text'] ?? item['title'] ?? "";
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.check_box_outlined : Icons.check_box_outline_blank_rounded,
                  size: 14,
                  color: isDone ? textColor.withAlpha(100) : textColor.withAlpha(150),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    itemText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: isDone ? textColor.withAlpha(120) : textColor,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        if (totalCount > 3)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              "+ ${totalCount - 3} more tasks",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: textColor.withAlpha(120),
              ),
            ),
          ),
        const SizedBox(height: 8),
        // Progress text
        Text(
          fractionText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textColor.withAlpha(180),
          ),
        ),
      ],
    );
  }
}
