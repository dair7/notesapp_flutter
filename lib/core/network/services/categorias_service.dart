import 'dart:convert';
import '../api_client.dart';
import '../../../features/categories/domain/categoria_model.dart';

class CategoriasService {
  // GET /api/categorias - Obtener todas las categorías
  static Future<List<Categoria>> obtenerCategorias() async {
    final response = await ApiClient.get('/api/categorias');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Categoria.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener categorías');
    }
  }

  // GET /api/categorias/{id} - Obtener categoría por ID
  static Future<Categoria> obtenerCategoria(int id) async {
    final response = await ApiClient.get('/api/categorias/$id');

    if (response.statusCode == 200) {
      return Categoria.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener categoría');
    }
  }

  // POST /api/categorias - Crear categoría (solo admin)
  static Future<Categoria> crearCategoria(String nombre, {String? colorHex}) async {
    final response = await ApiClient.post(
      '/api/categorias',
      body: {
        'nombre': nombre,
        'colorHex': colorHex,
      },
    );

    if (response.statusCode == 201) {
      return Categoria.fromJson(jsonDecode(response.body));
    } else {
      String msg = 'Error al crear categoría';
      try { msg = jsonDecode(response.body)['mensaje'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // PUT /api/categorias/{id} - Actualizar categoría (solo admin)
  static Future<Categoria> actualizarCategoria(int id, String nombre, {String? colorHex}) async {
    final response = await ApiClient.put(
      '/api/categorias/$id',
      body: {
        'nombre': nombre,
        'colorHex': colorHex,
      },
    );

    if (response.statusCode == 200) {
      return Categoria.fromJson(jsonDecode(response.body));
    } else {
      String msg = 'Error al actualizar categoría';
      try { msg = jsonDecode(response.body)['mensaje'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // DELETE /api/categorias/{id} - Eliminar categoría (solo admin)
  static Future<void> eliminarCategoria(int id) async {
    final response = await ApiClient.delete('/api/categorias/$id');

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Error al eliminar categoría');
    }
  }
}
