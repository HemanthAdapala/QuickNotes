import 'dart:ui';

import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter/services.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/animations/animation_constants.dart';
import '../../themes/glassmorphism_presets.dart';
import 'glass_container.dart';
import '../constants/app_bottom_navigation_assets.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.destinations = AppBottomNavigationDestination.defaults,
    this.activeColor,
  })  : assert(destinations.length == 5),
        assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppBottomNavigationDestination> destinations;
  final Color? activeColor;

  static const double _figmaWidth = 318;
  static const double _barWidth = 264;
  static const double _height = 58;
  static const double _controlHeight = 50;
  static const double _gap = 4;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: _height + bottomInset,
      child: Align(
        alignment: Alignment.topCenter,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth <= 32
                ? constraints.maxWidth
                : constraints.maxWidth - 32;
            final scale =
                (availableWidth / _figmaWidth).clamp(0.0, 1.0).toDouble();
            final width = _figmaWidth * scale;

            return SizedBox(
              width: width,
              height: _height * scale,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BottomBarGlassSurface(
                    width: _barWidth * scale,
                    height: _controlHeight * scale,
                    borderRadius: BorderRadius.circular(25 * scale),
                    child: Stack(
                      children: [
                        // Sliding active tab indicator pill (Change 3)
                        if (selectedIndex < 4)
                          AnimatedPositioned(
                            duration: kDurationNormal,
                            curve: Curves.easeInOutCubic,
                            left: (40.0 + selectedIndex * (184.0 / 3.0) - 35.0) * scale,
                            top: scale * (50.0 - 43.0) / 2.0,
                            width: 70.0 * scale,
                            height: 43.0 * scale,
                            child: GlassSurface(
                              borderRadius: BorderRadius.circular(21.5 * scale),
                              customTintColor: activeColor ?? const Color(0xFFFFCC00),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        // Navigation buttons
                        for (var index = 0; index < 4; index++)
                          Positioned(
                            left: (40.0 + index * (184.0 / 3.0) - 35.0) * scale,
                            top: 0,
                            width: 70.0 * scale,
                            height: 50.0 * scale,
                            child: _NavigationButton(
                              destination: destinations[index],
                              index: index,
                              selectedIndex: selectedIndex,
                              onDestinationSelected: onDestinationSelected,
                              iconSize: 22 * scale,
                              selectedColor: Colors.white, // Active icon changes to white
                              unselectedColor: const Color(0xFF333333), // Inactive is 333333
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: _gap * scale),
                  BottomBarGlassSurface(
                    width: _controlHeight * scale,
                    height: _controlHeight * scale,
                    borderRadius: BorderRadius.circular(25 * scale),
                    child: _NavigationButton(
                      destination: destinations[4],
                      index: 4,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                      iconSize: 22 * scale,
                      selectedColor: Colors.white, // Active FAB is white
                      unselectedColor: const Color(0xFF333333), // Inactive FAB is 333333
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class AppBottomNavigationDestination {
  const AppBottomNavigationDestination({
    required this.iconAsset,
    required this.label,
  });

  final String iconAsset;
  final String label;

  static const List<AppBottomNavigationDestination> defaults = [
    AppBottomNavigationDestination(
      iconAsset: AppBottomNavigationAssets.home,
      label: 'Home',
    ),
    AppBottomNavigationDestination(
      iconAsset: AppBottomNavigationAssets.folderOpen,
      label: 'Folders',
    ),
    AppBottomNavigationDestination(
      iconAsset: AppBottomNavigationAssets.calendarPen,
      label: 'Calendar',
    ),
    AppBottomNavigationDestination(
      iconAsset: AppBottomNavigationAssets.settings,
      label: 'Settings',
    ),
    AppBottomNavigationDestination(
      iconAsset: AppBottomNavigationAssets.pencil,
      label: 'Create note',
    ),
  ];
}

class BottomBarGlassSurface extends StatelessWidget {
  const BottomBarGlassSurface({
    super.key,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.child,
    this.useFrost = false,
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;
  final Widget child;
  final bool useFrost;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: GlassmorphismPresets.shadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: RepaintBoundary(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: GlassmorphismPresets.blurSigma,
              sigmaY: GlassmorphismPresets.blurSigma,
            ),
            child: CustomPaint(
              foregroundPainter: _InnerGlassBorderPainter(
                borderRadius: borderRadius,
              ),
              child: SizedBox(
                width: width,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: GlassmorphismPresets.fillColor,
                    borderRadius: borderRadius,
                    boxShadow: GlassmorphismPresets.innerShadows,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: useFrost ? 0.65 : 0.45),
                      width: 0.8,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: useFrost ? 0.85 : 0.72),
                        Colors.white.withValues(alpha: useFrost ? 0.45 : 0.0),
                        scheme.surfaceTint.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.035),
                      ],
                      stops: const [0, 0.42, 0.78, 1],
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationButton extends StatefulWidget {
  const _NavigationButton({
    required this.destination,
    required this.index,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.iconSize,
    required this.selectedColor,
    required this.unselectedColor,
  });

  final AppBottomNavigationDestination destination;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final double iconSize;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  State<_NavigationButton> createState() => _NavigationButtonState();
}

class _NavigationButtonState extends State<_NavigationButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this);
    _scaleAnimation = const AlwaysStoppedAnimation<double>(1.0);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(bool reduceMotion) {
    if (reduceMotion) return;
    _scaleController.stop();
    _scaleController.duration = const Duration(milliseconds: 80);
    setState(() {
      _scaleAnimation = Tween<double>(
        begin: _scaleAnimation.value,
        end: 0.7,
      ).animate(CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeIn,
      ));
    });
    _scaleController.forward(from: 0.0);
  }

  void _handleTapCancel(bool reduceMotion) {
    if (reduceMotion) return;
    _scaleController.stop();
    _scaleController.duration = const Duration(milliseconds: 1000);
    setState(() {
      _scaleAnimation = Tween<double>(
        begin: _scaleAnimation.value,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ));
    });
    _scaleController.forward(from: 0.0);
  }

  void _handleTap(bool reduceMotion) {
    if (reduceMotion) {
      widget.onDestinationSelected(widget.index);
      return;
    }

    // Play haptic tick
    HapticFeedback.selectionClick();

    // Scale spring animation sequence
    _scaleController.stop();
    _scaleController.duration = const Duration(milliseconds: 1000);
    setState(() {
      _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(
          parent: _scaleController,
          curve: Curves.elasticOut,
        ),
      );
    });
    _scaleController.forward(from: 0.0);

    // Trigger tab navigation selection
    widget.onDestinationSelected(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selectedIndex == widget.index;
    final color = isSelected ? widget.selectedColor : widget.unselectedColor;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      selected: isSelected,
      label: widget.destination.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _handleTapDown(reduceMotion),
        onTapCancel: () => _handleTapCancel(reduceMotion),
        onTap: () => _handleTap(reduceMotion),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 48.0,
            minHeight: 48.0,
          ),
          child: AnimatedBuilder(
            animation: _scaleController,
            builder: (context, child) {
              final currentScale = reduceMotion ? 1.0 : _scaleAnimation.value;
              return Center(
              child: Transform.scale(
                scale: currentScale,
                child: AnimatedSwitcher(
                  duration: kDurationNormal,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: (widget.index == 4 && widget.selectedIndex == 1)
                      ? Icon(
                          Icons.add_rounded,
                          key: const ValueKey('plus_icon'),
                          size: widget.iconSize,
                          color: color,
                        )
                      : SvgPicture.asset(
                          widget.destination.iconAsset,
                          key: ValueKey(isSelected),
                          width: widget.iconSize,
                          height: widget.iconSize,
                          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                        ),
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}

class _InnerGlassBorderPainter extends CustomPainter {
  const _InnerGlassBorderPainter({required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // Flat Apple Liquid Glass - Bevel and 3D inner borders disabled (bevelStyle = 0.0)
    return;
  }

  @override
  bool shouldRepaint(_InnerGlassBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius;
  }
}
