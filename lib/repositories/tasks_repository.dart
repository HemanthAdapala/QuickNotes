import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/task_item.dart';
import '../models/sync_outbox_item.dart';
import '../services/database_service.dart';
import '../services/session_manager.dart';
import '../services/database_exceptions.dart';

abstract class TasksRepository {
  Future<List<TaskItem>> getTasks();
  Future<List<TaskItem>> getTrashTasks();
  Future<List<TaskItem>> getTasksForDate(DateTime date);
  Future<int> insertTask(TaskItem task);
  Future<int> updateTask(TaskItem task);
  Future<int> trashTask(String id);
  Future<int> restoreTask(String id);
  Future<int> deleteTask(String id);
  Future<int> emptyTrash();
  Future<int> generateUniqueNotificationId();
}

class SqliteTasksRepository implements TasksRepository {
  final DatabaseService _dbService;

  SqliteTasksRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  String _resolveActiveUserId() {
    final activeId = SessionManager().activeUserId;
    if (activeId == null || activeId.isEmpty) {
      throw const OwnershipException('No active canonical user exists for this repository operation.');
    }
    return activeId;
  }

  Future<void> _recordOutboxEvent(
    DatabaseExecutor executor, {
    required String userId,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payloadMap,
    required int localVersion,
  }) async {
    final outboxItem = SyncOutboxItem(
      id: const Uuid().v4(),
      operationId: const Uuid().v4(),
      userId: userId,
      entityType: 'task',
      entityId: entityId,
      operation: operation,
      payload: jsonEncode(payloadMap),
      localVersion: localVersion,
      createdAt: DateTime.now(),
    );
    await executor.insert(
      'sync_outbox',
      outboxItem.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<TaskItem>> getTasks() async {
    final uid = _resolveActiveUserId();
    final all = await _dbService.getAllTasks();
    return all.where((t) => t.userId == uid && !t.isDeleted).toList();
  }

  @override
  Future<List<TaskItem>> getTrashTasks() async {
    final uid = _resolveActiveUserId();
    final all = await _dbService.getAllTasks();
    return all.where((t) => t.userId == uid && t.isDeleted).toList();
  }

  @override
  Future<List<TaskItem>> getTasksForDate(DateTime date) async {
    final all = await getTasks();
    final target = DateTime(date.year, date.month, date.day);
    return all.where((t) {
      final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return d.isAtSameMomentAs(target);
    }).toList();
  }

  @override
  Future<int> insertTask(TaskItem task) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final now = DateTime.now();
      final scopedTask = TaskItem(
        id: task.id,
        userId: uid,
        title: task.title,
        description: task.description,
        folderId: task.folderId,
        categoryId: task.categoryId,
        dueDate: task.dueDate,
        startTime: task.startTime,
        endTime: task.endTime,
        priority: task.priority,
        status: task.status,
        createdAt: task.createdAt,
        updatedAt: now,
        completedAt: task.completedAt,
        reminderEnabled: task.reminderEnabled,
        reminderMode: task.reminderMode,
        reminderTime: task.reminderTime,
        notificationId: task.notificationId,
        repeatRule: task.repeatRule,
        isRecurring: task.isRecurring,
        recurrence: task.recurrence,
        recurringSeriesId: task.recurringSeriesId,
        timezone: task.timezone,
        completedDates: task.completedDates,
        isDeleted: task.isDeleted,
        deletedAt: task.deletedAt,
        version: 1,
        lastSyncedVersion: task.lastSyncedVersion,
      );
      await executor.insert(
        'tasks',
        scopedTask.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _recordOutboxEvent(
        executor,
        userId: uid,
        entityId: scopedTask.id,
        operation: 'create',
        payloadMap: scopedTask.toMap(),
        localVersion: 1,
      );
      return 1;
    });
  }

