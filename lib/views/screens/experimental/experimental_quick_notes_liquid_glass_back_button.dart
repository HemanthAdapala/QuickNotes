import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/quick_notes_liquid_glass_button.dart';

/// Experimental Lab-Only Circular Back Button Adapter for LB-R5 validation.
///
/// Wraps the already-validated [QuickNotesLiquidGlassButton] constrained to
/// the 44x44 circular geometry required by Quick Notes.
///
/// CRITICAL ARCHITECTURAL CONSTRAINTS:
/// - LAB-ONLY experimentation code.
/// - NOT a production component.
/// - Must NOT be used in production screens or AppHeaderBar yet.
/// - Does NOT contain Navigator logic or screen-specific business logic.
/// - Retains 100% of the validated Stage 2 LiquidGlassFlexDriver physics.
class ExperimentalQuickNotesLiquidGlassBackButton extends StatelessWidget {
  /// Generic tap callback (action-agnostic, defaults to a no-op in the lab).
  final VoidCallback? onPressed;

  /// Theme brightness toggle (light vs dark mode glass and icon tint).
  final bool isDark;

  /// Whether the button responds to gestures.
  final bool enabled;

  /// Whether soft-body LiquidGlassFlexDriver press + drag deformation is active.
  final bool enableFlex;

  /// Content follow ratio for the interior icon (defaults to 0.0 for anchored icon).
  final double childFollow;

  /// Explicit accessibility label (defaults to 'Back').
  final String semanticLabel;

  /// Optional icon color override. Defaults to white in dark mode, near-black in light mode.
  final Color? iconColor;

  const ExperimentalQuickNotesLiquidGlassBackButton({
    super.key,
    this.onPressed,
    this.isDark = false,
    this.enabled = true,
    this.enableFlex = true,
    this.childFollow = 0.0,
    this.semanticLabel = 'Back',
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        iconColor ?? (isDark ? Colors.white : const Color(0xFF1C1C1E));

    return QuickNotesLiquidGlassButton(
      width: 44.0,
      height: 44.0,
      isDark: isDark,
      enabled: enabled,
      enableFlex: enableFlex,
      childFollow: childFollow,
      semanticLabel: semanticLabel,
      onTap: onPressed ?? () {},
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/angle_left.svg',
          width: 22.0,
          height: 22.0,
          colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
        ),
      ),
    );
  }
}
