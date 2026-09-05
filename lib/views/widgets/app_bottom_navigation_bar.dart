import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/animations/animation_constants.dart';
import '../../core/motion/motion_constants.dart';
import '../../core/motion/quick_notes_haptics.dart';
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
                        // Physical active tab indicator pill with liquid stretch (Phase P1-A)
                        if (selectedIndex < 4)
                          _PhysicalActiveIndicator(
                            selectedIndex: selectedIndex,
                            scale: scale,
                            activeColor:
                                activeColor ?? const Color(0xFFFFCC00),
                            disableAnimations:
                                MediaQuery.of(context).disableAnimations,
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
                              selectedColor:
                                  Colors.white, // Active icon changes to white
                              unselectedColor:
                                  const Color(0xFF333333), // Inactive is 333333
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
                      unselectedColor:
                          const Color(0xFF333333), // Inactive FAB is 333333
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

class BottomBarGlassSurface extends StatefulWidget {
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
  State<BottomBarGlassSurface> createState() => _BottomBarGlassSurfaceState();
}

class _BottomBarGlassSurfaceState extends State<BottomBarGlassSurface>
    with SingleTickerProviderStateMixin {
  AnimationController? _refreshController;
  Animation<double>? _refreshAnimation;
  Animation<double>? _routeAnimation;
  bool _hasInvalidatedPostTransition = false;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
    _refreshAnimation = Tween<double>(begin: 0.999, end: 1.0).animate(
      CurvedAnimation(parent: _refreshController!, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToRouteAnimation();
  }

  void _subscribeToRouteAnimation() {
    final route = ModalRoute.of(context);
    final animation = route?.animation;

    if (animation != _routeAnimation) {
      _removeRouteListener();
      _routeAnimation = animation;
      if (_routeAnimation != null) {
        if (_routeAnimation!.isCompleted) {
          _triggerBackdropRefresh();
        } else {
          _hasInvalidatedPostTransition = false;
          _routeAnimation!.addStatusListener(_handleAnimationStatusChange);
        }
      }
    }
  }

  void _removeRouteListener() {
    if (_routeAnimation != null) {
      _routeAnimation!.removeStatusListener(_handleAnimationStatusChange);
      _routeAnimation = null;
    }
  }

  void _handleAnimationStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _removeRouteListener();
      _triggerBackdropRefresh();
    }
  }

  void _triggerBackdropRefresh() {
    if (_hasInvalidatedPostTransition) return;
    _hasInvalidatedPostTransition = true;
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _refreshController != null) {
          _refreshController!.forward(from: 0.0);
        }
      });
    }
  }

  @override
  void dispose() {
    _removeRouteListener();
    _refreshController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _refreshAnimation ?? const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        return Transform.scale(
          scale: _refreshAnimation?.value ?? 1.0,
          child: child,
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: GlassmorphismPresets.shadows,
        ),
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: GlassmorphismPresets.blurSigma,
              sigmaY: GlassmorphismPresets.blurSigma,
            ),
            child: CustomPaint(
              foregroundPainter: _InnerGlassBorderPainter(
                borderRadius: widget.borderRadius,
              ),
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: GlassmorphismPresets.fillColor,
                    borderRadius: widget.borderRadius,
                    boxShadow: GlassmorphismPresets.innerShadows,
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: widget.useFrost ? 0.65 : 0.45,
                      ),
                      width: 0.8,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(
                          alpha: widget.useFrost ? 0.85 : 0.72,
                        ),
                        Colors.white.withValues(
                          alpha: widget.useFrost ? 0.45 : 0.0,
                        ),
                        scheme.surfaceTint.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.035),
                      ],
                      stops: const [0, 0.42, 0.78, 1],
                    ),
                  ),
                  child: widget.child,
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
    _scaleController.duration = QuickNotesMotion.kMotionMicro;
    setState(() {
      _scaleAnimation = Tween<double>(
        begin: _scaleAnimation.value,
        end: 0.94,
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
    _scaleController.duration = QuickNotesMotion.kMotionRelease;
    setState(() {
      _scaleAnimation = Tween<double>(
        begin: _scaleAnimation.value,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutCubic,
      ));
    });
    _scaleController.forward(from: 0.0);
  }

  void _handleTap(bool reduceMotion) {
    // Play semantic navigation haptic tick ONLY when destination changes,
    // or buttonPress for FAB action
    if (widget.index != widget.selectedIndex) {
      QuickNotesHaptics.navigationSelection();
    } else if (widget.index == 4) {
      QuickNotesHaptics.buttonPress();
    }

    if (reduceMotion) {
      widget.onDestinationSelected(widget.index);
      return;
    }

    // Refined spring return sequence (0.94 -> 1.018 -> 1.000) over 190ms
    _scaleController.stop();
    _scaleController.duration = QuickNotesMotion.kMotionRelease;
    setState(() {
      _scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: _scaleAnimation.value, end: 1.018)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 60,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.018, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 40,
        ),
      ]).animate(_scaleController);
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
                            colorFilter:
                                ColorFilter.mode(color, BlendMode.srcIn),
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

