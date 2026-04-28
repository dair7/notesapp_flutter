import 'dart:convert';
import '../api_client.dart';
import '../../../features/notes/domain/nota_model.dart';

class NotasService {
  // POST /api/notas/{usuarioId}
  static Future<Nota> crearNota(
    int usuarioId,
    String titulo,
    String contenido, {
    String? color,
    List<String> etiquetas = const [],
    int? categoriaId,
  }) async {
    final response = await ApiClient.post(
      '/api/notas/$usuarioId',
      body: {
        'titulo': titulo,
        'contenido': contenido,
        'color': color,
        'etiquetas': etiquetas.isEmpty ? null : etiquetas.join(','),
        'categoriaId': categoriaId,
      },
    );

    if (response.statusCode == 200) {
      return Nota.fromJson(jsonDecode(response.body));
    } else {
      String msg = 'Error al crear nota';
      try { msg = jsonDecode(response.body)['mensaje'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // GET /api/notas/usuario/{usuarioId}
  static Future<List<Nota>> obtenerNotas(int usuarioId) async {
    final response = await ApiClient.get('/api/notas/usuario/$usuarioId');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Nota.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener notas');
    }
  }

  // GET /api/notas/usuario/{usuarioId}/estado/{estado}
  static Future<List<Nota>> obtenerNotasPorEstado(int usuarioId, String estado) async {
    final response = await ApiClient.get('/api/notas/usuario/$usuarioId/estado/$estado');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Nota.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener notas');
    }
  }

  // GET /api/notas/{notaId}
  static Future<Nota> obtenerNota(int notaId) async {
    final response = await ApiClient.get('/api/notas/$notaId');

    if (response.statusCode == 200) {
      return Nota.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener nota');
    }
  }

  // PUT /api/notas/{notaId}
  static Future<Nota> actualizarNota(
    int notaId,
    String titulo,
    String contenido, {
    String? color,
    List<String> etiquetas = const [],
    int? categoriaId,
  }) async {
    final response = await ApiClient.put(
      '/api/notas/$notaId',
      body: {
        'titulo': titulo,
        'contenido': contenido,
        'color': color,
        'etiquetas': etiquetas.isEmpty ? null : etiquetas.join(','),
        'categoriaId': categoriaId,
      },
    );

    if (response.statusCode == 200) {
      return Nota.fromJson(jsonDecode(response.body));
    } else {
      String msg = 'Error al actualizar nota';
      try { msg = jsonDecode(response.body)['mensaje'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // PUT /api/notas/{notaId}/estado?estado=ESTADO
  static Future<Nota> cambiarEstado(int notaId, String estado) async {
    final response = await ApiClient.put('/api/notas/$notaId/estado?estado=$estado');

    if (response.statusCode == 200) {
      return Nota.fromJson(jsonDecode(response.body));
    } else {
      String msg = 'Error al cambiar estado';
      try { msg = jsonDecode(response.body)['mensaje'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // PUT /api/notas/anclar?anclar=true o false (body: List<Long> notasIds)
  static Future<void> anclarNotasLote(List<int> notasIds, bool anclar) async {
    final response = await ApiClient.put(
      '/api/notas/anclar?anclar=$anclar',
      body: notasIds,
    );

    if (response.statusCode != 200) {
       throw Exception('Error al anclar notas');
    }
  }

  // DELETE /api/notas/{notaId}
  static Future<void> eliminarNota(int notaId) async {
    final response = await ApiClient.delete('/api/notas/$notaId');

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Error al eliminar nota');
    }
  }
}
