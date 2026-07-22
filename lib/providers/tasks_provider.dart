import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task_item.dart';
import '../repositories/tasks_repository.dart';

class TasksProvider with ChangeNotifier {
  final TasksRepository _tasksRepository;
  List<TaskItem> _tasks = [];
  bool _isLoading = false;
  final _uuid = const Uuid();

  TasksProvider({TasksRepository? tasksRepository})
      : _tasksRepository = tasksRepository ?? SqliteTasksRepository() {
    loadTasks();
  }

  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  List<TaskItem> get activeTasks => _tasks.where((t) => !t.completed).toList();
  List<TaskItem> get completedTasks => _tasks.where((t) => t.completed).toList();
  bool get isLoading => _isLoading;

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tasks = await _tasksRepository.getTasks();
    } catch (e) {
      debugPrint("Error loading tasks: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTask({
    required String title,
    String description = '',
    required DateTime dueDate,
    required String priority,
    DateTime? reminderTime,
  }) async {
    final newTask = TaskItem(
      id: _uuid.v4(),
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      completed: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      reminderTime: reminderTime,
    );

    _tasks.insert(0, newTask);
    notifyListeners();

    try {
      await _tasksRepository.insertTask(newTask);
    } catch (e) {
      debugPrint("Error inserting task: $e");
      _tasks.removeWhere((t) => t.id == newTask.id);
      notifyListeners();
    }
  }

  Future<void> toggleTaskCompletion(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final task = _tasks[index];
    final updated = task.copyWith(
      completed: !task.completed,
      updatedAt: DateTime.now(),
    );

    _tasks[index] = updated;
    notifyListeners();

    try {
      await _tasksRepository.updateTask(updated);
    } catch (e) {
      debugPrint("Error updating task completion: $e");
      _tasks[index] = task;
      notifyListeners();
    }
  }

  Future<void> updateTask(TaskItem updatedTask) async {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index == -1) return;

    final oldTask = _tasks[index];
    _tasks[index] = updatedTask;
    notifyListeners();

    try {
      await _tasksRepository.updateTask(updatedTask);
    } catch (e) {
      debugPrint("Error updating task: $e");
      _tasks[index] = oldTask;
      notifyListeners();
    }
  }

  Future<void> deleteTask(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final removedTask = _tasks.removeAt(index);
    notifyListeners();

    try {
      await _tasksRepository.deleteTask(id);
    } catch (e) {
      debugPrint("Error deleting task: $e");
      _tasks.insert(index, removedTask);
      notifyListeners();
    }
  }

  List<TaskItem> getTasksForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return _tasks.where((t) {
      final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return d.isAtSameMomentAs(target);
    }).toList();
  }
}
