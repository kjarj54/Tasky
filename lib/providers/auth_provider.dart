import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/auth.dart';
import '../services/api_service.dart';
import '../db/task_database.dart';

class AuthProvider extends ChangeNotifier {
  static const String _sessionsKey = 'user_sessions';
  static const String _activeUserKey = 'active_user_id';
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();
    List<UserSession> _sessions = [];
  UserSession? _activeSession;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  // Getters
  List<UserSession> get sessions => List.unmodifiable(_sessions);
  UserSession? get activeSession => _activeSession;
  User? get currentUser => _activeSession?.user;
  bool get isAuthenticated => _activeSession != null;
  bool get hasMultipleAccounts => _sessions.length > 1;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  AuthProvider() {
    // Don't auto-load sessions in constructor to avoid loading issues
  }  // Initialize the provider (call once during app startup)
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Ensure database schema exists
    await TaskDatabase.instance.ensureSchemaExists();
    
    await _loadSessions();
    _isInitialized = true;
    notifyListeners(); // Notify after initialization is complete
  }
  // Load saved sessions from secure storage
  Future<void> _loadSessions() async {
    // Don't set loading during initialization to avoid build-time notifications
    final bool shouldNotify = _isInitialized;
    
    if (shouldNotify) {
      _setLoading(true);
    } else {
      _isLoading = true;
    }
    
    try {
      final sessionsJson = await _storage.read(key: _sessionsKey);
      final activeUserIdStr = await _storage.read(key: _activeUserKey);
      
      if (sessionsJson != null) {
        final sessionsList = jsonDecode(sessionsJson) as List;
        _sessions = sessionsList.map((json) => UserSession.fromMap(json)).toList();
          // Set active session
        if (activeUserIdStr != null) {
          final activeUserId = int.parse(activeUserIdStr);
          try {
            _activeSession = _sessions.firstWhere(
              (session) => session.user.id == activeUserId,
            );
          } catch (e) {
            // If user not found, use first session
            _activeSession = _sessions.isNotEmpty ? _sessions.first : null;
          }
        } else if (_sessions.isNotEmpty) {
          _activeSession = _sessions.first;
        }
        
        // Update all sessions to reflect active state
        _updateActiveStates();
        
        // Try to refresh tokens for all sessions
        await _refreshAllTokens();
      }
    } catch (e) {
      _error = 'Error al cargar sesiones: $e';
      // Don't call _setError during initialization
    } finally {
      _isLoading = false;
      if (shouldNotify) {
        notifyListeners();
      }
    }
  }

  // Save sessions to secure storage
  Future<void> _saveSessions() async {
    try {
      final sessionsJson = jsonEncode(_sessions.map((s) => s.toMap()).toList());
      await _storage.write(key: _sessionsKey, value: sessionsJson);
      
      if (_activeSession != null) {
        await _storage.write(key: _activeUserKey, value: _activeSession!.user.id.toString());
      } else {
        await _storage.delete(key: _activeUserKey);
      }
    } catch (e) {
      _setError('Error al guardar sesiones: $e');
    }
  }

  // Update active states for all sessions
  void _updateActiveStates() {
    for (int i = 0; i < _sessions.length; i++) {
      _sessions[i] = _sessions[i].copyWith(
        isActive: _activeSession != null && _sessions[i].user.id == _activeSession!.user.id,
        lastActivity: _activeSession != null && _sessions[i].user.id == _activeSession!.user.id 
            ? DateTime.now() 
            : _sessions[i].lastActivity,
      );
    }
  }
  // Register new user
  Future<void> register(String name, String email, String password) async {
    _setLoading(true);
    _clearError();
    
    try {
      final authResponse = await _apiService.register(name, email, password);
      
      // Ensure database schema exists before inserting user
      await TaskDatabase.instance.ensureSchemaExists();
      
      await _addSession(authResponse);
      await TaskDatabase.instance.insertUser(authResponse.user);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Login user
  Future<void> login(String email, String password) async {
    _setLoading(true);
    _clearError();
    
    try {
      final authResponse = await _apiService.login(email, password);
      
      // Ensure database schema exists before inserting user
      await TaskDatabase.instance.ensureSchemaExists();
      
      await _addSession(authResponse);
      await TaskDatabase.instance.insertUser(authResponse.user);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Add new session or update existing one
  Future<void> _addSession(AuthResponse authResponse) async {
    final newSession = UserSession(
      user: authResponse.user,
      token: authResponse.token,
      refreshToken: authResponse.refreshToken,
      isActive: true,
    );

    // Remove existing session for this user if it exists
    _sessions.removeWhere((session) => session.user.id == authResponse.user.id);
    
    // Add new session
    _sessions.add(newSession);
    _activeSession = newSession;
    
    _updateActiveStates();
    await _saveSessions();
    notifyListeners();
  }
  // Switch to different user account
  Future<void> switchAccount(int userId) async {
    try {
      final session = _sessions.firstWhere(
        (s) => s.user.id == userId,
      );

      _activeSession = session;
      _updateActiveStates();
      await _saveSessions();
      notifyListeners();
    } catch (e) {
      throw Exception('Usuario no encontrado');
    }
  }

  // Logout current user
  Future<void> logout() async {
    if (_activeSession == null) return;

    _setLoading(true);
    try {
      await _apiService.logout(_activeSession!.token, _activeSession!.refreshToken);
    } catch (e) {
      // Continue with logout even if API call fails
    }

    _sessions.removeWhere((session) => session.user.id == _activeSession!.user.id);
    
    if (_sessions.isNotEmpty) {
      _activeSession = _sessions.first;
      _updateActiveStates();
    } else {
      _activeSession = null;
    }

    await _saveSessions();
    _setLoading(false);
    notifyListeners();
  }
  // Logout specific user
  Future<void> logoutUser(int userId) async {
    UserSession session;
    try {
      session = _sessions.firstWhere(
        (s) => s.user.id == userId,
      );
    } catch (e) {
      throw Exception('Usuario no encontrado');
    }

    _setLoading(true);
    try {
      await _apiService.logout(session.token, session.refreshToken);
    } catch (e) {
      // Continue with logout even if API call fails
    }

    _sessions.removeWhere((s) => s.user.id == userId);
    
    if (_activeSession?.user.id == userId) {
      _activeSession = _sessions.isNotEmpty ? _sessions.first : null;
      _updateActiveStates();
    }

    await _saveSessions();
    _setLoading(false);
    notifyListeners();
  }

  // Logout all users
  Future<void> logoutAll() async {
    _setLoading(true);
    
    // Try to logout all sessions from the server
    for (final session in _sessions) {
      try {
        await _apiService.logout(session.token, session.refreshToken);
      } catch (e) {
        // Continue even if some logout calls fail
      }
    }

    _sessions.clear();
    _activeSession = null;
    await _storage.deleteAll();
    
    _setLoading(false);
    notifyListeners();
  }

  // Refresh tokens for all sessions
  Future<void> _refreshAllTokens() async {
    for (int i = 0; i < _sessions.length; i++) {
      try {
        final authResponse = await _apiService.refreshToken(_sessions[i].refreshToken);
        _sessions[i] = _sessions[i].copyWith(
          token: authResponse.token,
          refreshToken: authResponse.refreshToken,
        );
        
        if (_activeSession?.user.id == _sessions[i].user.id) {
          _activeSession = _sessions[i];
        }
      } catch (e) {
        // If refresh fails, remove the session
        if (_activeSession?.user.id == _sessions[i].user.id) {
          _activeSession = null;
        }
        _sessions.removeAt(i);
        i--; // Adjust index after removal
      }
    }
    
    if (_sessions.isEmpty) {
      _activeSession = null;
    } else if (_activeSession == null) {
      _activeSession = _sessions.first;
      _updateActiveStates();
    }
    
    await _saveSessions();
    notifyListeners();
  }

  // Get valid token for current user
  Future<String?> getValidToken() async {
    if (_activeSession == null) return null;

    try {
      // Try to use current token first
      await _apiService.getCurrentUser(_activeSession!.token);
      return _activeSession!.token;
    } catch (e) {
      // Token might be expired, try to refresh
      try {
        final authResponse = await _apiService.refreshToken(_activeSession!.refreshToken);
        _activeSession = _activeSession!.copyWith(
          token: authResponse.token,
          refreshToken: authResponse.refreshToken,
        );
        
        // Update session in list
        final sessionIndex = _sessions.indexWhere((s) => s.user.id == _activeSession!.user.id);
        if (sessionIndex >= 0) {
          _sessions[sessionIndex] = _activeSession!;
        }
        
        await _saveSessions();
        notifyListeners();
        
        return _activeSession!.token;
      } catch (refreshError) {
        // Refresh failed, remove session
        await logoutUser(_activeSession!.user.id);
        return null;
      }
    }
  }

  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
