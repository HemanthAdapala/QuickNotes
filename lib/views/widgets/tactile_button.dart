import 'package:flutter/material.dart';
import '../../core/motion/motion_constants.dart';
import '../../core/motion/quick_notes_haptics.dart';

class TactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final double compressionScale;
  final Duration pressDuration;
  final Duration settleDuration;
  final bool useAppleSpring;
  final bool playSelectionHaptic;
  final bool enabled;

  const TactileButton({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPressStart,
    this.compressionScale = 0.94,
    this.pressDuration = QuickNotesMotion.kMotionMicro,
    this.settleDuration = QuickNotesMotion.kMotionRelease,
    this.useAppleSpring = true,
    this.playSelectionHaptic = true,
    this.enabled = true,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _setupAnimation();
  }

  void _setupAnimation() {
    if (widget.useAppleSpring) {
      _scaleAnimation =
          Tween<double>(begin: 1.0, end: widget.compressionScale).animate(
        CurvedAnimation(
          parent: _controller,
          curve: QuickNotesMotion.kMotionAppleEase,
        ),
      );
    } else {
      _scaleAnimation =
          Tween<double>(begin: 1.0, end: widget.compressionScale).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant TactileButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.compressionScale != widget.compressionScale ||
        oldWidget.useAppleSpring != widget.useAppleSpring) {
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown() {
    if (!widget.enabled) return;

    if (widget.playSelectionHaptic) {
      QuickNotesHaptics.buttonPress();
    }
    _controller.stop();
    _controller.duration = widget.pressDuration;
    _controller.forward();
  }

  void _handleTapUp() {
    if (!widget.enabled) return;

    _controller.stop();
    _controller.duration = widget.settleDuration;
    if (widget.useAppleSpring) {
      setState(() {
        _scaleAnimation =
            Tween<double>(begin: _scaleAnimation.value, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: QuickNotesMotion.kMotionSpring,
          ),
        );
      });
      _controller.forward(from: 0.0);
    } else {
      _controller.reverse();
    }
    widget.onTap();
  }

  void _handleTapCancel() {
    if (!widget.enabled) return;

    _controller.stop();
    _controller.duration = widget.settleDuration;
    if (widget.useAppleSpring) {
      setState(() {
        _scaleAnimation =
            Tween<double>(begin: _scaleAnimation.value, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: QuickNotesMotion.kMotionSpring,
          ),
        );
      });
      _controller.forward(from: 0.0);
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = MediaQuery.of(context).disableAnimations;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _handleTapDown(),
      onTapUp: (_) => _handleTapUp(),
      onTapCancel: () => _handleTapCancel(),
      onLongPressStart: widget.enabled ? widget.onLongPressStart : null,
      child: ScaleTransition(
        scale: disableAnimations
            ? const AlwaysStoppedAnimation<double>(1.0)
            : _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
