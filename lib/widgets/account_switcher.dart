import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';

class AccountSwitcher extends StatelessWidget {
  const AccountSwitcher({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final currentUser = authProvider.currentUser;
        final users = authProvider.authenticatedUsers;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Text(
                      'Cuentas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              if (users.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No hay cuentas activas'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userId = users.keys.elementAt(index);
                    final user = users[userId]!;
                    final isSelected = currentUser?.id == user.id;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceVariant,
                        child: Text(
                          user.name[0].toUpperCase(),
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      selected: isSelected,
                      onTap: () async {
                        Navigator.pop(context);
                        if (!isSelected) {
                          await authProvider.switchUser(user.id);
                        }
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.logout),
                        tooltip: 'Cerrar sesión',
                        onPressed: () async {
                          Navigator.pop(context);
                          await authProvider.logout(user.id);
                        },
                      ),
                    );
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Agregar otra cuenta'),
                onTap: () {
                  Navigator.pop(context);
                  authProvider.logout(); // Logout without removing accounts
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
