class Task {
  final String id;
  final String title;
  bool isCompleted;
  DateTime createdAt;
  final String? userId; // Nueva propiedad para asociar con el usuario
  final String? serverId; // ID del servidor para sincronización
  final bool needsSync; // Indica si necesita sincronizarse

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
    this.userId,
    this.serverId,
    this.needsSync = true,
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
    String? userId,
    String? serverId,
    bool? needsSync,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      serverId: serverId ?? this.serverId,
      needsSync: needsSync ?? this.needsSync,
    );
  }
  // Convert Task to a Map for database operations
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'is_completed': isCompleted ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'user_id': userId,
    'server_id': serverId,
    'needs_sync': needsSync ? 1 : 0,
  };

  // Create a Task from a database Map
  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'],
    title: map['title'],
    isCompleted: map['is_completed'] == 1,
    createdAt: DateTime.parse(map['created_at']),
    userId: map['user_id'],
    serverId: map['server_id'],
    needsSync: map['needs_sync'] == 1,
  );
  // Convert Task to JSON for API requests
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'title': title,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
    };
    
    // Only include ID if we have a valid serverId (integer from backend)
    if (serverId != null) {
      // Parse serverId to ensure it's a valid integer
      final serverIdInt = int.tryParse(serverId!);
      if (serverIdInt != null) {
        json['id'] = serverIdInt;
      }
    }
    
    return json;
  }

  // Create a Task from API response
  factory Task.fromJson(Map<String, dynamic> json, String? userId) => Task(
    id: DateTime.now().millisecondsSinceEpoch.toString(), // Local ID
    title: json['title'],
    isCompleted: json['is_completed'] ?? false,
    createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at']) 
        : DateTime.now(),
    userId: userId,
    serverId: json['id']?.toString(),
    needsSync: false, // Viene del servidor, no necesita sync
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