import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double compressionScale;
  final Duration pressDuration;
  final Duration settleDuration;
  final bool useAppleSpring;
  final bool playSelectionHaptic;

  const TactileButton({
    super.key,
    required this.child,
    required this.onTap,
    this.compressionScale = 0.97,
    this.pressDuration = const Duration(milliseconds: 100),
    this.settleDuration = const Duration(milliseconds: 100),
    this.useAppleSpring = false,
    this.playSelectionHaptic = false,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> with TickerProviderStateMixin {
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
      _scaleAnimation = Tween<double>(begin: 1.0, end: widget.compressionScale).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn),
      );
    } else {
      _scaleAnimation = Tween<double>(begin: 1.0, end: widget.compressionScale).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
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
    if (widget.playSelectionHaptic) {
      HapticFeedback.selectionClick();
    }
    _controller.stop();
    _controller.duration = widget.pressDuration;
    _controller.forward();
  }

  void _handleTapUp() {
    _controller.stop();
    if (widget.useAppleSpring) {
      _controller.duration = widget.settleDuration;
      setState(() {
        _scaleAnimation = Tween<double>(begin: widget.compressionScale, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
        );
      });
      _controller.forward(from: 0.0);
    } else {
      _controller.duration = widget.settleDuration;
      _controller.reverse();
    }
    widget.onTap();
  }

  void _handleTapCancel() {
    _controller.stop();
    if (widget.useAppleSpring) {
      _controller.duration = widget.settleDuration;
      setState(() {
        _scaleAnimation = Tween<double>(begin: widget.compressionScale, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
        );
      });
      _controller.forward(from: 0.0);
    } else {
      _controller.duration = widget.settleDuration;
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _handleTapDown(),
      onTapUp: (_) => _handleTapUp(),
      onTapCancel: () => _handleTapCancel(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
