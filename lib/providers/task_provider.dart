import 'package:flutter/foundation.dart';
import '../models/task.dart';

class TaskProvider extends ChangeNotifier {
  final List<Task> _tasks = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  List<Task> get tasks => List.unmodifiable(_tasks);
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
      );

      _tasks.add(task);
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

      _tasks.removeAt(taskIndex);
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
