class Task {
  final String id;
  final String title;
  bool isCompleted;
  DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now() {
    if (title.isEmpty) {
      throw ArgumentError('El título de la tarea no puede estar vacío');
    }
    if (id.isEmpty) {
      throw ArgumentError('El ID de la tarea no puede estar vacío');
    }
  }

  Task copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Convert Task to a Map for database operations
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'is_completed': isCompleted ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  // Create a Task from a database Map
  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'],
    title: map['title'],
    isCompleted: map['is_completed'] == 1,
    createdAt: DateTime.parse(map['created_at']),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ isCompleted.hashCode;
}