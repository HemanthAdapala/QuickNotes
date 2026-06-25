import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a single nav destination
// ─────────────────────────────────────────────────────────────────────────────

class NavDestination {
  const NavDestination({
    required this.svgAssetPath,
    required this.label,
    this.semanticLabel,
  });

  final String svgAssetPath;
  final String label;
  final String? semanticLabel;
}

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — all magic numbers live here, not scattered through the tree
// ─────────────────────────────────────────────────────────────────────────────

class _NavTokens {
  const _NavTokens._();

  // Container
  static const double barHeight = 64.0;
  static const double barRadius = 32.0;
  static const double barPaddingH = 8.0;
  static const double barPaddingV = 8.0;

  // FAB pill (pencil / create button)
  static const double fabSize = 60.0;
  static const double fabRadius = 30.0;
  static const double fabGap = 12.0; // horizontal gap between bar and FAB

  // Blur
  static const double blurSigma = 20.0;

  // Glass surfaces — light mode
  static const Color lightFill = Color(0xBBFFFFFF);        // ~73 % white
  static const Color lightBorder = Color(0x40FFFFFF);      // top/left highlight
  static const Color lightBorderBottom = Color(0x18000000); // subtle dark base

  // Glass surfaces — dark mode
  static const Color darkFill = Color(0x992A2A2A);         // ~60 % dark
  static const Color darkBorder = Color(0x33FFFFFF);
  static const Color darkBorderBottom = Color(0x30000000);

  // Icon
  static const double iconSize = 24.0;
  static const Color iconActiveLight = Color(0xFF1A1A1A);
  static const Color iconInactiveLight = Color(0xFF8E8E93); // iOS gray
  static const Color iconActiveDark = Color(0xFFFFFFFF);
  static const Color iconInactiveDark = Color(0xFF636366);

  // Active indicator pill
  static const double indicatorWidth = 40.0;
  static const double indicatorHeight = 3.0;
  static const double indicatorRadius = 1.5;
  static const Color indicatorLight = Color(0xFF1A1A1A);
  static const Color indicatorDark = Color(0xFFFFFFFF);

  // Shadows (Figma: dy=4, blur=4, opacity=0.25)
  static List<BoxShadow> shadow(bool isDark) => [
        BoxShadow(
          color: isDark
              ? const Color(0x52000000)
              : const Color(0x40000000),
          blurRadius: 24.0,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: isDark
              ? const Color(0x1A000000)
              : const Color(0x1A000000),
          blurRadius: 4.0,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ];

  // Animation
  static const Duration animDuration = Duration(milliseconds: 220);
  static const Curve animCurve = Curves.easeInOut;
}

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

class AppBottomNavigationBar extends StatefulWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.fabSvgAssetPath,
    this.onFabPressed,
    this.margin = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
  }) : assert(
          destinations.length >= 2,
          'AppBottomNavigationBar requires at least 2 destinations.',
        );

  /// The regular nav items shown inside the pill bar.
  final List<NavDestination> destinations;

  /// Currently selected tab index (0-based, matching [destinations]).
  final int selectedIndex;

  /// Callback fired when the user taps a nav item.
  final ValueChanged<int> onDestinationSelected;

  /// Optional: SVG asset path for the floating FAB pill (pencil / create).
  /// If null, the FAB is not rendered.
  final String? fabSvgAssetPath;

  /// Optional: Callback fired when the FAB is pressed.
  final VoidCallback? onFabPressed;

  /// Outer margin from screen edges — tweak to taste.
  final EdgeInsets margin;

  @override
  State<AppBottomNavigationBar> createState() =>
      _AppBottomNavigationBarState();
}

class _AppBottomNavigationBarState extends State<AppBottomNavigationBar> {
  // Track which item is being pressed for the tap-scale effect
  int? _pressedIndex;
  bool _fabPressed = false;

  void _handleTapDown(int index) =>
      setState(() => _pressedIndex = index);

  void _handleTapUp(int index) {
    setState(() => _pressedIndex = null);
    widget.onDestinationSelected(index);
  }

  void _handleTapCancel() =>
      setState(() => _pressedIndex = null);

