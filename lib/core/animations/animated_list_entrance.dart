import 'package:flutter/material.dart';
import 'animation_constants.dart';

class AnimatedListEntrance extends StatefulWidget {
  final Widget child;
  final int index;

  const AnimatedListEntrance({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<AnimatedListEntrance> createState() => _AnimatedListEntranceState();
}

class _AnimatedListEntranceState extends State<AnimatedListEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _translateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: kDurationNormal,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: kCurveEnter),
    );

    _translateAnimation = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: kCurveEnter),
    );

    final delay = Duration(milliseconds: widget.index * 40);
    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0.0, _translateAnimation.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
