import '../models/task_item.dart';
import '../services/database_service.dart';

abstract class TasksRepository {
  Future<List<TaskItem>> getTasks();
  Future<List<TaskItem>> getTasksForDate(DateTime date);
  Future<int> insertTask(TaskItem task);
  Future<int> updateTask(TaskItem task);
  Future<int> deleteTask(String id);
  Future<int> generateUniqueNotificationId();
}

class SqliteTasksRepository implements TasksRepository {
  final DatabaseService _dbService;

  SqliteTasksRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<List<TaskItem>> getTasks() async {
    return await _dbService.getAllTasks();
  }

  @override
  Future<List<TaskItem>> getTasksForDate(DateTime date) async {
    return await _dbService.getTasksForDate(date);
  }

  @override
  Future<int> insertTask(TaskItem task) async {
    return await _dbService.insertTask(task);
  }

  @override
  Future<int> updateTask(TaskItem task) async {
    return await _dbService.updateTask(task);
  }

  @override
  Future<int> deleteTask(String id) async {
    return await _dbService.deleteTask(id);
  }

  @override
  Future<int> generateUniqueNotificationId() async {
    return await _dbService.generateUniqueNotificationId();
  }
}
