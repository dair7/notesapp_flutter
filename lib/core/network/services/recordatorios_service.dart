import 'dart:convert';
import '../api_client.dart';
import '../../../features/reminders/domain/recordatorio_model.dart';

class RecordatoriosService {
  // POST /api/recordatorios/{notaId}
  static Future<Recordatorio> crearRecordatorio(int notaId, DateTime fecha, Prioridad prioridad) async {
    final response = await ApiClient.post(
      '/api/recordatorios/$notaId',
      body: {
        'fecha': fecha.toIso8601String(),
        'prioridad': prioridad.name,
      },
    );

    if (response.statusCode == 200) {
      return Recordatorio.fromJson(jsonDecode(response.body));
    } else {
      String msg = 'Error al crear recordatorio';
      try { msg = jsonDecode(response.body)['mensaje'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // GET /api/recordatorios/usuario/{usuarioId}
  static Future<List<Recordatorio>> obtenerPorUsuario(int usuarioId) async {
    final response = await ApiClient.get('/api/recordatorios/usuario/$usuarioId');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Recordatorio.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener recordatorios');
    }
  }

  // GET /api/recordatorios/pendientes/usuario/{usuarioId}
  static Future<List<Recordatorio>> obtenerPendientes(int usuarioId) async {
    final response = await ApiClient.get('/api/recordatorios/pendientes/usuario/$usuarioId');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Recordatorio.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener recordatorios pendientes');
    }
  }

  // PUT /api/recordatorios/{id}
  static Future<Recordatorio> actualizarFecha(int recordatorioId, DateTime nuevaFecha) async {
    final response = await ApiClient.put(
      '/api/recordatorios/$recordatorioId',
      body: {'fecha': nuevaFecha.toIso8601String()},
    );

    if (response.statusCode == 200) {
      return Recordatorio.fromJson(jsonDecode(response.body));
    } else {
      String msg = 'Error al actualizar recordatorio';
      try { msg = jsonDecode(response.body)['mensaje'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // PUT /api/recordatorios/{id}/completar
  static Future<Recordatorio> toggleCompletado(int recordatorioId) async {
    final response = await ApiClient.put('/api/recordatorios/$recordatorioId/completar');

    if (response.statusCode == 200) {
      return Recordatorio.fromJson(jsonDecode(response.body));
    } else {
      String msg = 'Error al actualizar recordatorio';
      try { msg = jsonDecode(response.body)['mensaje'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // DELETE /api/recordatorios/{id}
  static Future<void> eliminarRecordatorio(int recordatorioId) async {
    final response = await ApiClient.delete('/api/recordatorios/$recordatorioId');

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Error al eliminar recordatorio');
    }
  }
}
