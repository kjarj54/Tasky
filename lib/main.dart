import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/task_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/multi_session_provider.dart';
import 'screens/task_screen.dart';
import 'screens/login_screen.dart';
import 'providers/theme_provider.dart';
import 'widgets/multi_session_app.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MultiSessionProvider(),
      child: Consumer<MultiSessionProvider>(
        builder: (context, multiSessionProvider, child) {
          // Modo de sesiones múltiples - nueva funcionalidad
          return const MultiSessionApp();
        },
      ),
    );
  }
}

// Mantener la clase original para compatibilidad hacia atrás
class SingleSessionApp extends StatelessWidget {
  const SingleSessionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<AuthProvider, TaskProvider>(
          create: (_) => TaskProvider(),
          update: (_, authProvider, taskProvider) {
            taskProvider?.setCurrentUser(authProvider.currentUser?.id);
            return taskProvider ?? TaskProvider();
          },
        ),
      ],
      child: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, child) {
          return MaterialApp(
            title: 'Tasky',
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
            home: _getHomeScreen(authProvider.state),
          );
        },
      ),
    );
  }

  Widget _getHomeScreen(AuthState authState) {
    switch (authState) {
      case AuthState.initial:
      case AuthState.loading:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case AuthState.authenticated:
        return const TaskScreen();
      case AuthState.unauthenticated:
      case AuthState.error:
        return const LoginScreen();
    }
  }
}
