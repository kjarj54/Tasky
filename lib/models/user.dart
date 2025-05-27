class User {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now() {
    if (email.isEmpty) {
      throw ArgumentError('El email no puede estar vacío');
    }
    if (name.isEmpty) {
      throw ArgumentError('El nombre no puede estar vacío');
    }
    if (id.isEmpty) {
      throw ArgumentError('El ID del usuario no puede estar vacío');
    }
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Convert User to a Map for API requests
  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'name': name,
    'created_at': createdAt.toIso8601String(),
  };

  // Create a User from API response
  factory User.fromMap(Map<String, dynamic> map) => User(
    id: map['id'].toString(),
    email: map['email'],
    name: map['name'],
    createdAt: map['created_at'] != null 
        ? DateTime.parse(map['created_at']) 
        : DateTime.now(),
  );

  @override
  String toString() {
    return 'User{id: $id, email: $email, name: $name, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ email.hashCode ^ name.hashCode;
}
