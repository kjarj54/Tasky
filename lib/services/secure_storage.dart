import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class SecureStorage {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _usersKey = 'authenticated_users';
  static const String _currentUserKey = 'current_user_id';

  // Token management
  static Future<void> saveTokens(String token, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  // Multi-user management
  static Future<void> saveUser(User user, String token, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing users
    final usersJson = prefs.getString(_usersKey) ?? '{}';
    final Map<String, dynamic> users = json.decode(usersJson);
    
    // Add or update user
    users[user.id] = {
      'user': user.toMap(),
      'token': token,
      'refresh_token': refreshToken,
      'last_login': DateTime.now().toIso8601String(),
    };
    
    // Save updated users
    await prefs.setString(_usersKey, json.encode(users));
  }

  static Future<Map<String, User>> getAuthenticatedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey) ?? '{}';
    final Map<String, dynamic> usersData = json.decode(usersJson);
    
    final Map<String, User> users = {};
    for (final entry in usersData.entries) {
      final userData = entry.value['user'];
      users[entry.key] = User.fromMap(userData);
    }
    
    return users;
  }

  static Future<void> setCurrentUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, userId);
    
    // Also update the current tokens
    final usersJson = prefs.getString(_usersKey) ?? '{}';
    final Map<String, dynamic> users = json.decode(usersJson);
    
    if (users.containsKey(userId)) {
      final userData = users[userId];
      await prefs.setString(_tokenKey, userData['token']);
      await prefs.setString(_refreshTokenKey, userData['refresh_token']);
    }
  }

  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserKey);
  }

  static Future<User?> getCurrentUser() async {
    final userId = await getCurrentUserId();
    if (userId == null) return null;
    
    final users = await getAuthenticatedUsers();
    return users[userId];
  }

  static Future<Map<String, String>?> getUserTokens(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey) ?? '{}';
    final Map<String, dynamic> users = json.decode(usersJson);
    
    if (users.containsKey(userId)) {
      final userData = users[userId];
      return {
        'token': userData['token'],
        'refresh_token': userData['refresh_token'],
      };
    }
    
    return null;
  }

  static Future<void> removeUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Remove from users list
    final usersJson = prefs.getString(_usersKey) ?? '{}';
    final Map<String, dynamic> users = json.decode(usersJson);
    users.remove(userId);
    await prefs.setString(_usersKey, json.encode(users));
    
    // If it was the current user, clear current tokens
    final currentUserId = await getCurrentUserId();
    if (currentUserId == userId) {
      await clearTokens();
      await prefs.remove(_currentUserKey);
    }
  }

  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_usersKey);
    await prefs.remove(_currentUserKey);
  }
}