  @override
  Future<int> updateTask(TaskItem task) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existingMap = await executor.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [task.id],
      );
      if (existingMap.isNotEmpty) {
        final ownerId = existingMap.first['userId'] as String?;
        if (ownerId != null && ownerId != uid) {
          throw OwnershipException('Ownership violation: User $uid cannot update task belonging to User $ownerId');
        }
      }
      final currentVersion = existingMap.isNotEmpty ? (existingMap.first['version'] as int? ?? 1) : 1;
      final newVersion = currentVersion + 1;
      final now = DateTime.now();

      final scopedTask = TaskItem(
        id: task.id,
        userId: uid,
        title: task.title,
        description: task.description,
        folderId: task.folderId,
        categoryId: task.categoryId,
        dueDate: task.dueDate,
        startTime: task.startTime,
        endTime: task.endTime,
        priority: task.priority,
        status: task.status,
        createdAt: task.createdAt,
        updatedAt: now,
        completedAt: task.completedAt,
        reminderEnabled: task.reminderEnabled,
        reminderMode: task.reminderMode,
        reminderTime: task.reminderTime,
        notificationId: task.notificationId,
        repeatRule: task.repeatRule,
        isRecurring: task.isRecurring,
        recurrence: task.recurrence,
        recurringSeriesId: task.recurringSeriesId,
        timezone: task.timezone,
        completedDates: task.completedDates,
        isDeleted: task.isDeleted,
        deletedAt: task.deletedAt,
        version: newVersion,
        lastSyncedVersion: task.lastSyncedVersion,
      );
      final count = await executor.update(
        'tasks',
        scopedTask.toMap(),
        where: 'id = ? AND userId = ?',
        whereArgs: [task.id, uid],
      );
      if (count > 0) {
        await _recordOutboxEvent(
          executor,
          userId: uid,
          entityId: scopedTask.id,
          operation: 'update',
          payloadMap: scopedTask.toMap(),
          localVersion: newVersion,
        );
      }
      return count;
    });
  }

  @override
  Future<int> trashTask(String id) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existingMap = await executor.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existingMap.isEmpty) return 0;
      final ownerId = existingMap.first['userId'] as String?;
      if (ownerId != null && ownerId != uid) {
        throw OwnershipException('Ownership violation: User $uid cannot trash task belonging to User $ownerId');
      }
      final existing = TaskItem.fromMap(existingMap.first);
      if (existing.isDeleted) return 1; // Idempotent

      final newVersion = existing.version + 1;
      final trashedTask = existing.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: newVersion,
      );
      await executor.update(
        'tasks',
        trashedTask.toMap(),
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      await _recordOutboxEvent(
        executor,
        userId: uid,
        entityId: id,
        operation: 'update',
        payloadMap: trashedTask.toMap(),
        localVersion: newVersion,
      );
      return 1;
    });
  }

  @override
  Future<int> restoreTask(String id) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existingMap = await executor.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existingMap.isEmpty) return 0;
      final ownerId = existingMap.first['userId'] as String?;
      if (ownerId != null && ownerId != uid) {
        throw OwnershipException('Ownership violation: User $uid cannot restore task belonging to User $ownerId');
      }
      final existing = TaskItem.fromMap(existingMap.first);
      if (!existing.isDeleted) return 1; // Idempotent

      final newVersion = existing.version + 1;
      final restoredTask = existing.copyWith(
        isDeleted: false,
        clearDeletedAt: true,
        updatedAt: DateTime.now(),
        version: newVersion,
      );
      await executor.update(
        'tasks',
        restoredTask.toMap(),
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      await _recordOutboxEvent(
        executor,
        userId: uid,
        entityId: id,
        operation: 'update',
        payloadMap: restoredTask.toMap(),
        localVersion: newVersion,
      );
      return 1;
    });
  }

  @override
  Future<int> deleteTask(String id) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existingMap = await executor.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existingMap.isEmpty) return 0;
      final ownerId = existingMap.first['userId'] as String?;
      if (ownerId != null && ownerId != uid) {
        throw OwnershipException('Ownership violation: User $uid cannot delete task belonging to User $ownerId');
      }
      final existing = TaskItem.fromMap(existingMap.first);

      final count = await executor.delete(
        'tasks',
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );

      // Hard Delete Rule
      if (existing.lastSyncedVersion == 0) {
        await executor.delete(
          'sync_outbox',
          where: 'entityId = ? AND userId = ?',
          whereArgs: [id, uid],
        );
      } else {
        await _recordOutboxEvent(
          executor,
          userId: uid,
          entityId: id,
          operation: 'delete',
          payloadMap: {'id': id, 'version': existing.version},
          localVersion: existing.version,
        );
      }
      return count;
    });
  }

  @override
  Future<int> emptyTrash() async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final trashedMaps = await executor.query(
        'tasks',
        where: 'userId = ? AND isDeleted = 1',
        whereArgs: [uid],
      );
      final trashedTasks = trashedMaps.map((m) => TaskItem.fromMap(m)).toList();

      final res = await executor.delete(
        'tasks',
        where: 'userId = ? AND isDeleted = 1',
        whereArgs: [uid],
      );

      for (final task in trashedTasks) {
        if (task.lastSyncedVersion == 0) {
          await executor.delete(
            'sync_outbox',
            where: 'entityId = ? AND userId = ?',
            whereArgs: [task.id, uid],
          );
        } else {
          await _recordOutboxEvent(
            executor,
            userId: uid,
            entityId: task.id,
            operation: 'delete',
            payloadMap: {'id': task.id, 'version': task.version},
            localVersion: task.version,
          );
        }
      }
      return res;
    });
  }

  @override
  Future<int> generateUniqueNotificationId() async {
    return await _dbService.generateUniqueNotificationId();
  }
}

