import 'package:flutter/material.dart';
import 'package:tasky/widgets/new_task_dialog.dart';
import '../models/task.dart';

class TaskItem extends StatelessWidget {
  final Task task;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onDelete;
  final ValueChanged<String> onEdit;

  const TaskItem({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Checkbox(
        value: task.isCompleted,
        onChanged: onToggle,
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          PopupMenuItem(
            onTap: () async {
              // Necesitamos usar Future.delayed porque onTap cierra el menú antes de mostrar el diálogo
              Future.delayed(
                const Duration(milliseconds: 10),
                () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => NewTaskDialog(
                      initialValue: task.title,
                      title: 'Editar Tarea',
                    ),
                  );
                  if (result != null) {
                    onEdit(result);
                  }
                },
              );
            },
            child: const Text('Editar'),
          ),
          PopupMenuItem(
            onTap: onDelete,
            child: const Text('Eliminar'),
          ),
          PopupMenuItem(
            onTap: () => onToggle(!task.isCompleted),
            child: Text(task.isCompleted ? 'Marcar como pendiente' : 'Marcar como completada'),
          ),
        ],
      ),
    );
  }
}