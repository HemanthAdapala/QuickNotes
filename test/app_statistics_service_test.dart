import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/services/app_statistics_service.dart';

void main() {
  group('AppStatisticsService Filtering & 4-Tier Sorting Tests', () {
    test('Today filter excludes task created today but due tomorrow', () {
      final now = DateTime.now();
      final todayDue = DateTime(now.year, now.month, now.day, 14, 0);
      final tomorrowDue = DateTime(now.year, now.month, now.day + 1, 14, 0);

      final taskToday = TaskItem(
        id: '1',
        title: 'Task Today',
        dueDate: todayDue,
        createdAt: now,
        priority: 'medium',
      );

      final taskTomorrow = TaskItem(
        id: '2',
        title: 'Task Tomorrow (Created Today)',
        dueDate: tomorrowDue,
        createdAt: now, // Created today!
        priority: 'medium',
      );

      final filtered = AppStatisticsService.filterTasksByDateRange([taskToday, taskTomorrow], 'Today');

      expect(filtered.length, 1);
      expect(filtered.first.id, '1');
    });

    test('Today filter sorts tasks Newest to Oldest by createdAt descending', () {
      final now = DateTime.now();
      final t1 = TaskItem(
        id: 'older',
        title: 'Older Task',
        dueDate: now,
        createdAt: now.subtract(const Duration(hours: 2)),
        priority: 'medium',
      );

      final t2 = TaskItem(
        id: 'newer',
        title: 'Newer Task',
        dueDate: now,
        createdAt: now,
        priority: 'medium',
      );

      final sorted = AppStatisticsService.sortTasks([t1, t2], filter: 'Today');

      expect(sorted[0].id, 'newer');
      expect(sorted[1].id, 'older');
    });

    test('4-Tier sorting orders overdue before today, and earlier due times first', () {
      final now = DateTime.now().toLocal();
      final yesterday = DateTime(now.year, now.month, now.day - 1, 10, 0);
      final todayMorning = DateTime(now.year, now.month, now.day, 9, 0);
      final todayAfternoon = DateTime(now.year, now.month, now.day, 15, 0);

      final tOverdueLow = TaskItem(
        id: 'overdue_low',
        title: 'Overdue Low',
        dueDate: yesterday,
        priority: 'low',
      );

      final tTodayHigh = TaskItem(
        id: 'today_high',
        title: 'Today High',
        dueDate: todayAfternoon,
        priority: 'high',
      );

      final tTodayMorning = TaskItem(
        id: 'today_morning',
        title: 'Today Morning',
        dueDate: todayMorning,
        priority: 'low',
      );

      final sorted = AppStatisticsService.sortTasks([tTodayHigh, tTodayMorning, tOverdueLow]);

      expect(sorted[0].id, 'overdue_low');
      expect(sorted[1].id, 'today_morning');
      expect(sorted[2].id, 'today_high');
    });
  });
}
