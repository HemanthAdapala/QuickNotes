import 'dart:ui';

import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';

import '../../themes/glassmorphism_presets.dart';
import '../constants/app_bottom_navigation_assets.dart';
import 'quick_notes_liquid_glass_tab_bar.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.destinations = AppBottomNavigationDestination.defaults,
    this.activeColor,
    this.folderModeActive = false,
    this.onFabPressed,
  })  : assert(destinations.length == 5),
        assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppBottomNavigationDestination> destinations;
  final Color? activeColor;
  final bool folderModeActive;
  final VoidCallback? onFabPressed;

  static const double figmaWidth = 318;
  static const double barWidth = 264;
  static const double height = 58;
  static const double controlHeight = 50;
  static const double gap = 4;

  static const double _figmaWidth = figmaWidth;
  static const double _height = height;
  static const double _controlHeight = controlHeight;

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
              height: _controlHeight * scale,
              child: QuickNotesLiquidGlassTabBar(
                key: const ValueKey('quick_notes_tab_bar_recreation'),
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                folderModeActive: folderModeActive || selectedIndex == 1,
                onFabPressed: onFabPressed,
                activeColor: activeColor,
                width: width,
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
