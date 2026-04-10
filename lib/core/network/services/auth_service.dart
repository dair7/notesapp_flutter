import 'dart:convert';
import '../api_client.dart';

class AuthService {
  // POST /api/auth/login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await ApiClient.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Guardar access token, refresh token y userId
      await ApiClient.saveToken(data['token']);
      if (data['refreshToken'] != null) {
        await ApiClient.saveRefreshToken(data['refreshToken']);
      }
      await ApiClient.saveUserId(data['usuario']['id']);
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['mensaje'] ?? 'Error al iniciar sesión');
    }
  }

  // POST /api/auth/register
  static Future<Map<String, dynamic>> register(String nombre, String email, String password) async {
    final response = await ApiClient.post(
      '/api/auth/register',
      body: {'nombre': nombre, 'email': email, 'password': password},
      auth: false,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['mensaje'] ?? error['error'] ?? 'Error al registrarse');
    }
  }

  // POST /api/auth/forgot-password
  static Future<String> forgotPassword(String email) async {
    final response = await ApiClient.post(
      '/api/auth/forgot-password?email=$email',
      auth: false,
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['mensaje'] ?? 'Error al procesar la solicitud');
    }
  }

  // POST /api/auth/reset-password
  static Future<String> resetPassword(String token, String newPassword) async {
    final response = await ApiClient.post(
      '/api/auth/reset-password',
      body: {'token': token, 'newPassword': newPassword},
      auth: false,
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['mensaje'] ?? 'Error al restablecer contraseña');
    }
  }

  // GET /api/auth/verify
  static Future<String> verifyEmail(String token) async {
    final response = await ApiClient.get(
      '/api/auth/verify?token=$token',
      auth: false,
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['mensaje'] ?? 'Error al verificar la cuenta');
    }
  }

  // Cerrar sesión (invalidar refresh token en backend + limpiar local)
  static Future<void> logout() async {
    try {
      final refreshToken = await ApiClient.getRefreshToken();
      if (refreshToken != null) {
        await ApiClient.post(
          '/api/auth/logout',
          body: {'refreshToken': refreshToken},
          auth: false,
        );
      }
    } catch (_) {
      // Si falla la llamada al backend, igual limpiamos local
    }
    await ApiClient.clearSession();
  }
}

