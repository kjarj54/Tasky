import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import 'login_screen.dart';

class AccountManagerScreen extends StatelessWidget {
  const AccountManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Cuentas'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final authenticatedUsers = authProvider.authenticatedUsers;
          final currentUser = authProvider.currentUser;

          return Column(
            children: [
              // Usuario actual
              if (currentUser != null) ...[
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          currentUser.name[0].toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              currentUser.email,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Cuenta Activa',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Lista de otras cuentas autenticadas
              if (authenticatedUsers.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Otras cuentas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: authenticatedUsers.length,
                    itemBuilder: (context, index) {
                      final user = authenticatedUsers.values.elementAt(index);
                      if (user.id == currentUser?.id) return const SizedBox.shrink();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          child: Text(
                            user.name[0].toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(user.name),
                        subtitle: Text(user.email),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'switch') {
                              await authProvider.switchUser(user.id);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            } else if (value == 'logout') {
                              await _showLogoutDialog(context, authProvider, user);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'switch',
                              child: Row(
                                children: [
                                  Icon(Icons.swap_horiz),
                                  SizedBox(width: 8),
                                  Text('Cambiar a esta cuenta'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(Icons.logout, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Botones de acción
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar cuenta'),
                    ),
                    const SizedBox(height: 8),
                    if (currentUser != null)
                      TextButton.icon(
                        onPressed: () => _showLogoutDialog(context, authProvider, currentUser),
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          'Cerrar sesión de cuenta actual',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (authenticatedUsers.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _showLogoutAllDialog(context, authProvider),
                        icon: const Icon(Icons.exit_to_app, color: Colors.red),
                        label: const Text(
                          'Cerrar todas las sesiones',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context, AuthProvider authProvider, User user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: Text('¿Está seguro de cerrar la sesión de ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (result == true) {
      await authProvider.logout(user.id);
      if (context.mounted && authProvider.authenticatedUsers.isEmpty) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _showLogoutAllDialog(BuildContext context, AuthProvider authProvider) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar todas las sesiones'),
        content: const Text('¿Está seguro de cerrar todas las sesiones? Tendrá que volver a iniciar sesión.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Cerrar todas'),
          ),
        ],
      ),
    );

    if (result == true) {
      await authProvider.logout();
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
