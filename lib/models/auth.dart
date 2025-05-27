import 'user.dart';

class AuthResponse {
  final String token;
  final String refreshToken;
  final User user;

  AuthResponse({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromMap(Map<String, dynamic> map) => AuthResponse(
    token: map['token'],
    refreshToken: map['refresh_token'],
    user: User.fromMap(map['user']),
  );
}

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toMap() => {
    'email': email,
    'password': password,
  };
}

class RegisterRequest {
  final String email;
  final String password;
  final String name;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.name,
  });

  Map<String, dynamic> toMap() => {
    'email': email,
    'password': password,
    'name': name,
  };
}
