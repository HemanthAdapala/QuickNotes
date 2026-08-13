import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tactile_button.dart';

/// GroupedListContainer — Standardized Apple-styled grouped card container.
///
/// Automatically inserts 1px divider hairlines between adjacent child widgets.
///
/// Example:
/// ```dart
/// GroupedListContainer(
///   children: [
///     GroupedTile.navigation(title: 'Account', onTap: () => ...),
///     GroupedTile.navigation(title: 'General Settings', onTap: () => ...),
///   ],
/// )
/// ```
class GroupedListContainer extends StatelessWidget {
  final List<Widget> children;
  final double width;
  final double borderRadius;
  final Color backgroundColor;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? padding;

  const GroupedListContainer({
    super.key,
    required this.children,
    this.width = 322.0,
    this.borderRadius = 20.0,
    this.backgroundColor = Colors.white,
    this.shadows = const [
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 12,
        offset: Offset(0, 2),
      ),
    ],
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    // Auto-inject 1px hairline dividers between adjacent children
    final List<Widget> dividedChildren = [];
    for (int i = 0; i < children.length; i++) {
      dividedChildren.add(children[i]);
      if (i < children.length - 1) {
        dividedChildren.add(
          Container(
            width: double.infinity,
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: const Color(0xFFE6E6E6),
          ),
        );
      }
    }

    return Center(
      child: Container(
        width: width,
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          shadows: shadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: dividedChildren,
        ),
      ),
    );
  }
}

/// Helper class for building standardized tiles inside [GroupedListContainer].
abstract class GroupedTile {
  /// Navigation Tile — displays a title, optional leading icon, and trailing chevron (`>`).
  static Widget navigation({
    Key? key,
    required String title,
    String? iconPath,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    double height = 50.0,
  }) {
    return TactileButton(
      key: key,
      useAppleSpring: true,
      onTap: onTap ?? () {},
      child: Container(
        width: double.infinity,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: 12),
            ] else if (iconPath != null) ...[
              SvgPicture.asset(
                iconPath,
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF333333),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: const Color(0xFF333333),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  letterSpacing: -0.43,
                ),
              ),
            ),
            trailing ??
                SvgPicture.asset(
                  'assets/icons/angle-right.svg',
                  width: 14,
                  height: 14,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF333333),
                    BlendMode.srcIn,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// Input Tile — displays a [TextField] for username, email, full name, or custom forms.
  static Widget input({
    Key? key,
    required TextEditingController controller,
    FocusNode? focusNode,
    required String hintText,
    bool isReadOnly = false,
    bool isEnabled = true,
    TextInputType keyboardType = TextInputType.text,
    bool showVerifiedBadge = false,
    double height = 52.0,
  }) {
    const primaryTextColor = Color(0xFF333333);

    return Container(
      key: key,
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: isReadOnly,
              enabled: isEnabled,
              keyboardType: keyboardType,
              style: GoogleFonts.inter(
                color: isReadOnly
                    ? primaryTextColor.withValues(alpha: 0.6)
                    : primaryTextColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.3,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.inter(
                  color: const Color(0x4C3C3C43),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (showVerifiedBadge)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Image.asset(
                'assets/icons/check.png',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              ),
            )
          else if (!isReadOnly && controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                controller.clear();
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.cancel,
                  size: 18,
                  color: const Color(0xFF3C3C43).withValues(alpha: 0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Toggle Tile — displays a title, optional icon, and trailing switch control.
  static Widget toggle({
    Key? key,
    required String title,
    String? iconPath,
    Widget? leading,
    required Widget trailingSwitch,
    double height = 50.0,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          if (leading != null) ...[
            leading,
            const SizedBox(width: 12),
          ] else if (iconPath != null) ...[
            SvgPicture.asset(
              iconPath,
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                Color(0xFF333333),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: const Color(0xFF333333),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.0,
                letterSpacing: -0.43,
              ),
            ),
          ),
          trailingSwitch,
        ],
      ),
    );
  }

  /// Action Tile — for standalone action buttons (e.g. Delete Data, Seed Tasks).
  static Widget action({
    Key? key,
    required String title,
    String? iconPath,
    Widget? leading,
    VoidCallback? onTap,
    bool isDestructive = false,
    double height = 50.0,
  }) {
    final textColor = isDestructive ? const Color(0xFFFF3B30) : const Color(0xFF333333);

    return TactileButton(
      key: key,
      useAppleSpring: true,
      onTap: onTap ?? () {},
      child: Container(
        width: double.infinity,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: 12),
            ] else if (iconPath != null) ...[
              SvgPicture.asset(
                iconPath,
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  letterSpacing: -0.43,
                ),
              ),
            ),
            SvgPicture.asset(
              'assets/icons/angle-right.svg',
              width: 14,
              height: 14,
              colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }
}
