import 'package:flutter/material.dart';
import '../../widgets/quick_notes_glass_action_morph.dart';

/// Enumeration of actions available from the Settings More Options surface.
///
/// Represents purely the identity/meaning of Settings-specific actions.
/// The execution of these actions is owned entirely by the Settings layer.
enum SettingsMoreOptionsAction {
  deleteData,
  refresh,
}

/// Helper for constructing Settings-specific action definitions for the
/// [QuickNotesGlassActionMorph] visual presentation component.
class SettingsMoreOptionsActions {
  const SettingsMoreOptionsActions._();

  /// Builds the list of [QuickNotesGlassAction] specifications for Settings.
  static List<QuickNotesGlassAction<SettingsMoreOptionsAction>> buildActions({
    Color? deleteColor,
    Color? refreshColor,
  }) {
    return <QuickNotesGlassAction<SettingsMoreOptionsAction>>[
      QuickNotesGlassAction<SettingsMoreOptionsAction>(
        id: SettingsMoreOptionsAction.deleteData,
        label: 'Delete Data',
        iconPath: 'assets/icons/trash.svg',
        textColor: deleteColor,
        iconColor: deleteColor,
        isDestructive: true,
      ),
      QuickNotesGlassAction<SettingsMoreOptionsAction>(
        id: SettingsMoreOptionsAction.refresh,
        label: 'Refresh',
        iconPath: 'assets/icons/refresh.svg',
        textColor: refreshColor,
        iconColor: refreshColor,
      ),
    ];
  }
}
