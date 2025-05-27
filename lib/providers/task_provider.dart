import 'package:flutter/foundation.dart';
import 'package:tasky/db/task_database.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/secure_storage.dart';

class TaskProvider extends ChangeNotifier {
  final List<Task> _tasks = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;
  bool _isSyncing = false;

  List<Task> get tasks => List.unmodifiable(_tasks);
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  String? get currentUserId => _currentUserId;  TaskProvider() {
    _initializeForCurrentUser();
  }

  Future<void> _initializeForCurrentUser() async {
    final userId = await SecureStorage.getCurrentUserId();
    await setCurrentUser(userId);
  }

  Future<void> setCurrentUser(String? userId) async {
    if (_currentUserId == userId) return;
    
    _currentUserId = userId;
    await loadTasks();
    
    // Intentar sincronizar si hay usuario autenticado
    if (userId != null) {
      syncTasks();
    }
  }
  Future<void> loadTasks() async {
    _setLoading(true);
    try {
      List<Task> dbTasks;
      if (_currentUserId != null) {
        dbTasks = await TaskDatabase.instance.getTasksForUser(_currentUserId!);
      } else {
        dbTasks = await TaskDatabase.instance.getAllTasks();
      }
      
      _tasks.clear();
      _tasks.addAll(dbTasks);
      notifyListeners();
    } catch (e) {
      _setError('Error al cargar tareas: $e');
    } finally {
      _setLoading(false);
    }
  }

  List<Task> get pendingTasks => List.unmodifiable(
    _tasks.where((task) => !task.isCompleted && _matchesSearch(task)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  List<Task> get completedTasks => List.unmodifiable(
    _tasks.where((task) => task.isCompleted && _matchesSearch(task)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  bool _matchesSearch(Task task) {
    if (_searchQuery.isEmpty) return true;
    return task.title.toLowerCase().contains(_searchQuery.toLowerCase().trim());
  }

  Future<void> addTask(String title) async {
    try {
      _setLoading(true);
      _clearError();

      final trimmedTitle = title.trim();
      if (trimmedTitle.isEmpty) {
        throw ArgumentError('El título de la tarea no puede estar vacío');
      }

      if (_tasks.any((task) => task.title == trimmedTitle)) {
        throw StateError('Ya existe una tarea con este título');
      }
    final task = Task(
      id: DateTime.now().toIso8601String(),
      title: trimmedTitle,
      userId: _currentUserId,
      needsSync: _currentUserId != null, // Solo sincronizar si hay usuario
    );

      _tasks.add(task);
      await TaskDatabase.instance.insertTask(task);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleTask(String id) async {
    try {
      _setLoading(true);
      _clearError();

      final taskIndex = _tasks.indexWhere((task) => task.id == id);
      if (taskIndex == -1) {
        throw StateError('Tarea no encontrada');
      }

      _tasks[taskIndex].isCompleted = !_tasks[taskIndex].isCompleted;
      await TaskDatabase.instance.updateTask(_tasks[taskIndex]);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      _setLoading(true);
      _clearError();

      final taskIndex = _tasks.indexWhere((task) => task.id == id);
      if (taskIndex == -1) {
        throw StateError('Tarea no encontrada');
      }

      await TaskDatabase.instance.deleteTask(id);
      _tasks.removeAt(taskIndex);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> editTask(String id, String newTitle) async {
    try {
      _setLoading(true);
      _clearError();

      final trimmedTitle = newTitle.trim();
      if (trimmedTitle.isEmpty) {
        throw ArgumentError('El título de la tarea no puede estar vacío');
      }

      final taskIndex = _tasks.indexWhere((task) => task.id == id);
      if (taskIndex == -1) {
        throw StateError('Tarea no encontrada');
      }

      if (_tasks.any((task) => task.id != id && task.title == trimmedTitle)) {
        throw StateError('Ya existe una tarea con este título');
      }

      _tasks[taskIndex] = _tasks[taskIndex].copyWith(title: trimmedTitle);
      await TaskDatabase.instance.updateTask(_tasks[taskIndex]);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  Future<void> syncTasks() async {
    if (_currentUserId == null || _isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final token = await SecureStorage.getToken();
      if (token == null) return;

      // Obtener tareas que necesitan sincronización
      final tasksToSync = await TaskDatabase.instance.getTasksNeedingSync(_currentUserId!);
      
      if (tasksToSync.isNotEmpty) {
        // Sincronizar tareas locales con el servidor
        final syncedTasks = await TaskService.syncTasks(token, _currentUserId!, tasksToSync);
        
        // Actualizar base de datos local con IDs del servidor
        for (int i = 0; i < tasksToSync.length && i < syncedTasks.length; i++) {
          final localTask = tasksToSync[i];
          final syncedTask = syncedTasks[i];
          await TaskDatabase.instance.markTaskAsSynced(localTask.id, syncedTask.serverId!);
        }
      }

      // Obtener todas las tareas del servidor
      final serverTasks = await TaskService.getTasks(token, _currentUserId!);
      
      // Actualizar lista local
      await _mergeServerTasks(serverTasks);
      
    } catch (e) {
      // No mostrar error de sincronización al usuario a menos que sea crítico
      if (kDebugMode) {
        print('Error en sincronización: $e');
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _mergeServerTasks(List<Task> serverTasks) async {
    for (final serverTask in serverTasks) {
      // Buscar si ya existe una tarea con el mismo server_id
      final existingIndex = _tasks.indexWhere((task) => task.serverId == serverTask.serverId);
      
      if (existingIndex >= 0) {
        // Actualizar tarea existente
        _tasks[existingIndex] = serverTask.copyWith(
          id: _tasks[existingIndex].id, // Mantener ID local
          userId: _currentUserId,
          needsSync: false,
        );
        await TaskDatabase.instance.updateTask(_tasks[existingIndex]);
      } else {
        // Agregar nueva tarea del servidor
        final newTask = serverTask.copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString() + serverTask.serverId!,
          userId: _currentUserId,
          needsSync: false,
        );
        _tasks.add(newTask);
        await TaskDatabase.instance.insertTask(newTask);
      }
    }
    
    await loadTasks(); // Recargar para asegurar consistencia
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void resetError() {
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
