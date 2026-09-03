import 'package:flutter/services.dart';

/// Central semantic haptic gateway for Quick Notes.
///
/// Enforces semantic ownership of tactile feedback and prevents accidental
/// duplicate triggers across layered widgets.
class QuickNotesHaptics {
  QuickNotesHaptics._();

  /// Optional listener hook for testing and telemetry.
  static void Function(String method)? debugHapticListener;

  /// Fired when the user changes navigation destination (e.g. Bottom Navigation Tab).
  ///
  /// Represents exactly one intentional navigation event.
  static Future<void> navigationSelection() async {
    debugHapticListener?.call('navigationSelection');
    await HapticFeedback.selectionClick();
  }

  /// Fired when the user toggles a segmented control or filter chip (e.g. Notes ↔ Tasks).
  static Future<void> selection() async {
    debugHapticListener?.call('selection');
    await HapticFeedback.selectionClick();
  }

  /// Fired when the user physically presses down on a primary interactive control (e.g. Prompt CTA).
  static Future<void> buttonPress() async {
    debugHapticListener?.call('buttonPress');
    await HapticFeedback.selectionClick();
  }

  /// Fired on subtle physical arrival or snap settle.
  static Future<void> subtleSettle() async {
    debugHapticListener?.call('subtleSettle');
    await HapticFeedback.lightImpact();
  }
}
