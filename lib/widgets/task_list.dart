import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import 'task_item.dart';

class TaskList extends StatelessWidget {
  final bool showCompleted;
  final String title;

  const TaskList({super.key, required this.showCompleted, required this.title});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        if (taskProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (taskProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error: ${taskProvider.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    taskProvider.resetError();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reintentando cargar las tareas...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        final tasks =
            showCompleted
                ? taskProvider.completedTasks
                : taskProvider.pendingTasks;

        if (tasks.isEmpty) {
          return Center(
            child: Text(
              showCompleted
                  ? 'No hay tareas completadas'
                  : 'No hay tareas pendientes',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '$title (${tasks.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return Dismissible(
                    key: Key(task.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Theme.of(context).colorScheme.error,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16.0),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss:
                        (_) => showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Confirmar eliminación'),
                                content: const Text(
                                  '¿Está seguro de eliminar esta tarea?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                        ),
                    onDismissed: (_) {
                      taskProvider.deleteTask(task.id).catchError((error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${error.toString()}'),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                        );
                      });
                    },
                    child: TaskItem(
                      task: task,
                      onToggle: (_) {
                        taskProvider.toggleTask(task.id).catchError((error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${error.toString()}'),
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                          );
                        });
                      },
                      onDelete: () {
                        taskProvider.deleteTask(task.id).catchError((error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${error.toString()}'),
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                          );
                        });
                      },
                      onEdit: (newTitle) {
                        taskProvider.editTask(task.id, newTitle).catchError((error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${error.toString()}'),
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                          );
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
