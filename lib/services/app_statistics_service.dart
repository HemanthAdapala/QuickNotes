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
    final tomorrow = today.add(const Duration(days: 1));
    final weekStart = today.subtract(const Duration(days: 6));
    final monthStart = today.subtract(const Duration(days: 29));

    switch (filter) {
      case 'Today':
        return activeNotes.where((n) {
          final c = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
          final u = DateTime(n.updatedAt.year, n.updatedAt.month, n.updatedAt.day);
          return c.isAtSameMomentAs(today) || u.isAtSameMomentAs(today);
        }).toList();
      case 'Weekly':
        return activeNotes.where((n) {
          final c = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
          final u = DateTime(n.updatedAt.year, n.updatedAt.month, n.updatedAt.day);
          return (c.isAfter(weekStart.subtract(const Duration(seconds: 1))) && c.isBefore(tomorrow)) ||
                 (u.isAfter(weekStart.subtract(const Duration(seconds: 1))) && u.isBefore(tomorrow));
        }).toList();
      case 'Monthly':
        return activeNotes.where((n) {
          final c = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
          final u = DateTime(n.updatedAt.year, n.updatedAt.month, n.updatedAt.day);
          return (c.isAfter(monthStart.subtract(const Duration(seconds: 1))) && c.isBefore(tomorrow)) ||
                 (u.isAfter(monthStart.subtract(const Duration(seconds: 1))) && u.isBefore(tomorrow));
        }).toList();
      case 'All':
      default:
        return activeNotes;
    }
  }

  /// Note Sorting Engine:
  /// - Pinned notes stay on top
  /// - Unpinned notes sorted by latest activity (updatedAt/createdAt) descending (Newest first) or ascending (Oldest first)
  static List<Note> sortNotes(List<Note> notes, {bool ascending = false}) {
    final list = List<Note>.from(notes);
    list.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      final timeA = a.updatedAt.isAfter(a.createdAt) ? a.updatedAt : a.createdAt;
      final timeB = b.updatedAt.isAfter(b.createdAt) ? b.updatedAt : b.createdAt;

      final comp = timeB.compareTo(timeA);
      return ascending ? -comp : comp;
    });
    return list;
  }

  /// Filters active (uncompleted) tasks strictly by Due Date windows.
  static List<TaskItem> filterTasksByDateRange(List<TaskItem> tasks, String filter) {
    final activeTasks = tasks.where((t) => !t.completed).toList();
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    
    // Current Week End: End of Sunday (or next 7 days)
    final daysUntilEndOfWeek = 7 - now.weekday;
    final weekEnd = DateTime(now.year, now.month, now.day + daysUntilEndOfWeek, 23, 59, 59, 999);

    // Current Month End: Last millisecond of current month
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    final monthEnd = DateTime(now.year, now.month, lastDayOfMonth, 23, 59, 59, 999);

    switch (filter) {
      case 'Missed':
        // Overdue tasks whose due date is strictly before today
        final todayStart = DateTime(now.year, now.month, now.day);
        return activeTasks.where((t) {
          final localDue = t.dueDate.toLocal();
          return localDue.isBefore(todayStart);
        }).toList();

      case 'Today':
        // Tasks due today (todayStart <= dueDate <= todayEnd)
        final todayStart = DateTime(now.year, now.month, now.day);
        return activeTasks.where((t) {
          final localDue = t.dueDate.toLocal();
          return (localDue.isAfter(todayStart.subtract(const Duration(milliseconds: 1))) || localDue.isAtSameMomentAs(todayStart)) &&
                 (localDue.isBefore(todayEnd) || localDue.isAtSameMomentAs(todayEnd));
        }).toList();

      case 'Weekly':
        // Overdue + tasks due within current week (dueDate <= weekEnd)
        return activeTasks.where((t) {
          final localDue = t.dueDate.toLocal();
          return localDue.isBefore(weekEnd) || localDue.isAtSameMomentAs(weekEnd);
        }).toList();

      case 'Monthly':
        // Overdue + tasks due within current month (dueDate <= monthEnd)
        return activeTasks.where((t) {
          final localDue = t.dueDate.toLocal();
          return localDue.isBefore(monthEnd) || localDue.isAtSameMomentAs(monthEnd);
        }).toList();

      case 'All':
      default:
        return activeTasks;
    }
  }

  /// Task Sorting Engine:
  /// - For 'Today': Newest to Oldest (createdAt descending, then dueDate descending)
  /// - For 'All' / 'Weekly' / 'Monthly': 4-Tier Sorting Engine (Overdue > Today > Future, Due Time Ascending, Priority Descending)
  static List<TaskItem> sortTasks(List<TaskItem> tasks, {String filter = 'All', bool ascending = false}) {
    final list = List<TaskItem>.from(tasks);

    if (filter == 'Today') {
      list.sort((a, b) {
        final cComp = b.createdAt.compareTo(a.createdAt);
        if (cComp != 0) return cComp;
        return b.dueDate.compareTo(a.dueDate);
      });
      return ascending ? list.reversed.toList() : list;
    }

    final now = DateTime.now().toLocal();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final todayStart = DateTime(now.year, now.month, now.day);

    int getUrgencyGroup(TaskItem t) {
      final localDue = t.dueDate.toLocal();
      if (localDue.isBefore(todayStart)) {
        return 0; // Overdue
      } else if (localDue.isBefore(todayEnd) || localDue.isAtSameMomentAs(todayEnd)) {
        return 1; // Today
      } else {
        return 2; // Future
      }
    }

    int getPriorityWeight(String p) {
      switch (p.toLowerCase()) {
        case 'high':
        case 'red':
          return 0;
        case 'medium':
        case 'yellow':
          return 1;
        case 'low':
        case 'green':
          return 2;
        default:
          return 3;
      }
    }

    list.sort((a, b) {
      // Tier 1: Urgency Grouping (Overdue > Today > Future)
      final groupA = getUrgencyGroup(a);
      final groupB = getUrgencyGroup(b);
      if (groupA != groupB) {
        return groupA.compareTo(groupB);
      }

      // Tier 2: Exact Due Date & Time Ascending (Earlier First)
      final dueComp = a.dueDate.compareTo(b.dueDate);
      if (dueComp != 0) {
        return dueComp;
      }

      // Tier 3: Priority Level Descending (High 'red' > Medium 'yellow' > Low 'green' > None)
      final prioA = getPriorityWeight(a.priority);
      final prioB = getPriorityWeight(b.priority);
      if (prioA != prioB) {
        return prioA.compareTo(prioB);
      }

      // Tier 4: Creation Timestamp Ascending
      return a.createdAt.compareTo(b.createdAt);
    });

    return ascending ? list.reversed.toList() : list;
  }
}
