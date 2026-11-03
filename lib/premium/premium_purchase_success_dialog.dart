import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/motion/motion_constants.dart';
import '../views/widgets/tactile_button.dart';
import 'premium_entitlement_manager.dart';
import 'feature_access.dart';

/// PremiumPurchaseSuccessCoordinator
///
/// Ensures exactly-once celebration presentation per purchase transaction.
/// Prevents repeated celebrations across replayed callbacks, widget rebuilds,
/// route updates, or restore events.
class PremiumPurchaseSuccessCoordinator {
  static const int _maxTrackedCelebrations = 100;
  static final List<String> _celebratedOrder = <String>[];
  static final Set<String> _celebratedTransactionIds = <String>{};
  static bool _hasCelebratedSession = false;

  /// Returns true if this [transactionId] (or this session if null) has already been celebrated.
  static bool hasCelebrated(String? transactionId) {
    if (transactionId != null && transactionId.isNotEmpty) {
      return _celebratedTransactionIds.contains(transactionId);
    }
    return _hasCelebratedSession;
  }

  /// Records that the [transactionId] (or session) has been celebrated.
  static void markCelebrated(String? transactionId) {
    if (transactionId != null && transactionId.isNotEmpty) {
      if (!_celebratedTransactionIds.contains(transactionId)) {
        if (_celebratedOrder.length >= _maxTrackedCelebrations) {
          final oldest = _celebratedOrder.removeAt(0);
          _celebratedTransactionIds.remove(oldest);
        }
        _celebratedOrder.add(transactionId);
        _celebratedTransactionIds.add(transactionId);
      }
    }
    _hasCelebratedSession = true;
  }

  /// Unmarks celebration if presentation failed before display.
  static void unmarkCelebrated(String? transactionId) {
    if (transactionId != null && transactionId.isNotEmpty) {
      _celebratedTransactionIds.remove(transactionId);
      _celebratedOrder.remove(transactionId);
    } else {
      _hasCelebratedSession = false;
    }
  }

  /// Clears in-memory celebration records. Visible for testing.
  @visibleForTesting
  static void reset() {
    _celebratedTransactionIds.clear();
    _celebratedOrder.clear();
    _hasCelebratedSession = false;
  }
}

/// Presents the dedicated Premium Purchase Success modal dialog.
///
/// Guaranteed conditions:
/// 1. Authoritative entitlement state must confirm Premium is active.
/// 2. The transaction must not have been previously celebrated.
/// 3. Exactly one modal instance is presented per transaction.
Future<void> showPremiumPurchaseSuccessDialog({
  required BuildContext context,
  String? transactionId,
  VoidCallback? onDismissed,
}) async {
  if (!context.mounted) return;

  // Guard 1: Exactly-once celebration per transaction
  if (PremiumPurchaseSuccessCoordinator.hasCelebrated(transactionId)) {
    return;
  }

  // Guard 2: Authoritative entitlement confirmation
  bool isPremiumActive = false;
  try {
    final featureAccess = Provider.of<FeatureAccess>(context, listen: false);
    isPremiumActive = featureAccess.isPremiumActive;
  } catch (_) {
    try {
      final manager =
          Provider.of<PremiumEntitlementManager>(context, listen: false);
      isPremiumActive = manager.isPremiumActive;
    } catch (_) {
      isPremiumActive = PremiumEntitlementManager().isPremiumActive;
    }
  }

  if (!isPremiumActive) {
    // Never show success celebration without authoritative active entitlement
    return;
  }

  if (!context.mounted) return;

  // Mark celebrated before presenting to prevent race conditions from concurrent callbacks
  PremiumPurchaseSuccessCoordinator.markCelebrated(transactionId);

  try {
    HapticFeedback.mediumImpact();
  } catch (_) {}

  try {
    return await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => PremiumPurchaseSuccessDialog(
        transactionId: transactionId,
        onDismissed: onDismissed,
      ),
    );
  } catch (e) {
    // If showDialog fails because navigator is not ready or route unmounted,
    // unmark so this legitimate success can be presented when ready.
    PremiumPurchaseSuccessCoordinator.unmarkCelebrated(transactionId);
    rethrow;
  }
}

/// PremiumPurchaseSuccessDialog
///
/// A polished, rewarding celebration modal for newly verified and persisted
/// Quick Notes Premium purchases.
class PremiumPurchaseSuccessDialog extends StatefulWidget {
  final String? transactionId;
  final VoidCallback? onDismissed;

  const PremiumPurchaseSuccessDialog({
    super.key,
    this.transactionId,
    this.onDismissed,
  });

  @override
  State<PremiumPurchaseSuccessDialog> createState() =>
      _PremiumPurchaseSuccessDialogState();
}

class _PremiumPurchaseSuccessDialogState
    extends State<PremiumPurchaseSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _sparkleAnimation;
  bool _hasDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: QuickNotesMotion.kMotionEaseOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isReducedMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (isReducedMotion) {
      _controller.value = 1.0;
    } else if (!_controller.isAnimating && _controller.value == 0.0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    if (_hasDismissed) return;
    _hasDismissed = true;

    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    widget.onDismissed?.call();

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReducedMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // Palette aligned with Quick Notes design system
    final cardBg = isDark ? const Color(0xFF1F2430) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF312E81).withValues(alpha: 0.40)
        : const Color(0xFFE5E7EB);
    final textPrimary =
        isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1C1C1E);
    final textSecondary =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final pillBg =
        isDark ? const Color(0xFF282F3E) : const Color(0xFFF3F4F6);
    final pillBorder = isDark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);

    final content = Container(
      width: 330,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Tasteful Emblem with Restrained Sparkles ──────────────────────
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glowing backdrop circle
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),

                // Top-right Sparkle
                Positioned(
                  top: 2,
                  right: 4,
                  child: AnimatedBuilder(
                    animation: _sparkleAnimation,
                    builder: (context, child) {
                      final scale = isReducedMotion
                          ? 1.0
                          : _sparkleAnimation.value;
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFF59E0B),
                      size: 18,
                    ),
                  ),
                ),

                // Bottom-left Sparkle
                Positioned(
                  bottom: 4,
                  left: 2,
                  child: AnimatedBuilder(
                    animation: _sparkleAnimation,
                    builder: (context, child) {
                      final scale = isReducedMotion
                          ? 1.0
                          : _sparkleAnimation.value;
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFA78BFA),
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Heading ───────────────────────────────────────────────────────
          Text(
            "You're Premium!",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),

          // ── Supporting Copy ───────────────────────────────────────────────
          Text(
            "Your Quick Notes experience just got better.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // ── Clear Statement that Premium is Enabled ───────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pillBorder, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF34C759),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "All premium features and themes are now unlocked.",
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── Primary Action: "Let's go" ─────────────────────────────────────
          TactileButton(
            useAppleSpring: true,
            onTap: _handleDismiss,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "Let's go",
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: isReducedMotion
          ? content
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: content,
            ),
    );
  }
}
