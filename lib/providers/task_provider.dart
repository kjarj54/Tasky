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
    
    // Limpiar las tareas actuales antes de cargar las nuevas
    _tasks.clear();
    _clearError();
    notifyListeners();
    
    // Cargar las tareas del nuevo usuario
    await loadTasks();
    
    // Intentar sincronizar si hay usuario autenticado
    if (userId != null) {
      syncTasks();
    }
  }  Future<void> loadTasks() async {
    _setLoading(true);
    try {
      List<Task> dbTasks;
      if (_currentUserId != null) {
        // Solo cargar tareas específicas del usuario actual (no eliminadas)
        dbTasks = await TaskDatabase.instance.getTasksForUser(_currentUserId!);
      } else {
        // Si no hay usuario, cargar tareas sin asociar a usuario (para modo offline)
        dbTasks = await TaskDatabase.instance.getAllTasks();
        // Filtrar solo las tareas que no tienen userId asignado y no están eliminadas
        dbTasks = dbTasks.where((task) => task.userId == null && !task.isDeleted).toList();
      }
      
      _tasks.clear();
      _tasks.addAll(dbTasks);
      
      if (kDebugMode) {
        print('Cargadas ${_tasks.length} tareas para usuario: $_currentUserId');
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Error al cargar tareas: $e');
      if (kDebugMode) {
        print('Error al cargar tareas: $e');
      }
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
      }    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
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

      // Marcar como eliminada en la base de datos
      await TaskDatabase.instance.deleteTask(id);
      
      // Eliminar de la lista en memoria
      _tasks.removeAt(taskIndex);
      
      // Si está conectado, intentar sincronizar inmediatamente
      if (_currentUserId != null && !_isSyncing) {
        // Sincronizar en segundo plano sin bloquear la UI
        Future.delayed(Duration.zero, syncTasks);
      }
      
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
      // Obtener el token específico del usuario actual
      final tokens = await SecureStorage.getUserTokens(_currentUserId!);
      if (tokens == null) return;
      
      final token = tokens['token'];
      if (token == null) return;
      
      if (kDebugMode) {
        print('Iniciando sincronización para usuario: $_currentUserId');
      }

      // PASO 1: Sincronizar tareas eliminadas
      final deletedTasks = await TaskDatabase.instance.getDeletedTasksForSync(_currentUserId!);
      if (deletedTasks.isNotEmpty) {
        if (kDebugMode) {
          print('Sincronizando ${deletedTasks.length} tareas eliminadas');
        }
        
        // Eliminar en el servidor
        await TaskService.syncDeletedTasks(token, deletedTasks);
        
        // Eliminar permanentemente de la base de datos local
        for (final task in deletedTasks) {
          await TaskDatabase.instance.purgeDeletedTask(task.id);
          if (kDebugMode) {
            print('Tarea eliminada permanentemente: ${task.id}');
          }
        }
      }

      // PASO 2: Sincronizar tareas modificadas localmente
      final tasksToSync = await TaskDatabase.instance.getTasksNeedingSync(_currentUserId!);
      
      if (tasksToSync.isNotEmpty) {
        if (kDebugMode) {
          print('Sincronizando ${tasksToSync.length} tareas modificadas');
        }
        
        // Sincronizar tareas locales con el servidor
        final syncedTasks = await TaskService.syncTasks(token, _currentUserId!, tasksToSync);
        
        // Actualizar base de datos local con IDs del servidor
        for (int i = 0; i < tasksToSync.length && i < syncedTasks.length; i++) {
          final localTask = tasksToSync[i];
          final syncedTask = syncedTasks[i];
          await TaskDatabase.instance.markTaskAsSynced(localTask.id, syncedTask.serverId!);
        }
      }

      // PASO 3: Obtener todas las tareas actualizadas del servidor
      if (kDebugMode) {
        print('Obteniendo tareas actualizadas del servidor');
      }
      
      final serverTasks = await TaskService.getTasks(token, _currentUserId!);
      
      // Actualizar lista local con las tareas del servidor
      await _mergeServerTasks(serverTasks);
      
      if (kDebugMode) {
        print('Sincronización completada con éxito');
      }
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
    // Obtener un mapa de tareas existentes para búsqueda más rápida
    final Map<String, Task> existingTasksByServerId = {};
    for (final task in _tasks) {
      if (task.serverId != null) {
        existingTasksByServerId[task.serverId!] = task;
      }
    }
    
    // Lista de tareas del servidor para comparar
    final serverTaskIds = serverTasks.map((task) => task.serverId).toSet();
    
    // Detectar tareas que están en local pero no en el servidor (posiblemente eliminadas en otro dispositivo)
    final localTasksToDelete = _tasks.where((task) => 
      task.serverId != null && 
      !serverTaskIds.contains(task.serverId) && 
      !task.isDeleted
    ).toList();
    
    // Eliminar tareas que ya no existen en el servidor
    for (final taskToDelete in localTasksToDelete) {
      if (kDebugMode) {
        print('Eliminando tarea local que ya no existe en el servidor: ${taskToDelete.id}');
      }
      await TaskDatabase.instance.purgeDeletedTask(taskToDelete.id);
    }
    
    // Actualizar/agregar tareas del servidor
    for (final serverTask in serverTasks) {
      final existingTask = existingTasksByServerId[serverTask.serverId];
      
      if (existingTask != null) {
        // Solo actualizar si hay cambios
        if (existingTask.title != serverTask.title || existingTask.isCompleted != serverTask.isCompleted) {
          if (kDebugMode) {
            print('Actualizando tarea existente: ${existingTask.id}');
          }
          
          // Actualizar tarea existente manteniendo ID local
          final updatedTask = serverTask.copyWith(
            id: existingTask.id,
            userId: _currentUserId,
            needsSync: false,
          );
          await TaskDatabase.instance.updateTask(updatedTask);
        }
      } else {
        // Agregar nueva tarea del servidor
        if (kDebugMode) {
          print('Agregando nueva tarea del servidor: ${serverTask.serverId}');
        }
        
        final newTask = serverTask.copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString() + serverTask.serverId!,
          userId: _currentUserId,
          needsSync: false,
        );
        await TaskDatabase.instance.insertTask(newTask);
      }
    }
    
    // Recargar tareas para asegurar consistencia
    await loadTasks();
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
  /// Refresca las tareas del usuario actual
  /// Útil cuando se cambia de sesión para mostrar las tareas correctas
  Future<void> refreshTasks() async {
    // Primero cargar tareas locales
    await loadTasks();
    
    // Asegurar que no hay otra sincronización en progreso
    if (_isSyncing) {
      if (kDebugMode) {
        print('Ya hay una sincronización en progreso. Esperando...');
      }
      // Esperar a que termine la sincronización actual
      while (_isSyncing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    // Sincronizar con el servidor si hay usuario autenticado
    if (_currentUserId != null) {
      if (kDebugMode) {
        print('Sincronizando tareas para usuario: $_currentUserId');
      }
      await syncTasks(); // Esperar a que termine la sincronización
      
      // Recargar tareas locales después de sincronizar
      await loadTasks();
    } else {
      if (kDebugMode) {
        print('No hay usuario autenticado, no se sincronizarán las tareas');
      }
    }
  }

  /// Limpia todas las tareas del provider
  /// Útil cuando se cierra sesión o se cambia de usuario
  void clearTasks() {
    _tasks.clear();
    _clearError();
    notifyListeners();
  }
}
