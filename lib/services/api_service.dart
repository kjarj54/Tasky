import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/user.dart';
import '../models/auth.dart';
import '../models/task.dart';

class ApiService {
  static const String _baseUrl = 'http://10.0.2.2:3000/api';
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Check internet connectivity
  Future<bool> get hasConnection async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Auth endpoints
  Future<AuthResponse> register(String name, String email, String password) async {
    if (!await hasConnection) {
      throw Exception('No hay conexión a internet');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return AuthResponse.fromMap(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error en el registro');
    }
  }

  Future<AuthResponse> login(String email, String password) async {
    if (!await hasConnection) {
      throw Exception('No hay conexión a internet');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromMap(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error en el login');
    }
  }

  Future<AuthResponse> refreshToken(String refreshToken) async {
    if (!await hasConnection) {
      throw Exception('No hay conexión a internet');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'refresh_token': refreshToken,
      }),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromMap(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al refrescar token');
    }
  }

  Future<void> logout(String token, String refreshToken) async {
    if (!await hasConnection) {
      return; // Allow logout even without connection
    }

    try {
      await http.post(
        Uri.parse('$_baseUrl/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'refresh_token': refreshToken,
        }),
      );
    } catch (e) {
      // Ignore logout errors as we're logging out anyway
    }
  }

  Future<User> getCurrentUser(String token) async {
    if (!await hasConnection) {
      throw Exception('No hay conexión a internet');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromMap(data['user']);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener usuario');
    }
  }

  // Task endpoints
  Future<List<Task>> getTasks(String token) async {
    if (!await hasConnection) {
      throw Exception('No hay conexión a internet');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/tasks'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tasksJson = data['tasks'] as List;
      return tasksJson.map((json) => Task.fromJson(json)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener tareas');
    }
  }

  Future<Task> createTask(String token, String title) async {
    if (!await hasConnection) {
      throw Exception('No hay conexión a internet');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/tasks'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Task.fromJson(data['task']);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al crear tarea');
    }
  }

  Future<Task> updateTask(String token, int taskId, {String? title, bool? isCompleted}) async {
    if (!await hasConnection) {
      throw Exception('No hay conexión a internet');
    }

    final Map<String, dynamic> body = {};
    if (title != null) body['title'] = title;
    if (isCompleted != null) body['is_completed'] = isCompleted;

    final response = await http.put(
      Uri.parse('$_baseUrl/tasks/$taskId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Task.fromJson(data['task']);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al actualizar tarea');
    }
  }

  Future<void> deleteTask(String token, int taskId) async {
    if (!await hasConnection) {
      throw Exception('No hay conexión a internet');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/tasks/$taskId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al eliminar tarea');
    }
  }

  Future<List<Task>> syncTasks(String token, List<Task> tasks) async {
    if (!await hasConnection) {
      throw Exception('No hay conexión a internet');
    }

    final tasksJson = tasks.map((task) => task.toJson()).toList();

    final response = await http.post(
      Uri.parse('$_baseUrl/tasks/sync'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'tasks': tasksJson,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tasksJson = data['tasks'] as List;
      return tasksJson.map((json) => Task.fromJson(json)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al sincronizar tareas');
    }
  }
}
