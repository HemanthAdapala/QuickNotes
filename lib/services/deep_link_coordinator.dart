import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart' as hw;
import 'package:provider/provider.dart';

import '../core/animations/page_transitions.dart';
import '../models/note.dart';
import '../models/task_item.dart';
import '../models/task_status.dart';
import '../providers/notes_provider.dart';
import '../providers/tasks_provider.dart';
import '../views/screens/create_task_screen.dart';
import '../views/screens/home_screen.dart';
import '../views/screens/note_editor_screen.dart';

/// Supported types of typed internal deep link actions triggered from widgets.
enum DeepLinkActionType {
  openHome,
  newNote,
  openNote,
  newChecklist,
  openTasks,
  openTask,
}

/// Immutable representation of a parsed and validated deep link action.
class DeepLinkAction {
  final DeepLinkActionType type;
  final Map<String, String> queryParameters;

  const DeepLinkAction(this.type, [this.queryParameters = const {}]);

  /// Parses and validates a [Uri] against the strict whitelist of approved actions.
  ///
  /// **Security Guarantee:**
  /// Rejects any unrecognized URI, non-quicknotes scheme, or malformed input.
  /// Never executes arbitrary string commands or raw parameters.
  static DeepLinkAction? parse(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme.toLowerCase() != 'quicknotes') return null;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final params = uri.queryParameters;

    // quicknotes://home or quicknotes:///home
    if (host == 'home' || path == '/home') {
      return DeepLinkAction(DeepLinkActionType.openHome, params);
    }

