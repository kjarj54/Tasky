import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/secure_storage.dart';
import 'auth_provider.dart';
import 'task_provider.dart';
import 'theme_provider.dart';

class SessionData {
  final AuthProvider authProvider;
  final TaskProvider taskProvider;
  final ThemeProvider themeProvider;
  final String sessionId;
  final User user;

  SessionData({
    required this.authProvider,
    required this.taskProvider,
    required this.themeProvider,
    required this.sessionId,
    required this.user,
  });
}

class MultiSessionProvider extends ChangeNotifier {
  final Map<String, SessionData> _activeSessions = {};
  String? _currentSessionId;
  static const String _activeSessionsKey = 'active_sessions';
  static const String _currentSessionKey = 'current_session_id';

  // Constructor que inicializa las sesiones desde el almacenamiento
  MultiSessionProvider() {
    _initializeFromStorage();
  }

  // Getters
  Map<String, SessionData> get activeSessions => Map.unmodifiable(_activeSessions);
  String? get currentSessionId => _currentSessionId;
  SessionData? get currentSession => _currentSessionId != null 
      ? _activeSessions[_currentSessionId] 
      : null;
  
  List<User> get activeUsers => _activeSessions.values
      .map((session) => session.user)
      .toList();

  int get sessionCount => _activeSessions.length;
  bool get hasActiveSessions => _activeSessions.isNotEmpty;
  // Crear una nueva sesión para un usuario
  Future<String> createSession(User user) async {
    final sessionId = '${user.id}_${DateTime.now().millisecondsSinceEpoch}';
    
    // Crear providers independientes para esta sesión
    final authProvider = AuthProvider();
    final themeProvider = ThemeProvider();
    final taskProvider = TaskProvider();

    // Configurar la sesión para el usuario específico
    // Usar el método nuevo para configurar directamente con los datos del usuario
    await authProvider.initializeWithUser(user.id);
    await taskProvider.setCurrentUser(user.id);

    final sessionData = SessionData(
      authProvider: authProvider,
      taskProvider: taskProvider,
      themeProvider: themeProvider,
      sessionId: sessionId,
      user: user,
    );

    _activeSessions[sessionId] = sessionData;
    
    // Si es la primera sesión, hacerla actual
    if (_currentSessionId == null) {
      _currentSessionId = sessionId;
    }

    // Guardar cambios en el almacenamiento
    await _saveActiveSessionsToStorage();
    await _saveCurrentSessionToStorage();
    
    notifyListeners();
    return sessionId;
  }

  // Crear sesión con datos de autenticación completos
  Future<String> createSessionWithAuthData(User user, String token, String refreshToken) async {
    final sessionId = '${user.id}_${DateTime.now().millisecondsSinceEpoch}';
    
    // Crear providers independientes para esta sesión
    final authProvider = AuthProvider();
    final themeProvider = ThemeProvider();
    final taskProvider = TaskProvider();

    // Configurar la sesión con los datos de autenticación
    await authProvider.setUserSession(user, token, refreshToken);
    await taskProvider.setCurrentUser(user.id);

    final sessionData = SessionData(
      authProvider: authProvider,
      taskProvider: taskProvider,
      themeProvider: themeProvider,
      sessionId: sessionId,
      user: user,
    );

    _activeSessions[sessionId] = sessionData;
    
    // Si es la primera sesión, hacerla actual
    if (_currentSessionId == null) {
      _currentSessionId = sessionId;
    }

    // Guardar cambios en el almacenamiento
    await _saveActiveSessionsToStorage();
    await _saveCurrentSessionToStorage();
    
    notifyListeners();
    return sessionId;
  }

  // Cambiar a una sesión específica
  void switchToSession(String sessionId) {
    if (_activeSessions.containsKey(sessionId)) {
      _currentSessionId = sessionId;
      
      // Guardar cambio en el almacenamiento
      _saveCurrentSessionToStorage();
      
      notifyListeners();
    }
  }

