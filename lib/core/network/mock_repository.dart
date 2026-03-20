import '../enums/estado_note_type.dart';
import '../../features/notes/domain/nota_model.dart';
import '../../features/reminders/domain/recordatorio_model.dart';

class MockRepository {
  // Simulamos la llamada (GET /api/notas/usuario/{id})
  Future<List<Nota>> getNotasRecientes() async {
    await Future.delayed(const Duration(milliseconds: 800));

    return [
      Nota(
        id: 101,
        titulo: 'Arquitectura Flutter + Spring',
        contenido: 'Definir entidades, repositorios y controladores.',
        fechaCreacion: DateTime.now().subtract(const Duration(hours: 2)),
        estado: EstadoNoteType.ACTIVA,
        usuarioId: 1,
        usuarioNombre: 'Elena',
      ),
      Nota(
        id: 102,
        titulo: 'Lista de Supermercado',
        contenido: 'Comprar café, leche de almendras y verduras.',
        fechaCreacion: DateTime.now().subtract(const Duration(days: 1)),
        estado: EstadoNoteType.ACTIVA,
        usuarioId: 1,
        usuarioNombre: 'Elena',
      ),
      Nota(
        id: 103,
        titulo: 'Ideas de Backend',
        contenido: 'Implementar JWT para la seguridad en PostgreSQL.',
        fechaCreacion: DateTime.now().subtract(const Duration(days: 2)),
        estado: EstadoNoteType.ACTIVA,
        usuarioId: 1,
        usuarioNombre: 'Elena',
      ),
    ];
  }

  // Simulamos la llamada (GET /api/recordatorios/usuario/{id})
  Future<List<Recordatorio>> getRecordatoriosProximos() async {
    await Future.delayed(const Duration(milliseconds: 800));

    return [
      Recordatorio(
        id: 1,
        fecha: DateTime.now().add(const Duration(hours: 2)),
        completado: false,
        notaId: 104,
        notaTitulo: 'Reunión de Diseño UI',
      ),
      Recordatorio(
        id: 2,
        fecha: DateTime.now().add(const Duration(hours: 5)),
        completado: false,
        notaId: 105,
        notaTitulo: 'Pagar servidor AWS',
      ),
    ];
  }
}