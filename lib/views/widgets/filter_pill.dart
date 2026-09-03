import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/motion/motion_constants.dart';

/// Phase P2.4 — Home Filter Pill Tactile & Motion Component
///
/// Encapsulates isolated tactile touch-down micro-compression (1.000 -> 0.960),
/// Apple-style animated indicator dot scaling/fade, tap gesture semantics,
/// and reduced-motion accessibility.
class FilterPill extends StatefulWidget {
  final String filter;
  final String text;
  final bool isSelected;
  final Color dotColor;
  final VoidCallback onTap;

  const FilterPill({
    required this.filter,
    required this.text,
    required this.isSelected,
    required this.dotColor,
    required this.onTap,
    super.key,
  });

  @override
  State<FilterPill> createState() => FilterPillState();
}

class FilterPillState extends State<FilterPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @visibleForTesting
  AnimationController get scaleController => _scaleController;

  @visibleForTesting
  Animation<double> get scaleAnimation => _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: QuickNotesMotion.kMotionMicro, // 90ms
      reverseDuration: QuickNotesMotion.kMotionRelease, // 190ms
    );
    _scaleAnimation = Tween<double>(begin: 1.000, end: 0.960).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOut,
      ),
    );
  }

  bool _disableAnimations = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.of(context).disableAnimations;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!mounted || _disableAnimations) return;
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!mounted || _disableAnimations) return;
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    if (!mounted || _disableAnimations) return;
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = MediaQuery.of(context).disableAnimations;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 40.0px Pill Container with isolated paint-only Transform.scale
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              final double scale =
                  disableAnimations ? 1.000 : _scaleAnimation.value;
              return Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: child,
              );
            },
            child: Container(
              height: 40.0,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              decoration: BoxDecoration(
                color: const Color(0x33787878),
                borderRadius: BorderRadius.circular(20.0),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.text,
                style: GoogleFonts.inter(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected
                      ? const Color(0xFF333333)
                      : const Color(0x80333333),
                  height: 1.38,
                  letterSpacing: -0.43,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4.0),
          // 5.0px Selection Indicator Dot with Apple-style ease animation
          AnimatedScale(
            scale: widget.isSelected ? 1.0 : 0.0,
            duration: disableAnimations
                ? Duration.zero
                : QuickNotesMotion.kMotionSelection,
            curve: QuickNotesMotion.kMotionAppleEase,
            child: AnimatedOpacity(
              opacity: widget.isSelected ? 1.0 : 0.0,
              duration: disableAnimations
                  ? Duration.zero
                  : QuickNotesMotion.kMotionSelection,
              curve: QuickNotesMotion.kMotionAppleEase,
              child: Container(
                width: 5.0,
                height: 5.0,
                decoration: ShapeDecoration(
                  color: widget.dotColor,
                  shape: const OvalBorder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
