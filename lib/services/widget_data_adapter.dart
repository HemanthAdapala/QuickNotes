import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart' as hw;

import '../models/note.dart';
import '../models/single_note_snapshot.dart';
import '../models/single_task_snapshot.dart';
import '../models/task_item.dart';
import '../models/task_status.dart';
import '../models/widget_snapshot_payload.dart';
import 'session_manager.dart';

typedef SaveWidgetDataFunction = Future<bool?> Function(
    String key, dynamic value);
typedef UpdateWidgetFunction = Future<bool?> Function({
  String? name,
  String? androidName,
  String? iOSName,
  String? qualifiedAndroidName,
});

/// WidgetDataAdapter — Central service responsible for constructing, sanitizing,
/// and publishing public aggregate snapshots to platform shared storage (HomeWidget).
///
/// **Privacy & Security Contract:**
/// 1. Excludes locked / vault notes (`isLocked == true`) unconditionally.
/// 2. Excludes trashed / deleted notes (`isDeleted == true`) and tasks (`isDeleted == true`).
/// 3. Excludes archived tasks (`status == TaskStatus.archived`).
/// 4. Emits ONLY aggregate statistics (pinned count, pending tasks, overdue tasks)
///    and localized date strings for the aggregate widget.
/// 5. Publishes dedicated single-note and single-task catalogs & snapshot maps
///    for configurable native home screen widgets.
/// 6. Contains ZERO user credentials, emails, passwords, or vault keys.
class WidgetDataAdapter {
  static final WidgetDataAdapter _instance = WidgetDataAdapter._internal();
  factory WidgetDataAdapter() => _instance;
  static WidgetDataAdapter get instance => _instance;

  WidgetDataAdapter._internal()
      : _sessionManager = SessionManager(),
        _saveData = hw.HomeWidget.saveWidgetData,
        _updateWidget = hw.HomeWidget.updateWidget;

  /// Visible for testing constructor with dependency injection.
  @visibleForTesting
  WidgetDataAdapter.custom({
    SessionManager? sessionManager,
    SaveWidgetDataFunction? saveData,
    UpdateWidgetFunction? updateWidget,
  })  : _sessionManager = sessionManager ?? SessionManager(),
        _saveData = saveData ?? hw.HomeWidget.saveWidgetData,
        _updateWidget = updateWidget ?? hw.HomeWidget.updateWidget;

  final SessionManager _sessionManager;
  final SaveWidgetDataFunction _saveData;
  final UpdateWidgetFunction _updateWidget;

  // Cached state to allow independent note or task updates
  List<Note> _lastNotes = const [];
  List<TaskItem> _lastTasks = const [];

  /// Default widget provider names matching native platform targets.
  static const String androidWidgetName = 'QuickCaptureWidget';
  static const String singleNoteWidgetName = 'SingleNoteWidget';
  static const String singleTaskWidgetName = 'SingleTaskWidget';
  static const String singleTaskLongWidgetName = 'SingleTaskLongWidget';
  static const String multiTaskWidgetName = 'MultiTaskWidget';
  static const String iOSWidgetName = 'QuickNotesWidget';
  static const String appGroupId = 'group.com.quicknotes.app';
  static const String notesCatalogKey = 'quicknotes_notes_catalog';
  static const String notesMapKey = 'quicknotes_notes_map';
  static const String tasksCatalogKey = 'quicknotes_tasks_catalog';
  static const String tasksMapKey = 'quicknotes_tasks_map';

  /// Sets the iOS App Group ID.
  Future<void> initializeAppGroup() async {
    try {
      await hw.HomeWidget.setAppGroupId(appGroupId);
    } catch (e) {
      debugPrint('WidgetDataAdapter: Failed to set App Group ID: $e');
    }
  }

  /// Builds a sanitized [WidgetSnapshotPayload] from raw notes and tasks lists.
  WidgetSnapshotPayload buildSnapshot({
    List<Note>? notes,
    List<TaskItem>? tasks,
    DateTime? now,
    bool? hasActiveSession,
  }) {
    final effectiveNotes = notes ?? _lastNotes;
    final effectiveTasks = tasks ?? _lastTasks;
    final currentTime = now ?? DateTime.now();
    final localTime = currentTime.toLocal();

    final sessionActive = hasActiveSession ?? _sessionManager.isLoggedIn;

    if (!sessionActive) {
      return WidgetSnapshotPayload.empty(now: currentTime);
    }

    // 1. Calculate Pinned Notes (STRICT PRIVACY: Exclude locked and deleted notes)
    final pinnedCount = effectiveNotes.where((note) {
      return note.isPinned &&
          !note.isLocked &&
          !note.isDeleted &&
          !note.isArchived;
    }).length;

    // 2. Calculate Task Metrics
    final todayStart = DateTime(localTime.year, localTime.month, localTime.day);
    final todayEnd = DateTime(
        localTime.year, localTime.month, localTime.day, 23, 59, 59, 999);

    int pendingTodayCount = 0;
    int overdueCount = 0;

    for (final task in effectiveTasks) {
      if (task.completed || task.isDeleted || task.status == TaskStatus.archived) continue;

      final dueLocal = task.dueDate.toLocal();
      if (dueLocal.isBefore(todayStart)) {
        overdueCount++;
      } else if ((dueLocal.isAfter(
                  todayStart.subtract(const Duration(milliseconds: 1))) ||
              dueLocal.isAtSameMomentAs(todayStart)) &&
          (dueLocal.isBefore(todayEnd) ||
              dueLocal.isAtSameMomentAs(todayEnd))) {
        pendingTodayCount++;
      }
    }

    // 3. Format Localized Date Display Strings
    final dateDayName = DateFormat('EEEE').format(localTime);
    final dateFormatted = DateFormat('d MMM').format(localTime);

    return WidgetSnapshotPayload(
      version: 1,
      updatedAt: currentTime.toUtc(),
      dateDayName: dateDayName,
      dateFormatted: dateFormatted,
      pinnedNotesCount: pinnedCount,
      pendingTasksCount: pendingTodayCount,
      overdueTasksCount: overdueCount,
      hasActiveSession: true,
    );
  }

