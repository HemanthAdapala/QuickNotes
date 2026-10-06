import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/motion/quick_notes_haptics.dart';
import 'quick_notes_liquid_glass_button.dart';

/// Production 44×44 circular Liquid Glass Back Button.
///
/// Encapsulates the validated [QuickNotesLiquidGlassButton] physics with
/// exact 44.0 × 44.0 circular geometry (rest radius = 22.0px) and a 22.0 × 22.0
/// `angle_left.svg` chevron.
///
/// Provides:
/// - Single glass surface (no nested [BottomBarGlassSurface]).
/// - Single interactive touch controller via [LiquidGlassFlexDriver] (no [TactileButton]).
/// - Automatic dark/light theme resolution (or explicit override).
/// - Exactly one intentional haptic pulse on activation via [QuickNotesHaptics.buttonPress].
/// - Semantic button role and accessibility label ('Back').
class QuickNotesLiquidGlassBackButton extends StatelessWidget {
  const QuickNotesLiquidGlassBackButton({
    super.key,
    required this.onPressed,
    this.isDark,
    this.enableFlex = true,
    this.childFollow = 0.0,
    this.enabled = true,
    this.semanticLabel = 'Back',
    this.playHaptic = true,
  });

  /// Action executed when the button is tapped.
  final VoidCallback? onPressed;

  /// Explicit theme override. When null, resolves automatically from [Theme.of(context)].
  final bool? isDark;

  /// Whether the LiquidGlassFlex press & stretch physics are active.
  final bool enableFlex;

  /// Content follow factor during directional pull (0.0 to 1.0).
  final double childFollow;

  /// Whether the button responds to interaction.
  final bool enabled;

  /// Accessibility semantic label.
  final String semanticLabel;

  /// Whether to emit an intentional [QuickNotesHaptics.buttonPress] on activation.
  final bool playHaptic;

  static const double buttonDimension = 44.0;
  static const double iconDimension = 22.0;

  @override
  Widget build(BuildContext context) {
    final bool effectiveIsDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final bool isActionable = enabled && onPressed != null;

    return QuickNotesLiquidGlassButton(
      width: buttonDimension,
      height: buttonDimension,
      isDark: effectiveIsDark,
      enableFlex: enableFlex,
      childFollow: childFollow,
      enabled: isActionable,
      semanticLabel: semanticLabel,
      onTap: () {
        if (playHaptic && isActionable) {
          QuickNotesHaptics.buttonPress();
        }
        onPressed?.call();
      },
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/angle_left.svg',
          width: iconDimension,
          height: iconDimension,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(
            effectiveIsDark
                ? const Color(0xFFFFFFFF)
                : const Color(0xFF1C1C1E),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
