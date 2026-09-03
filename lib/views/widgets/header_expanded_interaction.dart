import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/motion/motion_constants.dart';

/// Reusable interaction barrier and controller for expanded header states.
///
/// Provides:
/// 1. Full-screen outside-tap interception with [HitTestBehavior.opaque].
/// 2. Outside-tap dismissal with ZERO haptic feedback.
/// 3. System back interception via [PopScope].
/// 4. Desktop/web Escape-key dismissal via [CallbackShortcuts].
/// 5. Reduced-motion compliance (snaps to [Duration.zero] when animations are disabled).
/// 6. Complete pointer isolation preventing touches from leaking into underlying content.
class HeaderExpandedInteraction extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onDismiss;
  final Color barrierColor;
  final Widget? child;

  const HeaderExpandedInteraction({
    super.key,
    required this.isExpanded,
    required this.onDismiss,
    this.barrierColor = Colors.transparent,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = MediaQuery.of(context).disableAnimations;
    final Duration duration = disableAnimations
        ? Duration.zero
        : (isExpanded
            ? QuickNotesMotion.kMotionRelease
            : QuickNotesMotion.kMotionMicro);

    return PopScope(
      canPop: !isExpanded,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && isExpanded) {
          onDismiss();
        }
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (isExpanded) {
              onDismiss();
            }
          },
        },
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (child != null) child!,
              IgnorePointer(
                ignoring: !isExpanded,
                child: AnimatedOpacity(
                  duration: duration,
                  curve: QuickNotesMotion.kMotionAppleEase,
                  opacity: isExpanded ? 1.0 : 0.0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDismiss,
                    child: Container(
                      color: barrierColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convenience alias matching architecture documentation.
typedef HeaderActionBackdrop = HeaderExpandedInteraction;
