import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasky/screens/settings_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/account_switcher.dart';
import '../widgets/sync_indicator.dart';
import '../widgets/task_list.dart';
import '../widgets/new_task_dialog.dart';
import '../widgets/multi_account_summary.dart';

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
        title: isSearching
            ? TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar tareas...',
                  border: InputBorder.none,
                ),
                onChanged: (value) =>
                    context.read<TaskProvider>().setSearchQuery(value),
              )
            : Row(
                children: [
                  const Text('Tasky'),
                  const SizedBox(width: 8),
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      final user = authProvider.currentUser;
                      if (user != null) {
                        return Text(
                          ' - ${user.name}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
        actions: [
          if (!isSearching) const SyncIndicator(),
          if (!isSearching) const SizedBox(width: 8),
          if (!isSearching) const AccountSwitcher(),
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
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),      body: Column(
        children: [
          // Multi-account info banner
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.hasMultipleAccounts) {
                return Container(
                  width: double.infinity,
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${authProvider.sessions.length} cuentas activas • Toca el avatar para cambiar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),          // Sync status banner
          Consumer<TaskProvider>(
            builder: (context, taskProvider, child) {
              return FutureBuilder<bool>(
                future: taskProvider.isOnline,
                builder: (context, snapshot) {
                  final isOnline = snapshot.data ?? false;
                  if (!isOnline && !taskProvider.isSyncing) {
                    return Container(
                      width: double.infinity,
                      color: Colors.orange[100],
                      padding: const EdgeInsets.all(8.0),
                      child: const SyncStatus(),
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
          
          // Multi-account summary
          const MultiAccountSummary(),
          const Expanded(
            child: TaskList(showCompleted: false, title: 'Tareas Pendientes'),
          ),
          const Divider(),
          const Expanded(
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
