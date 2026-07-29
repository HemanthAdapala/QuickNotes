import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FolderOptionsPopup
//
// Liquid glass popup for FolderNotesScreen matching MoreOptionsPopup.
// Supports main menu and animated inline Sort Submenu with Back navigation.
// Typography: GoogleFonts.inter, fontSize: 14, letterSpacing: -0.43, height: 1.0, color: #333333
// ─────────────────────────────────────────────────────────────────────────────

enum FolderSortOption { newest, oldest, alphabetical }

class FolderOptionsPopup extends StatelessWidget {
  final VoidCallback? onRenameFolder;
  final ValueChanged<FolderSortOption>? onSortSelect;
  final VoidCallback? onDeleteFolder;
  final FolderSortOption currentSort;
  final bool isSortSubmenuOpen;
  final ValueChanged<bool>? onSubmenuToggle;

  const FolderOptionsPopup({
    super.key,
    this.onRenameFolder,
    this.onSortSelect,
    this.onDeleteFolder,
    this.currentSort = FolderSortOption.newest,
    this.isSortSubmenuOpen = false,
    this.onSubmenuToggle,
  });

  Widget _buildMenuItem({
    required String iconAsset,
    required String label,
    required VoidCallback? onTap,
    required bool hasBottomDivider,
    Widget? trailingWidget,
  }) {
    const textColor = Color(0xFF333333);

    return GestureDetector(
      onTap: onTap,
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
                  decoration: const ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(width: 0.20, color: Color(0x33000000)),
                    ),
                  ),
                ),
              ),

            Positioned(
              left: 14,
              top: 17,
              child: SvgPicture.asset(
                iconAsset,
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(textColor, BlendMode.srcIn),
              ),
            ),

            Positioned(
              left: 39,
              top: 10,
              child: SizedBox(
                width: trailingWidget != null ? 115 : 139,
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

            if (trailingWidget != null)
              Positioned(
                right: 14,
                top: 17,
                child: trailingWidget,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF333333);

    if (isSortSubmenuOpen) {
      return SizedBox(
        width: 192,
        height: 200,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back Header Item
            _buildMenuItem(
              iconAsset: 'assets/icons/angle_left.svg',
              label: 'Sort Notes',
              onTap: () => onSubmenuToggle?.call(false),
              hasBottomDivider: true,
            ),

            // Option 1: Newest First
            _buildMenuItem(
              iconAsset: 'assets/icons/refresh.svg',
              label: 'Newest First',
              onTap: () {
                onSortSelect?.call(FolderSortOption.newest);
                onSubmenuToggle?.call(false);
              },
              hasBottomDivider: true,
              trailingWidget: currentSort == FolderSortOption.newest
                  ? const Icon(Icons.check_rounded, size: 16, color: textColor)
                  : null,
            ),

            // Option 2: Oldest First
            _buildMenuItem(
              iconAsset: 'assets/icons/refresh.svg',
              label: 'Oldest First',
              onTap: () {
                onSortSelect?.call(FolderSortOption.oldest);
                onSubmenuToggle?.call(false);
              },
              hasBottomDivider: true,
              trailingWidget: currentSort == FolderSortOption.oldest
                  ? const Icon(Icons.check_rounded, size: 16, color: textColor)
                  : null,
            ),

            // Option 3: Alphabetical A-Z
            _buildMenuItem(
              iconAsset: 'assets/icons/refresh.svg',
              label: 'Alphabetical',
              onTap: () {
                onSortSelect?.call(FolderSortOption.alphabetical);
                onSubmenuToggle?.call(false);
              },
              hasBottomDivider: false,
              trailingWidget: currentSort == FolderSortOption.alphabetical
                  ? const Icon(Icons.check_rounded, size: 16, color: textColor)
                  : null,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 192,
      height: 150,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rename Folder (Pencil icon)
          _buildMenuItem(
            iconAsset: 'assets/icons/bottom_navigation/pencil.svg',
            label: 'Rename Folder',
            onTap: onRenameFolder,
            hasBottomDivider: true,
          ),

          // Sort Notes (Refresh icon + angle-right chevron)
          _buildMenuItem(
            iconAsset: 'assets/icons/refresh.svg',
            label: 'Sort Notes',
            onTap: () => onSubmenuToggle?.call(true),
            hasBottomDivider: true,
            trailingWidget: SvgPicture.asset(
              'assets/icons/angle-right.svg',
              width: 12,
              height: 12,
              colorFilter: const ColorFilter.mode(textColor, BlendMode.srcIn),
            ),
          ),

          // Delete Folder (Trash icon)
          _buildMenuItem(
            iconAsset: 'assets/icons/trash.svg',
            label: 'Delete Folder',
            onTap: onDeleteFolder,
            hasBottomDivider: false,
          ),
        ],
      ),
    );
  }
}
