import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../models/user.dart';
import '../models/auth.dart';
import '../services/auth_service.dart';
import '../services/secure_storage.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.initial;
  User? _currentUser;
  Map<String, User> _authenticatedUsers = {};
  String? _error;
  bool _isLoading = false;

  // Getters
  AuthState get state => _state;
  User? get currentUser => _currentUser;
  Map<String, User> get authenticatedUsers => Map.unmodifiable(_authenticatedUsers);
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _state == AuthState.authenticated && _currentUser != null;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _setLoading(true);
    try {
      // Cargar usuarios autenticados
      _authenticatedUsers = await SecureStorage.getAuthenticatedUsers();
      
      // Verificar si hay un usuario actual válido
      final token = await SecureStorage.getToken();
      if (token != null && !JwtDecoder.isExpired(token)) {
        _currentUser = await SecureStorage.getCurrentUser();
        if (_currentUser != null) {
          _setState(AuthState.authenticated);
        } else {
          _setState(AuthState.unauthenticated);
        }
      } else {
        // Token expirado, intentar refrescar
        await _tryRefreshToken();
      }
    } catch (e) {
      _setError('Error al inicializar autenticación: $e');
      _setState(AuthState.unauthenticated);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _tryRefreshToken() async {
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken != null && !JwtDecoder.isExpired(refreshToken)) {
        final authResponse = await AuthService.refreshToken(refreshToken);
        await _saveAuthData(authResponse);
        _setState(AuthState.authenticated);
      } else {
        _setState(AuthState.unauthenticated);
      }
    } catch (e) {
      _setState(AuthState.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    _setLoading(true);
    _clearError();
    
    try {
      final loginRequest = LoginRequest(email: email, password: password);
      final authResponse = await AuthService.login(loginRequest);
      
      await _saveAuthData(authResponse);
      _setState(AuthState.authenticated);
    } catch (e) {
      _setError(e.toString());
      _setState(AuthState.error);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(String name, String email, String password) async {
    _setLoading(true);
    _clearError();
    
    try {
      final registerRequest = RegisterRequest(
        name: name,
        email: email,
        password: password,
      );
      final authResponse = await AuthService.register(registerRequest);
      
      await _saveAuthData(authResponse);
      _setState(AuthState.authenticated);
    } catch (e) {
      _setError(e.toString());
      _setState(AuthState.error);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> switchUser(String userId) async {
    if (!_authenticatedUsers.containsKey(userId)) {
      _setError('Usuario no encontrado');
      return;
    }

    _setLoading(true);
    try {
      await SecureStorage.setCurrentUser(userId);
      _currentUser = _authenticatedUsers[userId];
      
      // Verificar que el token siga siendo válido
      final tokens = await SecureStorage.getUserTokens(userId);
      if (tokens != null) {
        final token = tokens['token']!;
        if (JwtDecoder.isExpired(token)) {
          // Intentar refrescar el token
          await _tryRefreshToken();
        } else {
          _setState(AuthState.authenticated);
        }
      }
    } catch (e) {
      _setError('Error al cambiar de usuario: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout([String? userId]) async {
    _setLoading(true);
    try {
      final token = await SecureStorage.getToken();
      if (token != null) {
        try {
          await AuthService.logout(token);
        } catch (e) {
          // Ignorar errores de logout del servidor
        }
      }

      if (userId != null) {
        // Logout de un usuario específico
        await SecureStorage.removeUser(userId);
        _authenticatedUsers.remove(userId);
        
        // Si era el usuario actual, cambiar al siguiente disponible
        if (_currentUser?.id == userId) {
          if (_authenticatedUsers.isNotEmpty) {
            final nextUserId = _authenticatedUsers.keys.first;
            await switchUser(nextUserId);
          } else {
            _currentUser = null;
            _setState(AuthState.unauthenticated);
          }
        }
      } else {
        // Logout completo
        await SecureStorage.clearAllData();
        _currentUser = null;
        _authenticatedUsers.clear();
        _setState(AuthState.unauthenticated);
      }
    } catch (e) {
      _setError('Error al cerrar sesión: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _saveAuthData(AuthResponse authResponse) async {
    _currentUser = authResponse.user;
    _authenticatedUsers[authResponse.user.id] = authResponse.user;
    
    await SecureStorage.saveUser(
      authResponse.user,
      authResponse.token,
      authResponse.refreshToken,
    );
    await SecureStorage.setCurrentUser(authResponse.user.id);
  }

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _setState(AuthState.error);
  }

  void _clearError() {
    _error = null;
  }

  void clearError() {
    _clearError();
    if (_currentUser != null) {
      _setState(AuthState.authenticated);
    } else {
      _setState(AuthState.unauthenticated);
    }
  }

  // Método para configurar una sesión específica del usuario
  Future<void> setUserSession(User user, String token, String refreshToken) async {
    _currentUser = user;
    _authenticatedUsers[user.id] = user;
    
    await SecureStorage.saveUser(user, token, refreshToken);
    await SecureStorage.setCurrentUser(user.id);
    _setState(AuthState.authenticated);
  }

  // Método para verificar si un usuario específico está autenticado
  bool isUserAuthenticated(String userId) {
    return _authenticatedUsers.containsKey(userId);
  }

  // Método para obtener información de un usuario específico
  User? getUserById(String userId) {
    return _authenticatedUsers[userId];
  }

  // Método para inicializar con un usuario específico (para sesiones múltiples)
  Future<void> initializeWithUser(String userId) async {
    if (_authenticatedUsers.containsKey(userId)) {
      await switchUser(userId);
    } else {
      // Cargar usuario desde storage si no está en memoria
      final tokens = await SecureStorage.getUserTokens(userId);
      if (tokens != null) {
        final users = await SecureStorage.getAuthenticatedUsers();
        final user = users[userId];
        if (user != null) {
          _authenticatedUsers[userId] = user;
          await switchUser(userId);
        }
      }
    }
  }
}
