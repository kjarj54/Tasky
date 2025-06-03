import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasky/screens/settings_screen.dart';
import 'package:tasky/screens/account_manager_screen.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/task_list.dart';
import '../widgets/new_task_dialog.dart';
import '../widgets/account_switcher.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  bool isSearching = false;

  void _showAccountSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: const AccountSwitcher(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(      appBar: AppBar(
        title:
            isSearching                ? TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar tareas...',
                    border: InputBorder.none,
                  ),
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  onSubmitted: (_) {
                    setState(() {
                      isSearching = false;
                    });
                  },
                  onChanged:
                      (value) =>
                          context.read<TaskProvider>().setSearchQuery(value),
                )
                : const Text('Tasky'),
        leading: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final currentUser = authProvider.currentUser;
            if (currentUser == null) return const SizedBox.shrink();          return Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () => _showAccountSwitcher(context),
                borderRadius: BorderRadius.circular(20),
                child: Tooltip(
                  message: 'Cambiar cuenta: ${currentUser.email}',
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      currentUser.name[0].toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        actions: [
          // Indicador de sincronización
          Consumer<TaskProvider>(
            builder: (context, taskProvider, child) {
              if (taskProvider.isSyncing) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
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
          // Menú de opciones
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'accounts') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AccountManagerScreen(),
                  ),
                );
              } else if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              } else if (value == 'sync') {
                context.read<TaskProvider>().syncTasks();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'accounts',
                child: Row(
                  children: [
                    Icon(Icons.manage_accounts),
                    SizedBox(width: 8),
                    Text('Gestionar cuentas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sync',
                child: Row(
                  children: [
                    Icon(Icons.sync),
                    SizedBox(width: 8),
                    Text('Sincronizar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Configuración'),
                  ],
                ),
              ),
            ],
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
