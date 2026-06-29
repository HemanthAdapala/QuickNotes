import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/animations/animation_constants.dart';
import '../../themes/glassmorphism_presets.dart';
import '../constants/app_bottom_navigation_assets.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.destinations = AppBottomNavigationDestination.defaults,
  })  : assert(destinations.length == 5),
        assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppBottomNavigationDestination> destinations;

  static const double _figmaWidth = 356;
  static const double _barWidth = 284;
  static const double _height = 68;
  static const double _controlHeight = 60;
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GlassSurface(
                    width: _barWidth * scale,
                    height: _controlHeight * scale,
                    borderRadius: BorderRadius.circular(30 * scale),
                    child: Stack(
                      children: [
                        // Sliding active tab indicator pill (Change 3)
                        if (selectedIndex < 4)
                          AnimatedPositioned(
                            duration: kDurationNormal,
                            curve: Curves.easeInOutCubic,
                            left: scale * (8.0 + selectedIndex * 67.0 + (67.0 - 62.0) / 2.0),
                            top: scale * (_controlHeight - 48.0) / 2.0,
                            width: 62.0 * scale,
                            height: 48.0 * scale,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5A623),
                                borderRadius: BorderRadius.circular(24.0 * scale),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8.0 * scale,
                                    offset: Offset(0, 4.0 * scale),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Navigation buttons
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0 * scale),
                          child: Row(
                            children: [
                              for (var index = 0; index < 4; index++)
                                Expanded(
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
                      ],
                    ),
                  ),
                  SizedBox(width: _gap * scale),
                  _GlassSurface(
                    width: _controlHeight * scale,
                    height: _controlHeight * scale,
                    borderRadius: BorderRadius.circular(30 * scale),
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

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.child,
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;
  final Widget child;

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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
          child: CustomPaint(
            foregroundPainter: _InnerGlassBorderPainter(
              borderRadius: borderRadius,
            ),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: GlassmorphismPresets.fillColor,
                borderRadius: borderRadius,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.30),
                  width: 0.8,
                ),
                gradient: LinearGradient(
                  begin: const Alignment(-0.45, -0.8),
                  end: const Alignment(0.45, 0.8),
                  colors: [
                    Colors.white.withValues(alpha: 0.72),
                    Colors.white.withValues(alpha: 0.0),
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

  late AnimationController _dotController;
  late Animation<double> _dotAnimation;

  static const List<Offset> _dotDirections = [
    Offset(0.951, 0.309),   // 18 degrees
    Offset(0.000, 1.000),   // 90 degrees
    Offset(-0.951, 0.309),  // 162 degrees
    Offset(-0.588, -0.809), // 234 degrees
    Offset(0.588, -0.809),  // 306 degrees
  ];

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this);
    _scaleAnimation = const AlwaysStoppedAnimation<double>(1.0);

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _dotAnimation = _dotController;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _dotController.dispose();
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

    // Emit particle dots
    _dotController.forward(from: 0.0);

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
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleController, _dotController]),
          builder: (context, child) {
            final currentScale = reduceMotion ? 1.0 : _scaleAnimation.value;
            return Center(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Transform.scale(
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
                      child: SvgPicture.asset(
                        widget.destination.iconAsset,
                        key: ValueKey(isSelected),
                        width: widget.iconSize,
                        height: widget.iconSize,
                        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                      ),
                    ),
                  ),
                  if (!reduceMotion)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _DotBurstPainter(
                            progress: _dotAnimation.value,
                            directions: _dotDirections,
                            scale: widget.iconSize / 22.0,
                          ),
                        ),
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

class _DotBurstPainter extends CustomPainter {
  _DotBurstPainter({
    required this.progress,
    required this.directions,
    required this.scale,
  });

  final double progress;
  final List<Offset> directions;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFF5A623).withValues(alpha: 1.0 - progress)
      ..style = PaintingStyle.fill;

    final currentRadius = 40.0 * scale * Curves.easeOut.transform(progress);
    final dotRadius = 2.0 * scale; // 4px diameter, so 2px radius

    for (final dir in directions) {
      final dotOffset = center + dir * currentRadius;
      canvas.drawCircle(dotOffset, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_DotBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.scale != scale;
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