/// Phase P1-A: Dedicated physical active tab indicator with liquid horizontal stretch.
///
/// Implements physical travel with damped spring overshoot and temporary
/// horizontal expansion (up to +8.0 * scale) during mid-flight, returning
/// symmetrically to exact 70px resting geometry on arrival.
class _PhysicalActiveIndicator extends StatefulWidget {
  final int selectedIndex;
  final double scale;
  final Color activeColor;
  final bool disableAnimations;

  const _PhysicalActiveIndicator({
    required this.selectedIndex,
    required this.scale,
    required this.activeColor,
    required this.disableAnimations,
  });

  @override
  State<_PhysicalActiveIndicator> createState() =>
      _PhysicalActiveIndicatorState();
}

class _PhysicalActiveIndicatorState extends State<_PhysicalActiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _springAnimation;
  int _previousIndex = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.selectedIndex;
    _currentIndex = widget.selectedIndex;
    _controller = AnimationController(
      vsync: this,
      duration: QuickNotesMotion.kMotionSelection,
    );
    _springAnimation = CurvedAnimation(
      parent: _controller,
      curve: QuickNotesMotion.kMotionSpring,
    );
  }

  @override
  void didUpdateWidget(covariant _PhysicalActiveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != _currentIndex && widget.selectedIndex < 4) {
      _previousIndex = _currentIndex;
      _currentIndex = widget.selectedIndex;
      if (widget.disableAnimations) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getCenterForIndex(int index) {
    return (40.0 + index * (184.0 / 3.0)) * widget.scale;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.disableAnimations) {
      final double center = _getCenterForIndex(widget.selectedIndex);
      final double width = 70.0 * widget.scale;
      final double height = 43.0 * widget.scale;
      final double left = center - (width / 2.0);
      final double top = widget.scale * (50.0 - 43.0) / 2.0;

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: GlassSurface(
          key: const ValueKey('physical_active_indicator'),
          borderRadius: BorderRadius.circular(21.5 * widget.scale),
          customTintColor: widget.activeColor,
          child: const SizedBox.expand(),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double tLinear = _controller.value;
        final double tSpring = _springAnimation.value;

        final double startCenter = _getCenterForIndex(_previousIndex);
        final double targetCenter = _getCenterForIndex(_currentIndex);

        // Position interpolation using physical spring with subtle overshoot
        final double currentCenter =
            startCenter + (targetCenter - startCenter) * tSpring;

        // Liquid stretch: expands horizontally during flight, peaking at midpoint (sin(pi * t))
        // Returns exactly to 0.0 additional width at rest (t = 1.0 and t = 0.0)
        final double stretchFactor = sin(tLinear * pi);
        final double additionalWidth = (_previousIndex == _currentIndex)
            ? 0.0
            : stretchFactor * (8.0 * widget.scale);

        final double currentWidth = (70.0 * widget.scale) + additionalWidth;
        final double currentHeight = 43.0 * widget.scale;

        // Symmetrical centering around current physical position
        final double left = currentCenter - (currentWidth / 2.0);
        final double top = widget.scale * (50.0 - 43.0) / 2.0;

        return Positioned(
          left: left,
          top: top,
          width: currentWidth,
          height: currentHeight,
          child: GlassSurface(
            key: const ValueKey('physical_active_indicator'),
            borderRadius: BorderRadius.circular(21.5 * widget.scale),
            customTintColor: widget.activeColor,
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

