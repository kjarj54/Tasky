import 'user.dart';

class AuthResponse {
  final User user;
  final String token;
  final String refreshToken;

  AuthResponse({
    required this.user,
    required this.token,
    required this.refreshToken,
  });

  Map<String, dynamic> toMap() => {
    'user': user.toMap(),
    'token': token,
    'refresh_token': refreshToken,
  };

  factory AuthResponse.fromMap(Map<String, dynamic> map) => AuthResponse(
    user: User.fromMap(map['user']),
    token: map['token'],
    refreshToken: map['refresh_token'],
  );

  @override
  String toString() {
    return 'AuthResponse(user: $user, token: $token, refreshToken: $refreshToken)';
  }
}

class UserSession {
  final User user;
  final String token;
  final String refreshToken;
  final DateTime lastActivity;
  final bool isActive;

  UserSession({
    required this.user,
    required this.token,
    required this.refreshToken,
    DateTime? lastActivity,
    this.isActive = false,
  }) : lastActivity = lastActivity ?? DateTime.now();

  UserSession copyWith({
    User? user,
    String? token,
    String? refreshToken,
    DateTime? lastActivity,
    bool? isActive,
  }) {
    return UserSession(
      user: user ?? this.user,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      lastActivity: lastActivity ?? this.lastActivity,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() => {
    'user': user.toMap(),
    'token': token,
    'refresh_token': refreshToken,
    'last_activity': lastActivity.toIso8601String(),
    'is_active': isActive,
  };

  factory UserSession.fromMap(Map<String, dynamic> map) => UserSession(
    user: User.fromMap(map['user']),
    token: map['token'],
    refreshToken: map['refresh_token'],
    lastActivity: DateTime.parse(map['last_activity']),
    isActive: map['is_active'] ?? false,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSession && other.user.id == user.id;
  }

  @override
  int get hashCode => user.id.hashCode;

  @override
  String toString() {
    return 'UserSession(user: ${user.name}, isActive: $isActive, lastActivity: $lastActivity)';
  }
}
