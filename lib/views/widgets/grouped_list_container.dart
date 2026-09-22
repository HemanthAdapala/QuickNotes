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
  final Color? backgroundColor;
  final Color? dividerColor;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;

  const GroupedListContainer({
    super.key,
    required this.children,
    this.width = 322.0,
    this.borderRadius = 20.0,
    this.backgroundColor,
    this.dividerColor,
    this.shadows = const [
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 12,
        offset: Offset(0, 2),
      ),
    ],
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBg =
        backgroundColor ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final effectiveDividerColor = dividerColor ??
        (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE6E6E6));

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
            color: effectiveDividerColor,
          ),
        );
      }
    }

    return Center(
      child: Container(
        width: width,
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border,
          boxShadow: shadows,
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
    bool scrollSafe = true,
    Color? textColor,
    double fontSize = 14.0,
    Color? chevronColor,
  }) {
    final primaryColor = textColor ?? const Color(0xFF333333);
    final effectiveChevronColor = chevronColor ?? primaryColor;
    return TactileButton(
      key: key,
      useAppleSpring: true,
      scrollSafe: scrollSafe,
      onTap: onTap ?? () {},
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: 12),
            ] else if (iconPath != null) ...[
              SvgPicture.asset(
                iconPath,
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(
                  primaryColor,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                key: ValueKey('$title-$primaryColor'),
                softWrap: true,
                style: GoogleFonts.inter(
                  color: primaryColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                SvgPicture.asset(
                  'assets/icons/angle-right.svg',
                  width: 14,
                  height: 14,
                  colorFilter: ColorFilter.mode(
                    effectiveChevronColor,
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
    List<TextInputFormatter>? inputFormatters,
    Color? textColor,
    Color? fillColor,
    Color? clearIconColor,
  }) {
    final primaryTextColor = textColor ?? const Color(0xFF333333);
    const hintColor = Color(0x4C3C3C43);
    final effectiveClearIconColor =
        clearIconColor ?? const Color(0xFF3C3C43).withValues(alpha: 0.3);

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
              inputFormatters: inputFormatters,
              style: GoogleFonts.inter(
                color: isReadOnly
                    ? primaryTextColor.withValues(alpha: 0.6)
                    : primaryTextColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.3,
              ),
              decoration: InputDecoration(
                filled: fillColor != null,
                fillColor: fillColor ?? Colors.transparent,
                hintText: hintText,
                hintStyle: GoogleFonts.inter(
                  color: hintColor,
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
                  color: effectiveClearIconColor,
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
    Color? textColor,
    double fontSize = 14.0,
  }) {
    final primaryColor = textColor ?? const Color(0xFF333333);

    return Container(
      key: key,
      width: double.infinity,
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading,
            const SizedBox(width: 12),
          ] else if (iconPath != null) ...[
            SvgPicture.asset(
              iconPath,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                primaryColor,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              key: ValueKey('$title-$primaryColor'),
              softWrap: true,
              style: GoogleFonts.inter(
                color: primaryColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                height: 1.25,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
    bool scrollSafe = true,
    Color? textColor,
    double fontSize = 14.0,
  }) {
    final effectiveTextColor = isDestructive
        ? const Color(0xFFFF453A)
        : (textColor ?? const Color(0xFF333333));

    return TactileButton(
      key: key,
      useAppleSpring: true,
      scrollSafe: scrollSafe,
      onTap: onTap ?? () {},
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: 12),
            ] else if (iconPath != null) ...[
              SvgPicture.asset(
                iconPath,
                width: 18,
                height: 18,
                colorFilter:
                    ColorFilter.mode(effectiveTextColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                softWrap: true,
                style: GoogleFonts.inter(
                  color: effectiveTextColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SvgPicture.asset(
              'assets/icons/angle-right.svg',
              width: 14,
              height: 14,
              colorFilter:
                  ColorFilter.mode(effectiveTextColor, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  /// Key-Value Display Tile — displays title on left and value text on right.
  static Widget keyValue({
    Key? key,
    required String title,
    required String value,
    String? iconPath,
    Widget? leading,
    VoidCallback? onTap,
    double height = 50.0,
    bool scrollSafe = true,
    Color? textColor,
    double fontSize = 14.0,
  }) {
    final primaryTextColor = textColor ?? const Color(0xFF333333);
    const valueTextColor = Color(0xFF8E8E93);

    return TactileButton(
      key: key,
      useAppleSpring: true,
      scrollSafe: scrollSafe,
      onTap: onTap ?? () {},
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: 12),
            ] else if (iconPath != null) ...[
              SvgPicture.asset(
                iconPath,
                width: 18,
                height: 18,
                colorFilter:
                    ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                title,
                softWrap: true,
                style: GoogleFonts.inter(
                  color: primaryTextColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: valueTextColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w400,
                  height: 1.25,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
