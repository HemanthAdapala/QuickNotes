import '../models/note.dart';
import '../models/task_item.dart';

class AppStatisticsService {
  static int calculateTotalNotes(List<Note> notes) {
    return notes.where((n) => !n.isDeleted && !n.isArchived).length;
  }

  static int calculateTotalTasks(List<TaskItem> tasks) {
    return tasks.length;
  }

  static int calculateCompletedTasks(List<TaskItem> tasks) {
    return tasks.where((t) => t.completed).length;
  }

  static int calculatePendingTasks(List<TaskItem> tasks) {
    return tasks.where((t) => !t.completed).length;
  }

  static int calculateNotesForCategory(List<Note> notes, String category) {
    return notes.where((n) => !n.isDeleted && !n.isArchived && n.category == category).length;
  }

  static int calculateNotesForFolder(List<Note> notes, String folderId) {
    return notes.where((n) => !n.isDeleted && !n.isArchived && n.folderId == folderId).length;
  }

  static List<Note> filterNotesByDateRange(List<Note> notes, String filter) {
    final activeNotes = notes.where((n) => !n.isDeleted && !n.isArchived).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));
    final monthEnd = today.add(const Duration(days: 30));

    switch (filter) {
      case 'Today':
        return activeNotes.where((n) {
          final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
          return d.isAtSameMomentAs(today);
        }).toList();
      case 'Weekly':
        return activeNotes.where((n) {
          final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
          return d.isAfter(today.subtract(const Duration(days: 1))) && d.isBefore(weekEnd.add(const Duration(days: 1)));
        }).toList();
      case 'Monthly':
        return activeNotes.where((n) {
          final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
          return d.isAfter(today.subtract(const Duration(days: 1))) && d.isBefore(monthEnd.add(const Duration(days: 1)));
        }).toList();
      case 'All':
      default:
        return activeNotes;
    }
  }

  static List<TaskItem> filterTasksByDateRange(List<TaskItem> tasks, String filter) {
    final activeTasks = tasks.where((t) => !t.completed).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));
    final monthEnd = today.add(const Duration(days: 30));

    switch (filter) {
      case 'Today':
        return activeTasks.where((t) {
          final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
          return d.isAtSameMomentAs(today);
        }).toList();
      case 'Weekly':
        return activeTasks.where((t) {
          final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
          return d.isAfter(today.subtract(const Duration(days: 1))) && d.isBefore(weekEnd.add(const Duration(days: 1)));
        }).toList();
      case 'Monthly':
        return activeTasks.where((t) {
          final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
          return d.isAfter(today.subtract(const Duration(days: 1))) && d.isBefore(monthEnd.add(const Duration(days: 1)));
        }).toList();
      case 'All':
      default:
        return activeTasks;
    }
  }
}
