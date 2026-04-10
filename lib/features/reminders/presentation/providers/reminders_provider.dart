import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/reminders/domain/recordatorio_model.dart';
import 'package:notes_app/core/network/services/recordatorios_service.dart';
import 'package:notes_app/core/network/api_client.dart';
import 'package:notes_app/core/services/notification_service.dart';

class RemindersNotifier extends AsyncNotifier<List<Recordatorio>> {
  
  @override
  Future<List<Recordatorio>> build() async {
    final userId = await ApiClient.getUserId();
    if (userId == null) return [];
    return await RecordatoriosService.obtenerPorUsuario(userId);
  }

  /// Marcar recordatorio como completado / no completado
  Future<void> toggleCompletado(int? idRecordatorio) async {
    if (idRecordatorio == null) return;

    final updated = await RecordatoriosService.toggleCompletado(idRecordatorio);

    final actuales = state.value ?? [];
    final nuevos = actuales.map((r) {
      return r.id == updated.id ? updated : r;
    }).toList();
    state = AsyncData(nuevos);
  }

  /// Agregar una tarea
  Future<void> addRecordatorio(int notaId, DateTime fecha, Prioridad prioridad) async {
    final nuevo = await RecordatoriosService.crearRecordatorio(notaId, fecha, prioridad);
    // Programar notificación local para la fecha del recordatorio
    if (nuevo.id != null) {
      await NotificationService.programar(
        id: nuevo.id!,
        titutoNota: nuevo.notaTitulo ?? 'Recordatorio de nota',
        fecha: fecha,
      );
    }
    final actuales = state.value ?? [];
    state = AsyncData([nuevo, ...actuales]);
  }

  /// Actualizar la fecha de un recordatorio
  Future<void> actualizarFecha(int idRecordatorio, DateTime nuevaFecha) async {
    final updated = await RecordatoriosService.actualizarFecha(idRecordatorio, nuevaFecha);
    // Cancelar la notificación anterior y reprogramar con la nueva fecha
    await NotificationService.cancelar(idRecordatorio);
    await NotificationService.programar(
      id: idRecordatorio,
      titutoNota: updated.notaTitulo ?? 'Recordatorio de nota',
      fecha: nuevaFecha,
    );
    final actuales = state.value ?? [];
    final nuevos = actuales.map((r) {
      return r.id == updated.id ? updated : r;
    }).toList();
    state = AsyncData(nuevos);
  }

  /// Eliminar un recordatorio
  Future<void> deleteRecordatorio(int? idRecordatorio) async {
    if (idRecordatorio == null) return;

    await RecordatoriosService.eliminarRecordatorio(idRecordatorio);
    // Cancelar la notificación local asociada
    await NotificationService.cancelar(idRecordatorio);

    final actuales = state.value ?? [];
    final nuevos = actuales.where((r) => r.id != idRecordatorio).toList();
    state = AsyncData(nuevos);
  }

  // Refrescar desde el backend
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }
}

final remindersProvider = AsyncNotifierProvider<RemindersNotifier, List<Recordatorio>>(() {
  return RemindersNotifier();
});
