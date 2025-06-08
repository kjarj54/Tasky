class Task {
  final int? id; // nullable for new tasks before server sync
  final int? userId;
  final String title;
  bool isCompleted;
  DateTime createdAt;
  DateTime? updatedAt;
  String? tempId; // temporary ID for offline tasks

  Task({
    this.id,
    this.userId,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
    this.updatedAt,
    this.tempId,
  }) : createdAt = createdAt ?? DateTime.now() {
    if (title.isEmpty) {
      throw ArgumentError('El título de la tarea no puede estar vacío');
    }
  }

  // Get a unique identifier (server ID if available, otherwise temp ID)
  String get uniqueId => id?.toString() ?? tempId ?? DateTime.now().millisecondsSinceEpoch.toString();

  Task copyWith({
    int? id,
    int? userId,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? tempId,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tempId: tempId ?? this.tempId,
    );
  }

  // Convert Task to a Map for database operations
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    if (userId != null) 'user_id': userId,
    'title': title,
    'is_completed': isCompleted ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    if (tempId != null) 'temp_id': tempId,
  };

  // Convert Task to JSON for API requests
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'title': title,
    'is_completed': isCompleted,
  };

  // Create a Task from a database Map
  factory Task.fromMap(Map<String, dynamic> map) {
    // Handle potential type mismatches from database
    int? id = map['id'] as int?;
    if (map['id'] is String) id = int.tryParse(map['id']);
    
    int? userId = map['user_id'] as int?;
    if (map['user_id'] is String) userId = int.tryParse(map['user_id']);
    
    String title = map['title']?.toString() ?? '';
    
    bool isCompleted = false;
    final completedValue = map['is_completed'];
    if (completedValue is int) {
      isCompleted = completedValue == 1;
    } else if (completedValue is bool) {
      isCompleted = completedValue;
    } else if (completedValue is String) {
      isCompleted = completedValue == '1' || completedValue.toLowerCase() == 'true';
    }
    
    DateTime createdAt = DateTime.now();
    if (map['created_at'] != null) {
      try {
        createdAt = DateTime.parse(map['created_at'].toString());
      } catch (e) {
        // Keep default if parsing fails
      }
    }
    
    DateTime? updatedAt;
    if (map['updated_at'] != null) {
      try {
        updatedAt = DateTime.parse(map['updated_at'].toString());
      } catch (e) {
        // Keep null if parsing fails
      }
    }
    
    String? tempId = map['temp_id']?.toString();
    
    return Task(
      id: id,
      userId: userId,
      title: title,
      isCompleted: isCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
      tempId: tempId,
    );
  }

  // Create a Task from API response
  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'],
    userId: json['user_id'],
    title: json['title'],
    isCompleted: json['is_completed'] ?? false,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
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
