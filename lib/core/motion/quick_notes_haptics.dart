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
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Fired when the user toggles a segmented control or filter chip (e.g. Notes ↔ Tasks).
  static Future<void> selection() async {
    debugHapticListener?.call('selection');
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Fired when the user physically presses down on a primary interactive control (e.g. Prompt CTA).
  static Future<void> buttonPress() async {
    debugHapticListener?.call('buttonPress');
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Fired on subtle physical arrival or snap settle.
  static Future<void> subtleSettle() async {
    debugHapticListener?.call('subtleSettle');
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Fired on irreversible or destructive actions (e.g. permanent delete note/folder/account, clear cache).
  static Future<void> destructiveAction() async {
    debugHapticListener?.call('destructiveAction');
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Fired when an operation fails, validation rejects, or passcode is invalid.
  static Future<void> errorAlert() async {
    debugHapticListener?.call('errorAlert');
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  /// Fired when a task or checklist item transitions to completed state.
  static Future<void> taskCompletion() async {
    debugHapticListener?.call('taskCompletion');
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Fired when dragging hits a boundary, snap point, or reorder index threshold.
  static Future<void> dragBoundary() async {
    debugHapticListener?.call('dragBoundary');
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }
}
