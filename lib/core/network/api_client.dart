import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:notes_app/core/config/app_config.dart';

class ApiClient {

  static const String baseUrl = AppConfig.baseUrl;
  

  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'jwt_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';

  // Flag para evitar múltiples refreshes simultáneos
  static bool _isRefreshing = false;

  // ── Token (almacenamiento seguro) ─────────────────
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  static Future<void> saveUserId(int id) async {
    await _storage.write(key: _userIdKey, value: id.toString());
  }

  static Future<int?> getUserId() async {
    final value = await _storage.read(key: _userIdKey);
    return value != null ? int.tryParse(value) : null;
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
  }

  // ── Headers ────────────────────────────────────────
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // ── Auto-refresh: renovar token si recibimos 401 ──
  static Future<http.Response> _withAutoRefresh(
    Future<http.Response> Function() request, {
    bool auth = true,
  }) async {
    final response = await request();

    // Si no es 401/403 o no requiere auth, retornar directamente
    if ((response.statusCode != 401 && response.statusCode != 403) || !auth) return response;

    print('[ApiClient] ⚠️ Recibido 401 — intentando refresh token...');

    // Intentar refresh
    final refreshed = await _tryRefreshToken();
    if (!refreshed) {
      print('[ApiClient] ❌ Refresh falló — retornando 401 original');
      return response;
    }

    print('[ApiClient] ✅ Refresh exitoso — reintentando request...');
    // Reintentar el request original con el nuevo token
    return await request();
  }

  /// Intenta renovar el access token usando el refresh token
  static Future<bool> _tryRefreshToken() async {
    if (_isRefreshing) {
      print('[ApiClient] ⏳ Ya hay un refresh en progreso, esperando...');
      // Esperar a que termine el refresh en curso
      while (_isRefreshing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // Verificar si hay un token nuevo después de esperar
      final token = await getToken();
      return token != null;
    }
    _isRefreshing = true;

    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        print('[ApiClient] ❌ No hay refresh token almacenado');
        return false;
      }

      print('[ApiClient] 🔄 Llamando POST /api/auth/refresh-token...');
      final url = Uri.parse('$baseUrl/api/auth/refresh-token');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      print('[ApiClient] 📩 Respuesta refresh: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['token']);
        await saveRefreshToken(data['refreshToken']);
        print('[ApiClient] ✅ Nuevos tokens guardados');
        return true;
      } else {
        print('[ApiClient] ❌ Refresh falló: ${response.body}');
        await clearSession();
        return false;
      }
    } catch (e) {
      print('[ApiClient] ❌ Error en refresh: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  // ── HTTP Methods (con auto-refresh) ────────────────
  static Future<http.Response> get(String path, {bool auth = true}) async {
    return _withAutoRefresh(
      () async {
        final url = Uri.parse('$baseUrl$path');
        final headers = await _headers(auth: auth);
        return http.get(url, headers: headers);
      },
      auth: auth,
    );
  }

  static Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    return _withAutoRefresh(
      () async {
        final url = Uri.parse('$baseUrl$path');
        final headers = await _headers(auth: auth);
        return http.post(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      },
      auth: auth,
    );
  }

  static Future<http.Response> put(
    String path, {
    Object? body,
    bool auth = true,
  }) async {
    return _withAutoRefresh(
      () async {
        final url = Uri.parse('$baseUrl$path');
        final headers = await _headers(auth: auth);
        return http.put(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      },
      auth: auth,
    );
  }

  static Future<http.Response> delete(String path, {bool auth = true}) async {
    return _withAutoRefresh(
      () async {
        final url = Uri.parse('$baseUrl$path');
        final headers = await _headers(auth: auth);
        return http.delete(url, headers: headers);
      },
      auth: auth,
    );
  }
}