  // Cerrar una sesión específica
  Future<void> closeSession(String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session != null) {
      // Realizar logout del provider de autenticación
      await session.authProvider.logout(session.user.id);
      
      // Limpiar la sesión
      _activeSessions.remove(sessionId);
      
      // Si era la sesión actual, cambiar a otra disponible
      if (_currentSessionId == sessionId) {
        if (_activeSessions.isNotEmpty) {
          _currentSessionId = _activeSessions.keys.first;
        } else {
          _currentSessionId = null;
        }
      }
      
      // Guardar cambios en el almacenamiento
      await _saveActiveSessionsToStorage();
      await _saveCurrentSessionToStorage();
    }
  }

  // Cerrar todas las sesiones
  Future<void> closeAllSessions() async {
    for (final session in _activeSessions.values) {
      await session.authProvider.logout(session.user.id);
    }
    
    _activeSessions.clear();
    _currentSessionId = null;
    
    // Limpiar almacenamiento
    await _clearSessionStorage();
    notifyListeners();
  }

  // Obtener una sesión específica
  SessionData? getSession(String sessionId) {
    return _activeSessions[sessionId];
  }

  // Verificar si un usuario ya tiene una sesión activa
  bool hasSessionForUser(String userId) {
    return _activeSessions.values
        .any((session) => session.user.id == userId);
  }
  // Obtener la sesión de un usuario específico
  SessionData? getSessionForUser(String userId) {
    try {
      return _activeSessions.values
          .firstWhere((session) => session.user.id == userId);
    } catch (e) {
      return null;
    }
  }

  // Crear o cambiar a la sesión de un usuario
  Future<String> createOrSwitchToUserSession(User user) async {
    // Verificar si ya existe una sesión para este usuario
    final existingSession = _activeSessions.values
        .where((session) => session.user.id == user.id)
        .firstOrNull;

    if (existingSession != null) {
      // Cambiar a la sesión existente
      switchToSession(existingSession.sessionId);
      return existingSession.sessionId;
    } else {
      // Crear nueva sesión
      return await createSession(user);
    }
  }

  // Inicializar las sesiones desde el almacenamiento persistente
  Future<void> _initializeFromStorage() async {
    try {
      // Cargar sesiones activas desde el almacenamiento
      final activeSessionsData = await _loadActiveSessionsFromStorage();
      
      for (final sessionInfo in activeSessionsData) {
        final userId = sessionInfo['userId'] as String;
        final sessionId = sessionInfo['sessionId'] as String;
        
        // Verificar que el usuario aún esté autenticado
        final users = await SecureStorage.getAuthenticatedUsers();
        final user = users[userId];
        
        if (user != null) {
          // Recrear la sesión
          await _recreateSession(sessionId, user);
        }
      }
      
      // Cargar la sesión actual
      final currentSessionId = await _loadCurrentSessionFromStorage();
      if (currentSessionId != null && _activeSessions.containsKey(currentSessionId)) {
        _currentSessionId = currentSessionId;
      } else if (_activeSessions.isNotEmpty) {
        _currentSessionId = _activeSessions.keys.first;
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error al inicializar sesiones desde almacenamiento: $e');
      }
    }
  }

  // Recrear una sesión desde los datos almacenados
  Future<void> _recreateSession(String sessionId, User user) async {
    try {
      // Crear providers independientes para esta sesión
      final authProvider = AuthProvider();
      final themeProvider = ThemeProvider();
      final taskProvider = TaskProvider();

      // Inicializar el provider de autenticación con el usuario
      await authProvider.initializeWithUser(user.id);
      await taskProvider.setCurrentUser(user.id);

      final sessionData = SessionData(
        authProvider: authProvider,
        taskProvider: taskProvider,
        themeProvider: themeProvider,
        sessionId: sessionId,
        user: user,
      );

      _activeSessions[sessionId] = sessionData;
    } catch (e) {
      if (kDebugMode) {
        print('Error al recrear sesión $sessionId: $e');
      }
    }
  }

  // Cargar información de sesiones activas desde el almacenamiento
  Future<List<Map<String, dynamic>>> _loadActiveSessionsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getString(_activeSessionsKey);
      
      if (sessionsJson != null) {
        final List<dynamic> sessionsList = json.decode(sessionsJson);
        return sessionsList.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar sesiones activas: $e');
      }
    }
    
    return [];
  }

  // Cargar la sesión actual desde el almacenamiento
  Future<String?> _loadCurrentSessionFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentSessionKey);
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar sesión actual: $e');
      }
      return null;
    }
  }

  // Guardar información de sesiones activas en el almacenamiento
  Future<void> _saveActiveSessionsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final sessionsList = _activeSessions.values.map((session) => {
        'sessionId': session.sessionId,
        'userId': session.user.id,
        'userName': session.user.name,
        'userEmail': session.user.email,
      }).toList();
      
      await prefs.setString(_activeSessionsKey, json.encode(sessionsList));
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar sesiones activas: $e');
      }
    }
  }

  // Guardar la sesión actual en el almacenamiento
  Future<void> _saveCurrentSessionToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_currentSessionId != null) {
        await prefs.setString(_currentSessionKey, _currentSessionId!);
      } else {
        await prefs.remove(_currentSessionKey);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar sesión actual: $e');
      }
    }
  }

  @override
  void dispose() {
    // Limpiar todas las sesiones al destruir el provider
    closeAllSessions();
    super.dispose();
  }

  // Limpiar datos de sesiones del almacenamiento
  Future<void> _clearSessionStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeSessionsKey);
      await prefs.remove(_currentSessionKey);
    } catch (e) {
      if (kDebugMode) {
        print('Error al limpiar almacenamiento de sesiones: $e');
      }
    }
  }
}

// Extension para facilitar el acceso a elementos nulos
extension _FirstWhereOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }
}
