import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/note_summary.dart';
import '../../providers/notes_provider.dart';
import 'package:flutter/services.dart';
import 'living_writing_experience.dart';
import '../screens/category_details_screen.dart';
import '../../core/animations/page_transitions.dart';
import '../../core/animations/animation_constants.dart';
import '../../core/animations/dialog_transition.dart';
import '../../themes/app_theme.dart';
import 'delete_confirmation_dialog.dart';

class NoteCard extends StatefulWidget {
  final NoteSummary note;
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
  late AnimationController _deleteController;
  late Animation<double> _deleteAnimation;
  bool _isDeleting = false;

  late AnimationController _pinController;
  late Animation<double> _pinAnimation;
  final bool _isPinning = false;

  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _deleteController = AnimationController(
      vsync: this,
      duration: kDurationSlow,
    );
    _deleteAnimation =
        CurvedAnimation(parent: _deleteController, curve: kCurvePage);

    _pinController = AnimationController(
      vsync: this,
      duration: kDurationNormal,
    );
    _pinAnimation = CurvedAnimation(parent: _pinController, curve: kCurveEnter);

    _pressController = AnimationController(
      vsync: this,
      duration: kDurationCardPress,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: kCurveExit),
    );
  }

  @override
  void dispose() {
    _deleteController.stop();
    _deleteController.dispose();
    _pinController.stop();
    _pinController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _handleDelete() {
    if (_isDeleting) return;
    setState(() {
      _isDeleting = true;
    });
    _deleteController.forward().then((_) {
      if (mounted) {
        widget.onDelete();
      }
    });
  }

  void _handlePinToggle() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.note.isPinned ? "Note unpinned" : "Note pinned"),
        duration: const Duration(seconds: 1),
      ),
    );
    widget.onPinToggle();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor =
        NotesProvider.getNoteColor(widget.note.colorValue, context);
    final textColor = isDark ? Colors.white70 : AppColors.ink.withOpacity(0.8);
    final titleColor = isDark ? Colors.white : AppColors.ink;

    // Format timestamp
    final formattedDate =
        DateFormat('MMM d, h:mm a').format(widget.note.updatedAt);

    if (_isDeleting) {
      final double progress = _deleteAnimation.value;
      final double scale = 1.0 - (0.05 * progress);
      final double opacity = 1.0 - progress;
      final double angle = 0.06 * progress; // ~3.5 degrees
      final double translateX = 120.0 * progress;

      return SizeTransition(
        sizeFactor:
            Tween<double>(begin: 1.0, end: 0.0).animate(_deleteAnimation),
        axis: Axis.vertical,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(translateX, 0),
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(
                scale: scale,
                child: _buildCardContent(context, theme, cardColor, textColor,
                    titleColor, widget.note.folderName, formattedDate),
              ),
            ),
          ),
        ),
      );
    }

    return TactileFlipWrapper(
      id: widget.note.id,
      child: Hero(
        tag: 'hero_note_card_${widget.note.id}',
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTapDown: (_) {
              _pressController.animateTo(1.0,
                  duration: kDurationCardPress, curve: kCurveExit);
            },
            onTapUp: (_) {
              _pressController.animateTo(0.0,
                  duration: kDurationCardRelease, curve: kCurveEnter);
              widget.onTap();
            },
            onTapCancel: () {
              _pressController.animateTo(0.0,
                  duration: kDurationCardRelease, curve: kCurveEnter);
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([_pressController, _pinAnimation]),
              builder: (context, child) {
                final double currentScale = _isPinning
                    ? 1.0 - (0.03 * _pinAnimation.value)
                    : _scaleAnimation.value;
                return Transform.scale(
                  scale: currentScale,
                  child: _buildCardContent(context, theme, cardColor, textColor,
                      titleColor, widget.note.folderName, formattedDate),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    ThemeData theme,
    Color cardColor,
    Color textColor,
    Color titleColor,
    String? folderName,
    String formattedDate,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    // Soft ambient shadow
    final cardShadow = isDark
        ? [
            BoxShadow(
              color: Color(0xFF333333).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ]
        : [
            BoxShadow(
              color: Color(0xFF333333).withOpacity(0.04),
              blurRadius: 12,
              offset: Offset.lerp(
                const Offset(0, 4),
                const Offset(0, 2),
                _pressController.value,
              )!,
            ),
          ];

    return AnimatedContainer(
      duration: kDurationNormal,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.note.isPinned
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.note.isPinned
              ? theme.colorScheme.primary
              : (isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.4)),
          width: widget.note.isPinned ? 2.0 : 1.0,
        ),
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.note.colorValue > 0 && !widget.note.isLocked)
            Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isDark ? Colors.white : AppColors.ink).withAlpha(30),
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
                                : (widget.note.title.isNotEmpty
                                    ? widget.note.title
                                    : "Untitled"),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.note.isHabit && !widget.note.isLocked) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.orange.withAlpha(80),
                                    width: 0.8),
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
                                    style: GoogleFonts.inter(
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
                          widget.note.isFavorite
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 20,
                          color: widget.note.isFavorite
                              ? Colors.amber
                              : titleColor.withAlpha(120),
                        ),
                        onPressed: widget.onFavoriteToggle,
                        tooltip: widget.note.isFavorite
                            ? "Remove favorite"
                            : "Add favorite",
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
                            widget.note.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            size: 20,
                            color: widget.note.isPinned
                                ? theme.colorScheme.primary
                                : titleColor.withAlpha(120),
                          ),
                        ),
                        onPressed: _handlePinToggle,
                        tooltip:
                            widget.note.isPinned ? "Unpin note" : "Pin note",
                      ),
                    ],
                  ],
                ),

                // Category & Folder Badges Tag Wrap
                if (!widget.note.isLocked &&
                    ((widget.note.categoryName != null &&
                            widget.note.categoryName != 'Uncategorized') ||
                        folderName != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (widget.note.categoryName != null &&
                            widget.note.categoryName != 'Uncategorized')
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).push(
                                buildPageRoute(CategoryDetailsScreen(
                                    category: widget.note.categoryName!)),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: NotesProvider.getCategoryTagColor(
                                    widget.note.colorValue, context),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: (isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.white.withOpacity(0.4)),
                                    width: 0.8),
                              ),
                              child: Text(
                                widget.note.categoryName!,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        if (folderName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: NotesProvider.getCategoryTagColor(
                                      widget.note.colorValue, context)
                                  .withAlpha(120),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.white.withOpacity(0.4)),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.folder_open_rounded,
                                  size: 11,
                                  color: isDark
                                      ? Colors.white60
                                      : AppColors.ink.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  folderName,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),

                // Body Content / Locked Mockup
                if (widget.note.isLocked)
                  _buildLockedContent(context, textColor)
                else
                  Text(
                    widget.note.previewText.isNotEmpty
                        ? widget.note.previewText
                        : "No additional text",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: widget.note.previewText.isNotEmpty
                          ? textColor
                          : textColor.withAlpha(120),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: 16),

                // Footer Row: Date / Icons & Delete Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          formattedDate,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white60
                                : AppColors.ink.withOpacity(0.6),
                          ),
                        ),
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
                          Provider.of<NotesProvider>(context, listen: false)
                              .restoreFromTrash(widget.note.id);
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
                        onPressed: () async {
                          final confirm = await showDeleteNoteDialog(
                            context,
                            title: 'Delete Note Permanently?',
                            message:
                                'This action cannot be undone. Are you sure you want to permanently delete this note?',
                          );
                          if (confirm == true) {
                            _handleDelete();
                          }
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
                        onPressed: () async {
                          final confirm = await showDeleteNoteDialog(context);
                          if (confirm == true) {
                            _handleDelete();
                          }
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
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor.withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }
}
