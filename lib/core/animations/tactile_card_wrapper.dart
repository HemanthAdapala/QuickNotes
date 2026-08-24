import 'package:flutter/material.dart';
import 'animation_constants.dart';

class TactileCardWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const TactileCardWrapper({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<TactileCardWrapper> createState() => _TactileCardWrapperState();
}

class _TactileCardWrapperState extends State<TactileCardWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: kDurationCardPress,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _controller,
        curve: kCurveExit,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _controller.animateTo(1.0,
            duration: kDurationCardPress, curve: kCurveExit);
      },
      onTapUp: (_) {
        _controller.animateTo(0.0,
            duration: kDurationCardRelease, curve: kCurveEnter);
        widget.onTap();
      },
      onTapCancel: () {
        _controller.animateTo(0.0,
            duration: kDurationCardRelease, curve: kCurveEnter);
      },
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
