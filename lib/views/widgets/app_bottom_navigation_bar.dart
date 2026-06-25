import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    final scheme = Theme.of(context).colorScheme;

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
                              selectedColor: scheme.onSurface,
                              unselectedColor:
                                  scheme.onSurface.withOpacity(0.62),
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
                      selectedColor: scheme.onSurface,
                      unselectedColor: scheme.onSurface.withOpacity(0.72),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.34),
            blurRadius: 18,
            offset: const Offset(-4, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: CustomPaint(
            foregroundPainter: _InnerGlassBorderPainter(
              borderRadius: borderRadius,
            ),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: scheme.surface.withOpacity(0.28),
                borderRadius: borderRadius,
                border: Border.all(
                  color: Colors.white.withOpacity(0.34),
                  width: 0.8,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.46),
                    Colors.white.withOpacity(0.16),
                    scheme.surfaceTint.withOpacity(0.08),
                  ],
                  stops: const [0, 0.56, 1],
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

class _NavigationButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    final color = isSelected ? selectedColor : unselectedColor;

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onDestinationSelected(index);
          },
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              scale: isSelected ? 1.08 : 1,
              child: SvgPicture.asset(
                destination.iconAsset,
                width: iconSize,
                height: iconSize,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
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
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(1);

    final topHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xB3FFFFFF),
          Color(0x00FFFFFF),
        ],
      ).createShader(rect);

    final lowerShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00000000),
          Color(0x26000000),
        ],
      ).createShader(rect);

    canvas
      ..drawRRect(rrect, topHighlight)
      ..drawRRect(rrect.deflate(1), lowerShadow);
  }

  @override
  bool shouldRepaint(_InnerGlassBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius;
  }
}
