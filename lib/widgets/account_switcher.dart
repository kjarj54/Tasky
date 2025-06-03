import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/multi_session_provider.dart';
import '../screens/multi_session_login_screen.dart';

class AccountSwitcher extends StatelessWidget {
  const AccountSwitcher({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MultiSessionProvider>(
      builder: (context, multiSessionProvider, _) {
        final currentSession = multiSessionProvider.currentSession;
        final sessions = multiSessionProvider.activeSessions.values.toList();

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
                      'Sesiones Activas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Text(
                      '${multiSessionProvider.sessionCount}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              if (sessions.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No hay sesiones activas'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {                    final session = sessions[index];
                    final isSelected = currentSession?.sessionId == session.sessionId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: isSelected ? 4 : 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceVariant,
                          child: Text(
                            session.user.name[0].toUpperCase(),
                            style: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          session.user.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(session.user.email),
                            if (isSelected)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Sesión Actual',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        selected: isSelected,
                        onTap: () async {
                          Navigator.pop(context);
                          if (!isSelected) {
                            await multiSessionProvider.switchToSession(session.sessionId);
                          }
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.logout),
                          tooltip: 'Cerrar sesión',
                          onPressed: () async {
                            Navigator.pop(context);
                            await multiSessionProvider.closeSession(session.sessionId);
                          },
                        ),                      ),
                    );
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Agregar nueva sesión'),
                onTap: () {
                  Navigator.pop(context);
                  // Navegar a la pantalla de login para agregar nueva sesión
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const MultiSessionLoginScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
