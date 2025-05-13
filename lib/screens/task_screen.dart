import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasky/screens/settings_screen.dart';
import '../providers/task_provider.dart';
import '../widgets/task_list.dart';
import '../widgets/new_task_dialog.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  bool isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            isSearching
                ? TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar tareas...',
                    border: InputBorder.none,
                  ),
                  onChanged:
                      (value) =>
                          context.read<TaskProvider>().setSearchQuery(value),
                )
                : const Text('Tasky'),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  context.read<TaskProvider>().setSearchQuery('');
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: const Column(
        children: [
          Expanded(
            child: TaskList(showCompleted: false, title: 'Tareas Pendientes'),
          ),
          Divider(),
          Expanded(
            child: TaskList(showCompleted: true, title: 'Tareas Completadas'),
          ),
        ],
      ),
      bottomNavigationBar: const BottomAppBar(
        shape: CircularNotchedRectangle(),
        child: Row(children: [SizedBox(height: 48)]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<String>(
            context: context,
            builder: (context) => const NewTaskDialog(),
          );
          if (result != null && context.mounted) {
            context.read<TaskProvider>().addTask(result);
          }
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
