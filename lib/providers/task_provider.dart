import 'package:flutter/foundation.dart';
import '../db/task_database.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class TaskProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  final ApiService _apiService = ApiService();
  
  final List<Task> _tasks = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  DateTime? _lastSyncTime;

  // Track if we're switching accounts for UI feedback
  bool _isSwitchingAccount = false;
  bool get isSwitchingAccount => _isSwitchingAccount;

  TaskProvider(this._authProvider) {
    _authProvider.addListener(_onAuthChanged);
    loadTasks();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
  // Getters
  List<Task> get tasks => List.unmodifiable(_tasks);
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  // Check if device is online
  Future<bool> get isOnline => _apiService.hasConnection;  // Handle auth state changes
  void _onAuthChanged() {
    // Set switching account state
    _setSwitchingAccount(true);
    
    // Clear error state when switching accounts
    _clearError();
    
    // Clear current tasks immediately to avoid showing wrong user's tasks
    _tasks.clear();
    _searchQuery = '';
    notifyListeners();
    
    // Load tasks for new user
    loadTasks().then((_) {
      _setSwitchingAccount(false);
    });
  }
  // Load tasks for current user
  Future<void> loadTasks() async {
    if (_authProvider.currentUser == null) {
      _tasks.clear();
      _clearError();
      notifyListeners();
      return;
    }

    _setLoading(true);
    _clearError();
    
    try {
      // Ensure database schema is correct first
      await TaskDatabase.instance.ensureSchemaExists();
      
      // Load from local database first
      final localTasks = await TaskDatabase.instance.getTasksByUser(_authProvider.currentUser!.id);
      _tasks.clear();
      _tasks.addAll(localTasks);
      notifyListeners();

      // Try to sync with server if connected
      await _syncWithServer();
    } catch (e) {
      _setError('Error al cargar tareas: $e');
      if (kDebugMode) {
        print('Error loading tasks for user ${_authProvider.currentUser?.id}: $e');
        print('Stack trace: ${StackTrace.current}');
        
        // Try to debug database schema if there's a schema-related error
        if (e.toString().contains('no such table') || 
            e.toString().contains('has no column') ||
            e.toString().contains('type cast')) {
          await TaskDatabase.instance.debugDatabaseSchema();
        }
      }
    } finally {
      _setLoading(false);
    }
  }

  // Sync tasks with server
  Future<void> syncTasks() async {
    if (_authProvider.currentUser == null) return;
    
    _setSyncing(true);
    try {
      await _syncWithServer();
    } catch (e) {
      _setError('Error al sincronizar: $e');
    } finally {
      _setSyncing(false);
    }
  }

  Future<void> _syncWithServer() async {
    if (_authProvider.currentUser == null) return;

    try {
      final hasConnection = await ApiService().hasConnection;
      if (!hasConnection) return;

      final token = await _authProvider.getValidToken();
      if (token == null) return;

      // Get server tasks
      final serverTasks = await _apiService.getTasks(token);
      
      // Replace local tasks with server tasks
      await TaskDatabase.instance.replaceTasks(serverTasks, _authProvider.currentUser!.id);
      
      // Update local state
      _tasks.clear();
      _tasks.addAll(serverTasks);
      _lastSyncTime = DateTime.now();
      
      notifyListeners();
    } catch (e) {
      // Don't throw error for sync failures, just log
      if (kDebugMode) {
        print('Sync failed: $e');
      }
    }
  }

  // Get filtered tasks
  List<Task> get pendingTasks => List.unmodifiable(
    _tasks.where((task) => 
      !task.isCompleted && 
      (_searchQuery.isEmpty || task.title.toLowerCase().contains(_searchQuery.toLowerCase()))
    ).toList(),
  );

  List<Task> get completedTasks => List.unmodifiable(
    _tasks.where((task) => 
      task.isCompleted && 
      (_searchQuery.isEmpty || task.title.toLowerCase().contains(_searchQuery.toLowerCase()))
    ).toList(),
  );

  // Add new task
  Future<void> addTask(String title) async {
    if (_authProvider.currentUser == null) {
      throw StateError('Debe iniciar sesión para crear tareas');
    }

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('El título no puede estar vacío');
    }

    if (_tasks.any((task) => task.title == trimmedTitle)) {
      throw StateError('Ya existe una tarea con este título');
    }

    _setLoading(true);
    _clearError();    try {
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      final newTask = Task(
        userId: _authProvider.currentUser!.id,
        title: trimmedTitle,
        tempId: tempId,
      );      // Add to local storage first
      await TaskDatabase.instance.insertTask(newTask);
      _tasks.add(newTask);
      notifyListeners();

      // Try to sync with server
      final hasConnection = await ApiService().hasConnection;
      if (hasConnection) {
        final token = await _authProvider.getValidToken();
        if (token != null) {
          try {
            final serverTask = await _apiService.createTask(token, trimmedTitle);
            
            // Replace local task with server task
            final taskIndex = _tasks.indexWhere((t) => t.tempId == tempId);
            if (taskIndex >= 0) {
              _tasks[taskIndex] = serverTask;
              await TaskDatabase.instance.deleteTask(null, tempId: tempId);
              await TaskDatabase.instance.insertTask(serverTask);
              notifyListeners();
            }
          } catch (e) {
            // Keep local task even if server sync fails
            if (kDebugMode) {
              print('Failed to sync new task to server: $e');            }
          }
        }
      }
    } catch (e) {
      // If database error occurs, try to debug and recreate if needed
      if (e.toString().contains('has no column named temp_id') || 
          e.toString().contains('SQLITE_ERROR')) {
        if (kDebugMode) {
          print('Database schema error detected: $e');
          await TaskDatabase.instance.debugDatabaseSchema();
        }
        _setError('Error de base de datos. La aplicación necesita actualizar su esquema. Reinicia la aplicación.');
      } else {
        _setError(e.toString());
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Toggle task completion
  Future<void> toggleTask(String taskIdentifier) async {
    if (_authProvider.currentUser == null) {
      throw StateError('Debe iniciar sesión para modificar tareas');
    }

    _setLoading(true);
    _clearError();

    try {
      final taskIndex = _tasks.indexWhere((task) => task.uniqueId == taskIdentifier);
      if (taskIndex == -1) {
        throw StateError('Tarea no encontrada');
      }

      final task = _tasks[taskIndex];
      final updatedTask = task.copyWith(
        isCompleted: !task.isCompleted,
        updatedAt: DateTime.now(),
      );

      // Update local storage
      _tasks[taskIndex] = updatedTask;
      await TaskDatabase.instance.updateTask(updatedTask);
      notifyListeners();

      // Try to sync with server
      final hasConnection = await ApiService().hasConnection;
      if (hasConnection && task.id != null) {
        final token = await _authProvider.getValidToken();
        if (token != null) {
          try {
            final serverTask = await _apiService.updateTask(
              token, 
              task.id!, 
              isCompleted: updatedTask.isCompleted,
            );
            
            _tasks[taskIndex] = serverTask;
            await TaskDatabase.instance.updateTask(serverTask);
            notifyListeners();
          } catch (e) {
            // Keep local changes even if server sync fails
            if (kDebugMode) {
              print('Failed to sync task toggle to server: $e');
            }
          }
        }
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Delete task
  Future<void> deleteTask(String taskIdentifier) async {
    if (_authProvider.currentUser == null) {
      throw StateError('Debe iniciar sesión para eliminar tareas');
    }

    _setLoading(true);
    _clearError();

    try {
      final taskIndex = _tasks.indexWhere((task) => task.uniqueId == taskIdentifier);
      if (taskIndex == -1) {
        throw StateError('Tarea no encontrada');
      }

      final task = _tasks[taskIndex];
      
      // Remove from local storage
      _tasks.removeAt(taskIndex);
      await TaskDatabase.instance.deleteTask(task.id, tempId: task.tempId);
      notifyListeners();

      // Try to sync with server
      final hasConnection = await ApiService().hasConnection;
      if (hasConnection && task.id != null) {
        final token = await _authProvider.getValidToken();
        if (token != null) {
          try {
            await _apiService.deleteTask(token, task.id!);
          } catch (e) {
            // Task is already removed locally, don't revert
            if (kDebugMode) {
              print('Failed to sync task deletion to server: $e');
            }
          }
        }
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Edit task
  Future<void> editTask(String taskIdentifier, String newTitle) async {
    if (_authProvider.currentUser == null) {
      throw StateError('Debe iniciar sesión para editar tareas');
    }

    final trimmedTitle = newTitle.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('El título no puede estar vacío');
    }

    _setLoading(true);
    _clearError();

    try {
      final taskIndex = _tasks.indexWhere((task) => task.uniqueId == taskIdentifier);
      if (taskIndex == -1) {
        throw StateError('Tarea no encontrada');
      }

      if (_tasks.any((task) => task.uniqueId != taskIdentifier && task.title == trimmedTitle)) {
        throw StateError('Ya existe una tarea con este título');
      }

      final task = _tasks[taskIndex];
      final updatedTask = task.copyWith(
        title: trimmedTitle,
        updatedAt: DateTime.now(),
      );

      // Update local storage
      _tasks[taskIndex] = updatedTask;
      await TaskDatabase.instance.updateTask(updatedTask);
      notifyListeners();

      // Try to sync with server
      final hasConnection = await ApiService().hasConnection;
      if (hasConnection && task.id != null) {
        final token = await _authProvider.getValidToken();
        if (token != null) {
          try {
            final serverTask = await _apiService.updateTask(
              token, 
              task.id!, 
              title: trimmedTitle,
            );
            
            _tasks[taskIndex] = serverTask;
            await TaskDatabase.instance.updateTask(serverTask);
            notifyListeners();
          } catch (e) {
            // Keep local changes even if server sync fails
            if (kDebugMode) {
              print('Failed to sync task edit to server: $e');
            }
          }
        }
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Set search query
  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  // Get task statistics for current user
  Map<String, int> get taskStats {
    final pending = pendingTasks.length;
    final completed = completedTasks.length;
    final total = pending + completed;
    
    return {
      'total': total,
      'pending': pending,
      'completed': completed,
    };
  }

  // Get task statistics for a specific user
  Future<Map<String, int>> getTaskStatsForUser(int userId) async {
    try {
      final userTasks = await TaskDatabase.instance.getTasksByUser(userId);
      final pending = userTasks.where((task) => !task.isCompleted).length;
      final completed = userTasks.where((task) => task.isCompleted).length;
      final total = pending + completed;
      
      return {
        'total': total,
        'pending': pending,
        'completed': completed,
      };
    } catch (e) {
      return {
        'total': 0,
        'pending': 0,
        'completed': 0,
      };
    }
  }

  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSyncing(bool value) {
    _isSyncing = value;
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
    notifyListeners();
  }

  void _setSwitchingAccount(bool value) {
    _isSwitchingAccount = value;
    notifyListeners();
  }
}
