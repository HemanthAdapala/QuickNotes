import 'dart:async';
import 'package:flutter/material.dart';
import '../motion/motion_constants.dart';

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

class _AnimatedListEntranceState extends State<AnimatedListEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _translateAnimation;
  Timer? _timer;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: QuickNotesMotion.kMotionPage,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: QuickNotesMotion.kMotionEaseOutCubic,
      ),
    );

    _translateAnimation = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: QuickNotesMotion.kMotionEaseOutCubic,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final bool disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (disableAnimations) {
        _controller.value = 1.0;
      } else {
        final delay = Duration(milliseconds: widget.index * 40);
        _timer = Timer(delay, () {
          if (mounted) {
            _controller.forward();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      return widget.child;
    }

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