    // quicknotes://note/new or quicknotes://note/<id> or legacy quicknotes://add?type=text
    if (host == 'note') {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty || segments.first == 'new') {
        if (segments.length <= 1) {
          return DeepLinkAction(DeepLinkActionType.newNote, params);
        }
      } else if (segments.length == 1) {
        final noteId = segments.first.trim();
        if (noteId.isNotEmpty) {
          final mergedParams = Map<String, String>.from(params);
          mergedParams['noteId'] = noteId;
          return DeepLinkAction(DeepLinkActionType.openNote, mergedParams);
        }
      }
      return null;
    }

    if (host == 'add' && params['type'] == 'text') {
      return DeepLinkAction(DeepLinkActionType.newNote, params);
    }

    // quicknotes://checklist/new or legacy quicknotes://add?type=checklist
    if (host == 'checklist') {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty || (segments.length == 1 && segments.first == 'new')) {
        return DeepLinkAction(DeepLinkActionType.newChecklist, params);
      }
      return null;
    }

    if (host == 'add' && params['type'] == 'checklist') {
      return DeepLinkAction(DeepLinkActionType.newChecklist, params);
    }

    // quicknotes://task/<taskId>
    if (host == 'task') {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length == 1) {
        final taskId = segments.first.trim();
        if (taskId.isNotEmpty) {
          final mergedParams = Map<String, String>.from(params);
          mergedParams['taskId'] = taskId;
          return DeepLinkAction(DeepLinkActionType.openTask, mergedParams);
        }
      }
      return null;
    }

    // quicknotes://tasks or quicknotes:///tasks
    if (host == 'tasks' || path == '/tasks') {
      return DeepLinkAction(DeepLinkActionType.openTasks, params);
    }

    // Strictly reject any unknown action
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeepLinkAction &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          mapEquals(queryParameters, other.queryParameters);

  @override
  int get hashCode => Object.hash(
        type,
        Object.hashAllUnordered(
          queryParameters.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  @override
  String toString() => 'DeepLinkAction($type, params: $queryParameters)';
}

/// DeepLinkCoordinator — Orchestrates widget deep-link events across the app lifecycle.
///
/// **Lifecycle & Readiness Guarantees:**
/// 1. Captures cold-launch URIs on app startup without race conditions.
/// 2. Listens for warm widget click events while the app is running in the background.
/// 3. Buffers pending actions while the app is booting, in onboarding, or behind PasscodeLock.
/// 4. Dispatches the buffered action ONLY once the app is unlocked and navigation-ready.
class DeepLinkCoordinator {
  static final DeepLinkCoordinator _instance = DeepLinkCoordinator._internal();
  factory DeepLinkCoordinator() => _instance;
  static DeepLinkCoordinator get instance => _instance;

  DeepLinkCoordinator._internal();

  DeepLinkAction? _pendingAction;
  bool _isInitialized = false;
  bool _isNavigationReady = false;
  StreamSubscription<Uri?>? _widgetClickedSubscription;
  void Function(DeepLinkAction action)? _onActionDispatched;

  /// Retrieves the current pending action, if any.
  DeepLinkAction? get pendingAction => _pendingAction;

  /// Whether the coordinator has completed initialization.
  bool get isInitialized => _isInitialized;

  /// Whether the app UI has settled and is ready to process navigations.
  bool get isNavigationReady => _isNavigationReady;

  /// Initializes the coordinator for both cold-launch and warm-launch listeners.
  Future<void> initialize({
    Future<Uri?> Function()? initialUriProvider,
    Stream<Uri?>? uriStream,
    void Function(DeepLinkAction)? onActionDispatched,
  }) async {
    if (onActionDispatched != null) {
      _onActionDispatched = onActionDispatched;
    }
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Cold Launch: Check if the app was launched by tapping a Home Screen Widget
    try {
      final initialUriFetcher =
          initialUriProvider ?? hw.HomeWidget.initiallyLaunchedFromHomeWidget;
      final initialUri = await initialUriFetcher();
      debugPrint('DeepLinkCoordinator: initiallyLaunchedFromHomeWidget = $initialUri');
      if (initialUri != null) {
        final action = DeepLinkAction.parse(initialUri);
        debugPrint('DeepLinkCoordinator: parsed cold action = $action');
        if (action != null) {
          _pendingAction = action;
        }
      }
    } catch (e) {
      debugPrint(
          'DeepLinkCoordinator: Failed to check initial widget launch: $e');
    }

    // 2. Warm Launch: Listen for widget click events while app is running/backgrounded
    final stream = uriStream ?? hw.HomeWidget.widgetClicked;
    _widgetClickedSubscription = stream.listen((uri) {
      debugPrint('DeepLinkCoordinator: widgetClicked stream received uri = $uri');
      if (uri != null) {
        final action = DeepLinkAction.parse(uri);
        debugPrint('DeepLinkCoordinator: parsed warm action = $action');
        if (action != null) {
          handleIncomingAction(action);
        }
      }
    });
  }

  /// Sets a pending action directly (useful for tests and manual deep-link dispatch).
  void setPendingAction(DeepLinkAction? action) {
    _pendingAction = action;
  }

  /// Consumes and clears the current pending action.
  DeepLinkAction? consumePendingAction() {
    final action = _pendingAction;
    _pendingAction = null;
    return action;
  }

  /// Called when an incoming action arrives during runtime.
  void handleIncomingAction(DeepLinkAction action) {
    debugPrint('DeepLinkCoordinator: handleIncomingAction = $action, _isNavigationReady = $_isNavigationReady');
    if (_isNavigationReady) {
      _onActionDispatched?.call(action);
    } else {
      _pendingAction = action;
    }
  }

  /// Marks the app as navigation-ready (e.g. after splash resolution and passcode unlock).
  /// If a pending action exists, it is dispatched immediately.
  Future<void> markNavigationReady({BuildContext? context}) async {
    _isNavigationReady = true;
    debugPrint('DeepLinkCoordinator: markNavigationReady called. pendingAction = $_pendingAction, context mounted = ${context?.mounted}');
    if (_pendingAction != null) {
      final action = consumePendingAction()!;
      debugPrint('DeepLinkCoordinator: executing pending action = $action');
      if (context != null && context.mounted) {
        await executeAction(context, action);
      } else {
        _onActionDispatched?.call(action);
      }
    }
  }

  /// Marks the app as locked or not ready (e.g. when app lock is engaged).
  void markNavigationNotReady() {
    _isNavigationReady = false;
  }

  /// Executes navigation for the given [DeepLinkAction] using standard app routes.
  Future<void> executeAction(BuildContext context, DeepLinkAction action) async {
    debugPrint('DeepLinkCoordinator: executeAction type = ${action.type}, params = ${action.queryParameters}');
    if (!context.mounted) return;

    switch (action.type) {
      case DeepLinkActionType.newNote:
        Navigator.of(context).push(
          buildPageRoute(const NoteEditorScreen(defaultNoteType: 'text')),
        );
        break;

      case DeepLinkActionType.newChecklist:
        Navigator.of(context).push(
          buildPageRoute(const NoteEditorScreen(defaultNoteType: 'checklist')),
        );
        break;

      case DeepLinkActionType.openTasks:
        Navigator.of(context).pushAndRemoveUntil(
          buildPageRoute(const HomeScreen()),
          (route) => false,
        );
        break;

      case DeepLinkActionType.openNote:
        final noteId = action.queryParameters['noteId'];
        debugPrint('DeepLinkCoordinator: resolving note with ID = $noteId');
        if (noteId != null && noteId.isNotEmpty) {
          try {
            final notesProvider =
                Provider.of<NotesProvider>(context, listen: false);

            // 1. Authoritative lookup: First check in-memory allActiveNotes, or query repository directly
            Note? targetNote;
            final inMemory =
                notesProvider.allActiveNotes.where((n) => n.id == noteId);
            if (inMemory.isNotEmpty) {
              targetNote = inMemory.first;
              debugPrint('DeepLinkCoordinator: found note in memory: ${targetNote.title}');
            } else {
              targetNote = await notesProvider.getNoteById(noteId);
              debugPrint('DeepLinkCoordinator: fetched note from repository: ${targetNote?.title}');
            }

            // 2. Strict Security Validation: !isDeleted && !isArchived && !isLocked
            if (targetNote != null &&
                !targetNote.isDeleted &&
                !targetNote.isArchived &&
                !targetNote.isLocked) {
              if (context.mounted) {
                debugPrint('DeepLinkCoordinator: pushing NoteEditorScreen for ${targetNote.title}');
                Navigator.of(context).push(
                  buildPageRoute(NoteEditorScreen(note: targetNote)),
                );
              }
              break;
            } else {
              debugPrint('DeepLinkCoordinator: Note validation rejected. targetNote = $targetNote, isDeleted = ${targetNote?.isDeleted}, isArchived = ${targetNote?.isArchived}, isLocked = ${targetNote?.isLocked}');
            }
          } catch (e) {
            debugPrint('DeepLinkCoordinator: Failed to find note $noteId: $e');
          }
        }
        // Fallback to HomeScreen if note is not found, locked, archived, or deleted
        if (context.mounted) {
          debugPrint('DeepLinkCoordinator: Falling back to HomeScreen');
          Navigator.of(context).pushAndRemoveUntil(
            buildPageRoute(const HomeScreen()),
            (route) => false,
          );
        }
        break;

      case DeepLinkActionType.openTask:
        final taskId = action.queryParameters['taskId'];
        debugPrint('DeepLinkCoordinator: resolving task with ID = $taskId');
        if (taskId != null && taskId.isNotEmpty) {
          try {
            final tasksProvider =
                Provider.of<TasksProvider>(context, listen: false);
            await tasksProvider.loadTasks();

            // 1. Authoritative lookup: First check in-memory tasks, or query engine directly
            TaskItem? targetTask;
            final inMemory =
                tasksProvider.tasks.where((t) => t.id == taskId);
            if (inMemory.isNotEmpty) {
              targetTask = inMemory.first;
              debugPrint('DeepLinkCoordinator: found task in memory: ${targetTask.title}');
            } else {
              targetTask = tasksProvider.engine.getTaskById(taskId);
              debugPrint('DeepLinkCoordinator: fetched task from engine: ${targetTask?.title}');
            }

            // 2. Strict Security & Lifecycle Validation: !isDeleted && status != TaskStatus.archived
            if (targetTask != null &&
                !targetTask.isDeleted &&
                targetTask.status != TaskStatus.archived) {
              if (context.mounted) {
                debugPrint('DeepLinkCoordinator: pushing TaskEditorScreen for ${targetTask.title}');
                Navigator.of(context).push(
                  buildPageRoute(TaskEditorScreen(
                    initialDate: targetTask.dueDate,
                    taskToEdit: targetTask,
                  )),
                );
              }
              break;
            } else {
              debugPrint('DeepLinkCoordinator: Task validation rejected. targetTask = $targetTask, isDeleted = ${targetTask?.isDeleted}, status = ${targetTask?.status}');
            }
          } catch (e) {
            debugPrint('DeepLinkCoordinator: Failed to find task $taskId: $e');
          }
        }
        // Fallback to HomeScreen if task is not found, archived, or deleted
        if (context.mounted) {
          debugPrint('DeepLinkCoordinator: Falling back to HomeScreen');
          Navigator.of(context).pushAndRemoveUntil(
            buildPageRoute(const HomeScreen()),
            (route) => false,
          );
        }
        break;

      case DeepLinkActionType.openHome:
        Navigator.of(context).pushAndRemoveUntil(
          buildPageRoute(const HomeScreen()),
          (route) => false,
        );
        break;
    }
  }

  /// Disposes active subscriptions.
  void dispose() {
    _widgetClickedSubscription?.cancel();
    _widgetClickedSubscription = null;
    _isInitialized = false;
    _isNavigationReady = false;
    _pendingAction = null;
    _onActionDispatched = null;
  }
}
