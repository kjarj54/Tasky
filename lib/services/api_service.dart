import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Configuración dinámica de baseUrl según la plataforma
  static String get baseUrl {
    if (kIsWeb) {
      // Para Flutter Web - usar localhost
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      // Para emulador de Android - usar IP especial del emulador
      return 'http://10.0.2.2:3000/api';
    } else if (Platform.isIOS) {
      // Para simulador de iOS - usar localhost
      return 'http://localhost:3000/api';
    } else {
      // Para otras plataformas (Windows, macOS, Linux) - usar localhost
      return 'http://localhost:3000/api';
    }
  }
  
  static const Duration timeout = Duration(seconds: 30);
  
  static Map<String, String> getHeaders([String? token]) {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  
  ApiException(this.message, [this.statusCode]);
  
  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class ApiService {
  static Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return json.decode(response.body);
    } else {
      String errorMessage = 'Error del servidor';
      try {
        final errorBody = json.decode(response.body);
        errorMessage = errorBody['error'] ?? errorBody['message'] ?? errorMessage;
      } catch (e) {
        // Si no se puede parsear el error, usar el mensaje por defecto
      }
      throw ApiException(errorMessage, response.statusCode);
    }
  }

  static Future<Map<String, dynamic>> get(String endpoint, [String? token]) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: ApiConfig.getHeaders(token),
      ).timeout(ApiConfig.timeout);
      
      return await _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión: $e');
    }
  }
  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data, [String? token]) async {
    try {
      print('POST $endpoint');
      print('Request data: ${json.encode(data)}');
        final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: ApiConfig.getHeaders(token),
        body: json.encode(data),
      ).timeout(ApiConfig.timeout);
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      return await _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión: $e');
    }
  }

  static Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data, [String? token]) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: ApiConfig.getHeaders(token),
        body: json.encode(data),
      ).timeout(ApiConfig.timeout);
      
      return await _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión: $e');
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint, [String? token]) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: ApiConfig.getHeaders(token),
      ).timeout(ApiConfig.timeout);
      
      return await _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión: $e');
    }
  }
}