  /// Synchronizes the latest widget snapshot with platform shared storage (HomeWidget).
  ///
  /// This method isolates all errors to ensure a widget update failure NEVER
  /// interferes with primary note or task saving in the database.
  Future<bool> sync({
    List<Note>? notes,
    List<TaskItem>? tasks,
    DateTime? now,
    bool? hasActiveSession,
  }) async {
    if (notes != null) _lastNotes = List.unmodifiable(notes);
    if (tasks != null) _lastTasks = List.unmodifiable(tasks);

    try {
      final payload = buildSnapshot(
        notes: notes,
        tasks: tasks,
        now: now,
        hasActiveSession: hasActiveSession,
      );

      final jsonString = payload.toJsonString();

      // Write full JSON contract payload
      await _saveData(WidgetSnapshotPayload.storageKey, jsonString);

      // Write legacy key for backwards compatibility with Android skeleton widget
      await _saveData('pinned_count', payload.pinnedNotesCount.toString());
      await _saveData('pending_tasks_count', payload.pendingTasksCount);

      final sessionActive = hasActiveSession ?? _sessionManager.isLoggedIn;

      // 1. Write SingleNoteWidget catalog and snapshots for active unlocked notes
      if (sessionActive && _lastNotes.isNotEmpty) {
        final activeUnlockedNotes = _lastNotes
            .where((n) => !n.isLocked && !n.isDeleted && !n.isArchived)
            .toList();

        final catalogList = <Map<String, dynamic>>[];
        final noteMap = <String, Map<String, dynamic>>{};

        for (final note in activeUnlockedNotes) {
          final snapshot = SingleNoteSnapshot.fromNote(note, now: now);
          catalogList.add(snapshot.toCatalogEntry());
          noteMap[note.id] = snapshot.toJson();
        }

        await _saveData(notesCatalogKey, jsonEncode(catalogList));
        await _saveData(notesMapKey, jsonEncode(noteMap));
      } else {
        await _saveData(notesCatalogKey, '[]');
        await _saveData(notesMapKey, '{}');
      }

      // 2. Write Task Widgets catalog and snapshots for active non-deleted/non-archived tasks
      if (sessionActive && _lastTasks.isNotEmpty) {
        final activeTasks = _lastTasks
            .where((t) => !t.isDeleted && t.status != TaskStatus.archived)
            .toList();

        final taskCatalogList = <Map<String, dynamic>>[];
        final taskMap = <String, Map<String, dynamic>>{};

        for (final task in activeTasks) {
          final snapshot = SingleTaskSnapshot.fromTask(task, now: now);
          taskCatalogList.add(snapshot.toCatalogEntry());
          taskMap[task.id] = snapshot.toJson();
        }

        await _saveData(tasksCatalogKey, jsonEncode(taskCatalogList));
        await _saveData(tasksMapKey, jsonEncode(taskMap));
      } else {
        await _saveData(tasksCatalogKey, '[]');
        await _saveData(tasksMapKey, '{}');
      }

      // Request native widget timeline reloads
      await _updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        iOSName: iOSWidgetName,
      );

      await _updateWidget(
        name: singleNoteWidgetName,
        androidName: singleNoteWidgetName,
      );

      await _updateWidget(
        name: singleTaskWidgetName,
        androidName: singleTaskWidgetName,
      );

      await _updateWidget(
        name: singleTaskLongWidgetName,
        androidName: singleTaskLongWidgetName,
      );

      await _updateWidget(
        name: multiTaskWidgetName,
        androidName: multiTaskWidgetName,
      );

      return true;
    } catch (e) {
      debugPrint('WidgetDataAdapter.sync error (isolated): $e');
      return false;
    }
  }

  /// Clears the widget snapshot on logout or account deletion.
  Future<bool> clearSnapshot({DateTime? now}) async {
    _lastNotes = const [];
    _lastTasks = const [];

    try {
      final emptyPayload = WidgetSnapshotPayload.empty(now: now);
      await _saveData(
          WidgetSnapshotPayload.storageKey, emptyPayload.toJsonString());
      await _saveData('pinned_count', '0');
      await _saveData('pending_tasks_count', 0);
      await _saveData(notesCatalogKey, '[]');
      await _saveData(notesMapKey, '{}');
      await _saveData(tasksCatalogKey, '[]');
      await _saveData(tasksMapKey, '{}');

      await _updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        iOSName: iOSWidgetName,
      );

      await _updateWidget(
        name: singleNoteWidgetName,
        androidName: singleNoteWidgetName,
      );

      await _updateWidget(
        name: singleTaskWidgetName,
        androidName: singleTaskWidgetName,
      );

      await _updateWidget(
        name: singleTaskLongWidgetName,
        androidName: singleTaskLongWidgetName,
      );

      await _updateWidget(
        name: multiTaskWidgetName,
        androidName: multiTaskWidgetName,
      );
      return true;
    } catch (e) {
      debugPrint('WidgetDataAdapter.clearSnapshot error: $e');
      return false;
    }
  }
}
