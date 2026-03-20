import 'dart:convert';
import '../api_client.dart';

class UsuarioService {
  // PUT /api/usuarios/{id} — Actualizar nombre y/o email
  static Future<Map<String, dynamic>> actualizarPerfil(
      int userId, String nombre, String email) async {
    final response = await ApiClient.put(
      '/api/usuarios/$userId',
      body: {'nombre': nombre, 'email': email},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String msg = 'Error al actualizar perfil';
      try { msg = jsonDecode(response.body)['mensaje'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // PUT /api/usuarios/{id}/password — Cambiar contraseña
  static Future<String> cambiarPassword(
      int userId, String currentPassword, String newPassword) async {
    final response = await ApiClient.put(
      '/api/usuarios/$userId/password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      String msg = 'Error al cambiar contraseña';
      try { msg = jsonDecode(response.body)['mensaje'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // DELETE /api/usuarios/me — Eliminar mi cuenta
  static Future<void> eliminarCuenta() async {
    final response = await ApiClient.delete('/api/usuarios/me');

    if (response.statusCode != 204 && response.statusCode != 200) {
      String msg = 'Error al eliminar cuenta';
      try { msg = jsonDecode(response.body)['mensaje'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }
}
