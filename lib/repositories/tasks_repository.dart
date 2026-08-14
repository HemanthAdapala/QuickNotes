import '../models/task_item.dart';
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
      updatedAt: task.updatedAt,
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
    );
    return await _dbService.insertTask(scopedTask);
  }

  @override
  Future<int> updateTask(TaskItem task) async {
    final uid = _resolveActiveUserId();
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
      updatedAt: DateTime.now(),
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
    );
    return await _dbService.updateTask(scopedTask);
  }

  @override
  Future<int> trashTask(String id) async {
    final uid = _resolveActiveUserId();
    final all = await _dbService.getAllTasks();
    final matches = all.where((t) => t.id == id);
    if (matches.isEmpty) return 0;
    final existing = matches.first;
    if (existing.userId != null && existing.userId != uid) {
      throw OwnershipException('Ownership violation: User $uid cannot trash task belonging to User ${existing.userId}');
    }
    if (existing.isDeleted) return 1; // Idempotent

    final trashedTask = existing.copyWith(
      isDeleted: true,
      deletedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await _dbService.updateTask(trashedTask);
  }

  @override
  Future<int> restoreTask(String id) async {
    final uid = _resolveActiveUserId();
    final all = await _dbService.getAllTasks();
    final matches = all.where((t) => t.id == id);
    if (matches.isEmpty) return 0;
    final existing = matches.first;
    if (existing.userId != null && existing.userId != uid) {
      throw OwnershipException('Ownership violation: User $uid cannot restore task belonging to User ${existing.userId}');
    }
    if (!existing.isDeleted) return 1; // Idempotent

    final restoredTask = existing.copyWith(
      isDeleted: false,
      clearDeletedAt: true,
      updatedAt: DateTime.now(),
    );
    return await _dbService.updateTask(restoredTask);
  }

  @override
  Future<int> deleteTask(String id) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final res = await executor.delete(
        'tasks',
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      return res;
    });
  }

  @override
  Future<int> emptyTrash() async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final res = await executor.delete(
        'tasks',
        where: 'userId = ? AND isDeleted = 1',
        whereArgs: [uid],
      );
      return res;
    });
  }

  @override
  Future<int> generateUniqueNotificationId() async {
    return await _dbService.generateUniqueNotificationId();
  }
}