  void _handleFabDown() => setState(() => _fabPressed = true);
  void _handleFabUp() {
    setState(() => _fabPressed = false);
    widget.onFabPressed?.call();
  }
  void _handleFabCancel() => setState(() => _fabPressed = false);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: widget.margin,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Main pill bar ──────────────────────────────────────────────────
          Flexible(
            child: _GlassPill(
              isDark: isDark,
              child: SizedBox(
                height: _NavTokens.barHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _NavTokens.barPaddingH,
                    vertical: _NavTokens.barPaddingV,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(widget.destinations.length, (i) {
                      return Expanded(
                        child: _NavItem(
                          destination: widget.destinations[i],
                          isSelected: widget.selectedIndex == i,
                          isPressed: _pressedIndex == i,
                          isDark: isDark,
                          onTapDown: () => _handleTapDown(i),
                          onTapUp: () => _handleTapUp(i),
                          onTapCancel: _handleTapCancel,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),

          // ── Optional FAB pill ──────────────────────────────────────────────
          if (widget.fabSvgAssetPath != null) ...[
            const SizedBox(width: _NavTokens.fabGap),
            _FabPill(
              svgAssetPath: widget.fabSvgAssetPath!,
              isDark: isDark,
              isPressed: _fabPressed,
              onTapDown: _handleFabDown,
              onTapUp: _handleFabUp,
              onTapCancel: _handleFabCancel,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass pill container — shared by bar and FAB
// ─────────────────────────────────────────────────────────────────────────────

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.isDark,
    required this.child,
    this.radius = _NavTokens.barRadius,
  });

  final bool isDark;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: _NavTokens.shadow(isDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _NavTokens.blurSigma,
            sigmaY: _NavTokens.blurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? _NavTokens.darkFill : _NavTokens.lightFill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: isDark
                    ? _NavTokens.darkBorder
                    : _NavTokens.lightBorder,
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single nav item
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.isPressed,
    required this.isDark,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  final NavDestination destination;
  final bool isSelected;
  final bool isPressed;
  final bool isDark;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected
        ? (isDark ? _NavTokens.iconActiveDark : _NavTokens.iconActiveLight)
        : (isDark ? _NavTokens.iconInactiveDark : _NavTokens.iconInactiveLight);

    return Semantics(
      label: destination.semanticLabel ?? destination.label,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onTapDown(),
        onTapUp: (_) => onTapUp(),
        onTapCancel: onTapCancel,
        child: AnimatedScale(
          scale: isPressed ? 0.88 : 1.0,
          duration: _NavTokens.animDuration,
          curve: _NavTokens.animCurve,
          child: SizedBox(
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Icon ──────────────────────────────────────────────────
                AnimatedScale(
                  scale: isSelected ? 1.08 : 1.0,
                  duration: _NavTokens.animDuration,
                  curve: _NavTokens.animCurve,
                  child: SvgPicture.asset(
                    destination.svgAssetPath,
                    width: _NavTokens.iconSize,
                    height: _NavTokens.iconSize,
                    colorFilter: ColorFilter.mode(
                      iconColor,
                      BlendMode.srcIn,
                    ),
                    semanticsLabel: destination.semanticLabel,
                  ),
                ),
                const SizedBox(height: 5),
                // ── Active dot indicator ──────────────────────────────────
                AnimatedContainer(
                  duration: _NavTokens.animDuration,
                  curve: _NavTokens.animCurve,
                  width: isSelected ? _NavTokens.indicatorWidth : 0,
                  height: _NavTokens.indicatorHeight,
                  decoration: BoxDecoration(
                    color: isDark
                        ? _NavTokens.indicatorDark
                        : _NavTokens.indicatorLight,
                    borderRadius: BorderRadius.circular(
                      _NavTokens.indicatorRadius,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating FAB pill
// ─────────────────────────────────────────────────────────────────────────────

class _FabPill extends StatelessWidget {
  const _FabPill({
    required this.svgAssetPath,
    required this.isDark,
    required this.isPressed,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  final String svgAssetPath;
  final bool isDark;
  final bool isPressed;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Create new note',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onTapDown(),
        onTapUp: (_) => onTapUp(),
        onTapCancel: onTapCancel,
        child: AnimatedScale(
          scale: isPressed ? 0.90 : 1.0,
          duration: _NavTokens.animDuration,
          curve: _NavTokens.animCurve,
          child: _GlassPill(
            isDark: isDark,
            radius: _NavTokens.fabRadius,
            child: SizedBox(
              width: _NavTokens.fabSize,
              height: _NavTokens.fabSize,
              child: Center(
                child: SvgPicture.asset(
                  svgAssetPath,
                  width: _NavTokens.iconSize,
                  height: _NavTokens.iconSize,
                  colorFilter: ColorFilter.mode(
                    isDark
                        ? _NavTokens.iconActiveDark
                        : _NavTokens.iconActiveLight,
                    BlendMode.srcIn,
                  ),
                  semanticsLabel: 'Create',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
