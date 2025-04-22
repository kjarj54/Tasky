class Task {
  final String id;
  final String title;
  bool isCompleted;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
  }) : createdAt = DateTime.now() {
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
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
    )..isCompleted = isCompleted ?? this.isCompleted;
  }

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