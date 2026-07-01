class TaskItem {
  final String id;
  final String title;
  final DateTime dueDate;
  final String priority; // 'High', 'Medium', 'Low', 'None'
  bool completed;

  TaskItem({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.priority,
    this.completed = false,
  });
}
