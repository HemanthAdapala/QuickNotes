import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/motion/quick_notes_haptics.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NoteEditorOptionsPopup
//
// Liquid glass popup for NoteEditorScreen matching MoreOptionsPopup & FolderOptionsPopup.
// Displays Pin Note, Add Favourite, Export & Share, and Delete Note options.
// ─────────────────────────────────────────────────────────────────────────────

class NoteEditorOptionsPopup extends StatelessWidget {
  final bool isPinned;
  final bool isFavorite;
  final VoidCallback? onTogglePin;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onFindInNote;
  final VoidCallback? onExportAndShare;
  final VoidCallback? onDeleteNote;

  const NoteEditorOptionsPopup({
    super.key,
    required this.isPinned,
    required this.isFavorite,
    this.onTogglePin,
    this.onToggleFavorite,
    this.onFindInNote,
    this.onExportAndShare,
    this.onDeleteNote,
  });

  Widget _buildMenuItem({
    required Widget icon,
    required String label,
    required VoidCallback? onTap,
    required bool hasBottomDivider,
    Color textColor = const Color(0xFF333333),
    Color dividerColor = const Color(0x33000000),
  }) {
    return Semantics(
      button: true,
      child: FocusableActionDetector(
        includeFocusSemantics: false,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) {
              QuickNotesHaptics.buttonPress();
              onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: () {
            QuickNotesHaptics.buttonPress();
            onTap?.call();
          },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 192,
            height: 50,
            child: Stack(
              children: [
                if (hasBottomDivider)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      width: 192,
                      height: 1,
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(width: 0.20, color: dividerColor),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 14,
                  top: 17,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: Center(child: icon),
                  ),
                ),
                Positioned(
                  left: 39,
                  top: 10,
                  child: SizedBox(
                    width: 139,
                    height: 30,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.43,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor =
        isDark ? const Color(0xFFFFFFFF) : const Color(0xFF333333);
    final iconColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF333333);
    final dividerColor =
        isDark ? const Color(0x33FFFFFF) : const Color(0x33000000);

    return Container(
      width: 192,
      height: 250,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Pin / Unpin Note
          _buildMenuItem(
            icon: Icon(
              isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 16,
              color: isPinned
                  ? (isDark
                      ? const Color(0xFF0088FF)
                      : theme.colorScheme.primary)
                  : iconColor,
            ),
            label: isPinned ? 'Unpin Note' : 'Pin Note',
            onTap: onTogglePin,
            hasBottomDivider: true,
            textColor: primaryTextColor,
            dividerColor: dividerColor,
          ),

          // 2. Add / Remove Favourite
          _buildMenuItem(
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              size: 16,
              color: isFavorite ? const Color(0xFFFFCC00) : iconColor,
            ),
            label: isFavorite ? 'Remove Favorite' : 'Add Favorite',
            onTap: onToggleFavorite,
            hasBottomDivider: true,
            textColor: primaryTextColor,
            dividerColor: dividerColor,
          ),

          // 3. Find in Note
          _buildMenuItem(
            icon: Icon(
              Icons.search_rounded,
              size: 16,
              color: iconColor,
            ),
            label: 'Find in Note',
            onTap: onFindInNote,
            hasBottomDivider: true,
            textColor: primaryTextColor,
            dividerColor: dividerColor,
          ),

          // 4. Export and Share
          _buildMenuItem(
            icon: Icon(
              Icons.share_rounded,
              size: 16,
              color: iconColor,
            ),
            label: 'Export & Share',
            onTap: onExportAndShare,
            hasBottomDivider: true,
            textColor: primaryTextColor,
            dividerColor: dividerColor,
          ),

          // 5. Delete Note
          _buildMenuItem(
            icon: SvgPicture.asset(
              'assets/icons/trash.svg',
              width: 16,
              height: 16,
              colorFilter:
                  const ColorFilter.mode(Colors.redAccent, BlendMode.srcIn),
            ),
            label: 'Delete Note',
            onTap: onDeleteNote,
            hasBottomDivider: false,
            textColor: Colors.redAccent,
            dividerColor: dividerColor,
          ),
        ],
      ),
    );
  }
}
