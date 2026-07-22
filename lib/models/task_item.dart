class TaskItem {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final String priority; // 'High', 'Medium', 'Low', 'None'
  bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reminderTime;

  TaskItem({
    required this.id,
    required this.title,
    this.description = '',
    required this.dueDate,
    required this.priority,
    this.completed = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.reminderTime,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority,
      'completed': completed ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'reminderTime': reminderTime?.toIso8601String(),
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      dueDate: DateTime.tryParse(map['dueDate'] as String? ?? '') ?? DateTime.now(),
      priority: map['priority'] as String? ?? 'None',
      completed: (map['completed'] as int? ?? (map['isCompleted'] as int? ?? 0)) == 1,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      reminderTime: map['reminderTime'] != null ? DateTime.tryParse(map['reminderTime'] as String) : null,
    );
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reminderTime,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}
