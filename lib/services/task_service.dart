import '../models/task.dart';
import 'api_service.dart';

class TaskService {
  static Future<List<Task>> getTasks(String token, String userId) async {
    final response = await ApiService.get('/tasks', token);
    final List<dynamic> tasksJson = response['tasks'] ?? [];
    return tasksJson.map((json) => Task.fromJson(json, userId)).toList();
  }

  static Future<Task> createTask(String token, Task task) async {
    final response = await ApiService.post('/tasks', task.toJson(), token);
    return Task.fromJson(response['task'], task.userId);
  }

  static Future<Task> updateTask(String token, Task task) async {
    final taskId = task.serverId ?? task.id;
    final response = await ApiService.put('/tasks/$taskId', task.toJson(), token);
    return Task.fromJson(response['task'], task.userId);
  }

  static Future<void> deleteTask(String token, String taskId) async {
    await ApiService.delete('/tasks/$taskId', token);
  }

  static Future<List<Task>> syncTasks(String token, String userId, List<Task> localTasks) async {
    final tasksToSync = localTasks.where((task) => task.needsSync).toList();
    
    final response = await ApiService.post('/tasks/sync', {
      'tasks': tasksToSync.map((task) => task.toJson()).toList(),
    }, token);
    
    final List<dynamic> syncedTasksJson = response['tasks'] ?? [];
    return syncedTasksJson.map((json) => Task.fromJson(json, userId)).toList();
  }
}
