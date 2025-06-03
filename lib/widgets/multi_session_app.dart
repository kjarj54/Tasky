import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/multi_session_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/task_provider.dart';
import '../screens/task_screen.dart';
import '../screens/multi_session_login_screen.dart';

class MultiSessionApp extends StatelessWidget {
  const MultiSessionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MultiSessionProvider>(
      builder: (context, multiSessionProvider, child) {        // Si no hay sesiones activas, mostrar login
        if (!multiSessionProvider.hasActiveSessions) {
          return MaterialApp(
            title: 'Tasky',
            theme: _getDefaultTheme(),
            darkTheme: _getDefaultDarkTheme(),
            home: ChangeNotifierProvider(
              create: (_) => multiSessionProvider,
              child: const MultiSessionLoginScreen(isNewSession: false),
            ),
          );
        }

        // Si hay múltiples sesiones, mostrar el administrador de sesiones
        if (multiSessionProvider.sessionCount > 1) {
          return MaterialApp(
            title: 'Tasky - Sesiones Múltiples',
            theme: _getDefaultTheme(),
            darkTheme: _getDefaultDarkTheme(),
            home: MultiSessionDashboard(),
          );
        }

        // Si hay una sola sesión, mostrar la app normal
        final currentSession = multiSessionProvider.currentSession!;
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(
              value: currentSession.authProvider,
            ),
            ChangeNotifierProvider.value(
              value: currentSession.taskProvider,
            ),
            ChangeNotifierProvider.value(
              value: currentSession.themeProvider,
            ),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return MaterialApp(
                title: 'Tasky - ${currentSession.user.name}',
                theme: _getDefaultTheme(),
                darkTheme: _getDefaultDarkTheme(),
                themeMode: themeProvider.themeMode,
                home: const TaskScreen(),
              );
            },
          ),
        );
      },
    );
  }

  ThemeData _getDefaultTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B1631),
      ),
      brightness: Brightness.light,
    );
  }

  ThemeData _getDefaultDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B1631),
        brightness: Brightness.dark,
      ),
      brightness: Brightness.dark,
    );
  }
}

class MultiSessionDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<MultiSessionProvider>(
      builder: (context, multiSessionProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tasky - Sesiones Activas'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showAddSessionDialog(context),
                tooltip: 'Agregar nueva sesión',
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'close_all') {
                    await multiSessionProvider.closeAllSessions();
                  }
                },                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'close_all',
                    child: Row(
                      children: [
                        Icon(Icons.close),
                        SizedBox(width: 8),
                        Text('Cerrar todas las sesiones'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: multiSessionProvider.hasActiveSessions
              ? _buildSessionGrid(context, multiSessionProvider)
              : _buildEmptyState(context),
        );
      },
    );
  }

  Widget _buildSessionGrid(BuildContext context, MultiSessionProvider provider) {
    final sessions = provider.activeSessions.values.toList();
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isCurrentSession = provider.currentSessionId == session.sessionId;
        
        return SessionCard(
          session: session,
          isCurrentSession: isCurrentSession,
          onTap: () => _openSessionInNewWindow(context, session),
          onClose: () => provider.closeSession(session.sessionId),
          onMakeCurrent: () async => await provider.switchToSession(session.sessionId),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay sesiones activas',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega una nueva sesión para comenzar',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddSessionDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Agregar sesión'),
          ),
        ],
      ),
    );
  }

  void _openSessionInNewWindow(BuildContext context, SessionData session) {
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
}

class SessionCard extends StatelessWidget {
  final SessionData session;
  final bool isCurrentSession;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final Future<void> Function() onMakeCurrent;

  const SessionCard({
    Key? key,
    required this.session,
    required this.isCurrentSession,
    required this.onTap,
    required this.onClose,
    required this.onMakeCurrent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isCurrentSession ? 8 : 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isCurrentSession
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      session.user.name[0].toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.user.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          session.user.email,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(                    onSelected: (value) async {
                      if (value == 'close') {
                        onClose();
                      } else if (value == 'make_current') {
                        await onMakeCurrent();
                      }
                    },itemBuilder: (context) => [
                      if (!isCurrentSession)
                        PopupMenuItem(
                          value: 'make_current',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle),
                              SizedBox(width: 8),
                              Text('Hacer actual'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'close',
                        child: Row(
                          children: [
                            Icon(Icons.close),
                            SizedBox(width: 8),
                            Text('Cerrar sesión'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isCurrentSession)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Sesión Actual',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),              const Spacer(),
              ChangeNotifierProvider.value(
                value: session.taskProvider,
                child: Consumer<TaskProvider>(
                  builder: (context, taskProvider, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tareas pendientes: ${taskProvider.pendingTasks.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Tareas completadas: ${taskProvider.completedTasks.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onTap,
                  child: const Text('Abrir sesión'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SessionWindow extends StatelessWidget {
  final SessionData session;

  const SessionWindow({Key? key, required this.session}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(
          value: session.authProvider,
        ),
        ChangeNotifierProvider.value(
          value: session.taskProvider,
        ),
        ChangeNotifierProvider.value(
          value: session.themeProvider,
        ),
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
            themeMode: themeProvider.themeMode,
            home: const TaskScreen(),
          );
        },
      ),
    );
  }
}

class LoginSessionScreen extends StatelessWidget {
  const LoginSessionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar nueva sesión'),
      ),
      body: const MultiSessionLoginScreen(isNewSession: true),
    );
  }
}
