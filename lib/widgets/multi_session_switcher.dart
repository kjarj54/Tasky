import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/multi_session_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/multi_session_login_screen.dart';
import '../screens/task_screen.dart';

class MultiSessionSwitcher extends StatelessWidget {
  const MultiSessionSwitcher({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MultiSessionProvider>(
      builder: (context, multiSessionProvider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
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
              const SizedBox(height: 16),

              // Lista de sesiones
              if (multiSessionProvider.hasActiveSessions)
                ...multiSessionProvider.activeSessions.values.map(
                  (session) {
                    final isCurrentSession = multiSessionProvider.currentSessionId == session.sessionId;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: isCurrentSession ? 4 : 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrentSession
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceVariant,
                          child: Text(
                            session.user.name[0].toUpperCase(),
                            style: TextStyle(
                              color: isCurrentSession
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          session.user.name,
                          style: TextStyle(
                            fontWeight: isCurrentSession ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(session.user.email),
                            if (isCurrentSession)
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
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'switch':
                                Navigator.pop(context);
                                multiSessionProvider.switchToSession(session.sessionId);
                                break;
                              case 'new_window':
                                _openInNewWindow(context, session);
                                break;
                              case 'close':
                                await multiSessionProvider.closeSession(session.sessionId);
                                if (!multiSessionProvider.hasActiveSessions) {
                                  Navigator.pop(context);
                                }
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            if (!isCurrentSession)
                              PopupMenuItem(
                                value: 'switch',
                                child: Row(
                                  children: [
                                    Icon(Icons.switch_account),
                                    SizedBox(width: 8),
                                    Text('Cambiar a esta sesión'),
                                  ],
                                ),
                              ),
                            PopupMenuItem(
                              value: 'new_window',
                              child: Row(
                                children: [
                                  Icon(Icons.open_in_new),
                                  SizedBox(width: 8),
                                  Text('Abrir en nueva ventana'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'close',
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
                        onTap: () {
                          if (!isCurrentSession) {
                            Navigator.pop(context);
                            multiSessionProvider.switchToSession(session.sessionId);
                          }
                        },
                      ),
                    );
                  },
                ).toList()
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay sesiones activas',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              const Divider(),
              
              // Botones de acción
              Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.add_circle),
                    title: const Text('Agregar nueva sesión'),
                    onTap: () {
                      Navigator.pop(context);
                      _showAddSessionDialog(context);
                    },
                  ),
                  if (multiSessionProvider.hasActiveSessions) ...[
                    ListTile(
                      leading: const Icon(Icons.dashboard),
                      title: const Text('Ver todas las sesiones'),
                      onTap: () {
                        Navigator.pop(context);
                        _showSessionDashboard(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text('Cerrar todas las sesiones', style: TextStyle(color: Colors.red)),
                      onTap: () async {
                        final confirm = await _showConfirmDialog(
                          context,
                          'Cerrar todas las sesiones',
                          '¿Está seguro de que desea cerrar todas las sesiones activas?',
                        );
                        if (confirm == true) {
                          await multiSessionProvider.closeAllSessions();
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openInNewWindow(BuildContext context, SessionData session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionWindow(session: session),
        fullscreenDialog: true,
      ),
    );
  }

  void _showAddSessionDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MultiSessionLoginScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _showSessionDashboard(BuildContext context) {
    // Navegar al dashboard de sesiones múltiples
    // Por ahora solo mostramos un mensaje
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dashboard de sesiones - próximamente'),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(BuildContext context, String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
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
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

// Widget para mostrar una sesión en una ventana separada
class SessionWindow extends StatelessWidget {
  final SessionData session;

  const SessionWindow({Key? key, required this.session}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session.authProvider),
        ChangeNotifierProvider.value(value: session.taskProvider),
        ChangeNotifierProvider.value(value: session.themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Tasky - ${session.user.name}',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6B1631),
              ),
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6B1631),
                brightness: Brightness.dark,
              ),
              brightness: Brightness.dark,
            ),
            themeMode: themeProvider?.themeMode ?? ThemeMode.system,
            home: Scaffold(
              appBar: AppBar(
                title: Text('${session.user.name} - Sesión Independiente'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              body: const TaskScreen(),
            ),
          );
        },
      ),
    );
  }
}
