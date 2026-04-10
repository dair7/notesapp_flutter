import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/notes/domain/nota_model.dart';
import 'package:notes_app/core/enums/estado_note_type.dart';
import 'package:notes_app/core/network/services/notas_service.dart';
import 'package:notes_app/core/network/api_client.dart';

class NotesNotifier extends AsyncNotifier<List<Nota>> {

  @override
  Future<List<Nota>> build() async {
    final userId = await ApiClient.getUserId();
    if (userId == null) return [];
    return await NotasService.obtenerNotas(userId);
  }

  // Crear nota en el backend
  Future<void> addNota(Nota nuevaNota) async {
    final userId = await ApiClient.getUserId();
    if (userId == null) return;

    final notaCreada = await NotasService.crearNota(
      userId,
      nuevaNota.titulo,
      nuevaNota.contenido,
      color: nuevaNota.color,
      etiquetas: nuevaNota.etiquetas,
    );

    final notasActuales = state.value ?? [];
    state = AsyncData([notaCreada, ...notasActuales]);
  }

  // Actualizar nota en el backend
  Future<void> updateNota(Nota notaActualizada) async {
    if (notaActualizada.id == null) return;

    final notaUpdated = await NotasService.actualizarNota(
      notaActualizada.id!,
      notaActualizada.titulo,
      notaActualizada.contenido,
      color: notaActualizada.color,
      etiquetas: notaActualizada.etiquetas,
    );

    final notasActuales = state.value ?? [];
    final nuevasNotas = notasActuales.map((nota) {
      return nota.id == notaUpdated.id ? notaUpdated : nota;
    }).toList();

    state = AsyncData(nuevasNotas);
  }

  // Cambiar estado de nota (ACTIVA, ARCHIVADA, ELIMINADA) — llama al backend
  Future<void> cambiarEstado(int notaId, String nuevoEstado) async {
    final notaUpdated = await NotasService.cambiarEstado(notaId, nuevoEstado);

    final notasActuales = state.value ?? [];
    final nuevasNotas = notasActuales.map((nota) {
      return nota.id == notaUpdated.id ? notaUpdated : nota;
    }).toList();

    state = AsyncData(nuevasNotas);
  }

  // Cambio de estado solo local (sin llamada al backend) — para UI optimista
  void cambiarEstadoLocal(int notaId, String nuevoEstado) {
    final notasActuales = state.value ?? [];
    final nuevasNotas = notasActuales.map((nota) {
      if (nota.id != notaId) return nota;
      // Se preservan color y etiquetas en el cambio local de estado
      return Nota(
        id: nota.id,
        titulo: nota.titulo,
        contenido: nota.contenido,
        fechaCreacion: nota.fechaCreacion,
        estado: EstadoNoteType.fromString(nuevoEstado),
        usuarioId: nota.usuarioId,
        usuarioNombre: nota.usuarioNombre,
        esAnclada: nota.esAnclada,
        color: nota.color,
        etiquetas: nota.etiquetas,
      );
    }).toList();
    state = AsyncData(nuevasNotas);
  }

  // Eliminar nota del backend (permanente)
  Future<void> deleteNota(int? notaId) async {
    if (notaId == null) return;

    await NotasService.eliminarNota(notaId);

    final notasActuales = state.value ?? [];
    final nuevasNotas = notasActuales.where((n) => n.id != notaId).toList();

    state = AsyncData(nuevasNotas);
  }

  // Anclar / Desanclar lote (múltiples notas)
  Future<void> anclarNotasMasivo(List<int> notasIds, bool estadoAnclado) async {
    try {
      await NotasService.anclarNotasLote(notasIds, estadoAnclado);

      if (state.hasValue) {
        final actuales = state.value!;
        final actualizadas = actuales.map((nota) {
           if (notasIds.contains(nota.id)) {
              // Se preservan color y etiquetas al anclar masivamente
              return Nota(
                 id: nota.id,
                 titulo: nota.titulo,
                 contenido: nota.contenido,
                 estado: nota.estado,
                 fechaCreacion: nota.fechaCreacion,
                 usuarioId: nota.usuarioId,
                 usuarioNombre: nota.usuarioNombre,
                 esAnclada: estadoAnclado,
                 color: nota.color,
                 etiquetas: nota.etiquetas,
              );
           }
           return nota;
        }).toList();
        state = AsyncValue.data(actualizadas);
      }
    } catch (e) {
      throw Exception('Error al anclar masivamente: $e');
    }
  }

  // Refrescar la lista desde el backend
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }
}

final notesProvider = AsyncNotifierProvider<NotesNotifier, List<Nota>>(() {
  return NotesNotifier();
});

// CLASE NOTIFIER PARA RIVERPOD 3.X (Reemplazo de StateProvider)
class SelectionModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false; // Valor inicial
  }

  void toggle(bool value) {
    state = value;
  }
}

// Provider para estado de Multi-Selección
final selectionModeProvider = NotifierProvider<SelectionModeNotifier, bool>(() {
  return SelectionModeNotifier();
});
