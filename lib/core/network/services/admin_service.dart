import 'dart:convert';
import '../api_client.dart';
import '../../../features/auth/domain/usuario_model.dart';

class AdminService {
  // GET /api/admin/usuarios — Listar todos los usuarios
  static Future<List<Usuario>> listarUsuarios() async {
    final response = await ApiClient.get('/api/admin/usuarios');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Usuario.fromJson(json)).toList();
    } else {
      throw Exception('Error al listar usuarios');
    }
  }

  // POST /api/admin/usuarios — Crear un admin (SUPER_ADMIN only)
  static Future<Usuario> crearAdmin(String nombre, String email, String password) async {
    final response = await ApiClient.post(
      '/api/admin/usuarios',
      body: {'nombre': nombre, 'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      return Usuario.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['mensaje'] ?? error['error'] ?? 'Error al crear admin');
    }
  }

  // PUT /api/admin/usuarios/{userId}/rol?rol=ROLE
  static Future<Usuario> cambiarRol(int userId, String nuevoRol) async {
    final response = await ApiClient.put(
      '/api/admin/usuarios/$userId/rol?rol=$nuevoRol',
    );

    if (response.statusCode == 200) {
      return Usuario.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['mensaje'] ?? error['error'] ?? 'Error al cambiar rol');
    }
  }

  // DELETE /api/admin/usuarios/{userId}
  static Future<void> eliminarUsuario(int userId) async {
    final response = await ApiClient.delete('/api/admin/usuarios/$userId');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Error al eliminar usuario');
    }
  }
}
