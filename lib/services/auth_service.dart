import '../models/auth.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  static Future<AuthResponse> login(LoginRequest request) async {
    final response = await ApiService.post('/auth/login', request.toMap());
    return AuthResponse.fromMap(response);
  }

  static Future<AuthResponse> register(RegisterRequest request) async {
    final response = await ApiService.post('/auth/register', request.toMap());
    return AuthResponse.fromMap(response);
  }

  static Future<AuthResponse> refreshToken(String refreshToken) async {
    final response = await ApiService.post('/auth/refresh', {
      'refresh_token': refreshToken,
    });
    return AuthResponse.fromMap(response);
  }

  static Future<User> getCurrentUser(String token) async {
    final response = await ApiService.get('/auth/me', token);
    return User.fromMap(response['user']);
  }

  static Future<void> logout(String token) async {
    await ApiService.post('/auth/logout', {}, token);
  }
}
