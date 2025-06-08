import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../screens/add_account_screen.dart';

class AccountSwitcher extends StatelessWidget {
  const AccountSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final sessions = authProvider.sessions;
        final currentUser = authProvider.currentUser;

        if (sessions.isEmpty) {
          return const SizedBox.shrink();
        }

        return PopupMenuButton<String>(
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
              currentUser?.name.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          tooltip: 'Switch Account',          onSelected: (userId) async {
            if (userId == 'add_account') {
              // Navigate to add account screen
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddAccountScreen(),
                ),
              );
            } else if (userId != currentUser?.id.toString()) {
              // Show loading indicator while switching
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text('Cambiando cuenta...'),
                    ],
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
              await authProvider.switchAccount(int.parse(userId));
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[];

            // Current accounts
            for (final session in sessions) {
              final user = session.user;
              final isActive = user.id == currentUser?.id;

              items.add(
                PopupMenuItem<String>(
                  value: user.id.toString(),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: isActive 
                          ? Theme.of(context).primaryColor 
                          : Colors.grey[400],
                      child: Text(
                        user.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      user.name,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: isActive 
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          )
                        : null,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              );
            }

            // Divider and add account option
            if (items.isNotEmpty) {
              items.add(const PopupMenuDivider());
            }

            items.add(
              const PopupMenuItem<String>(
                value: 'add_account',
                child: ListTile(
                  leading: Icon(Icons.add_circle_outline),
                  title: Text('Add Account'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            );

            return items;
          },
        );
      },
    );
  }
}

class AccountSwitcherDrawer extends StatelessWidget {
  const AccountSwitcherDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final sessions = authProvider.sessions;
        final currentUser = authProvider.currentUser;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Accounts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...sessions.map((session) {
                final user = session.user;
                final isActive = user.id == currentUser?.id;

                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: isActive 
                        ? Theme.of(context).primaryColor 
                        : Colors.grey[400],
                    child: Text(
                      user.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),                  title: Text(
                    user.name,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (isActive)
                        Consumer<TaskProvider>(
                          builder: (context, taskProvider, child) {
                            final stats = taskProvider.taskStats;
                            return Text(
                              '${stats['pending']} pendientes • ${stats['completed']} completadas',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  trailing: isActive 
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).primaryColor,
                        )
                      : null,onTap: isActive 
                      ? null 
                      : () async {
                          Navigator.pop(context);
                          // Show loading indicator
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text('Cambiando a ${user.name}...'),
                                ],
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                          await authProvider.switchAccount(user.id);
                        },
                );
              }).toList(),
              const Divider(),              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Add Account'),
                onTap: () async {
                  Navigator.pop(context);
                  // Navigate to login screen to add new account
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AddAccountScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout All'),
                onTap: () async {
                  Navigator.pop(context);
                  await authProvider.logoutAll();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
