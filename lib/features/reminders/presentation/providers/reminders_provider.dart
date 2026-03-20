import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/reminders/domain/recordatorio_model.dart';
import 'package:notes_app/core/network/services/recordatorios_service.dart';
import 'package:notes_app/core/network/api_client.dart';

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

  /// Agregar un recordatorio
  Future<void> addRecordatorio(int notaId, DateTime fecha) async {
    final nuevo = await RecordatoriosService.crearRecordatorio(notaId, fecha);
    final actuales = state.value ?? [];
    state = AsyncData([nuevo, ...actuales]);
  }

  /// Eliminar un recordatorio
  Future<void> deleteRecordatorio(int? idRecordatorio) async {
    if (idRecordatorio == null) return;

    await RecordatoriosService.eliminarRecordatorio(idRecordatorio);

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
