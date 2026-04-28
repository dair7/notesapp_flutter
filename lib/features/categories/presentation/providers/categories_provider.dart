import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/services/categorias_service.dart';
import '../../domain/categoria_model.dart';

// Provider para el estado de categorías (recargable)
final categoriasNotifierProvider = AsyncNotifierProvider<CategoriasNotifier, List<Categoria>>(() {
  return CategoriasNotifier();
});

class CategoriasNotifier extends AsyncNotifier<List<Categoria>> {

  @override
  Future<List<Categoria>> build() async {
    return await CategoriasService.obtenerCategorias();
  }

  Future<void> refrescar() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }

  Future<void> crearCategoria(String nombre, {String? colorHex}) async {
    try {
      final nueva = await CategoriasService.crearCategoria(nombre, colorHex: colorHex);
      final listaActual = state.value ?? [];
      state = AsyncData([...listaActual, nueva]);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> actualizarCategoria(int id, String nombre, {String? colorHex}) async {
    try {
      final actualizada = await CategoriasService.actualizarCategoria(id, nombre, colorHex: colorHex);
      final listaActual = state.value ?? [];
      state = AsyncData(
        listaActual.map((c) => c.id == id ? actualizada : c).toList(),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> eliminarCategoria(int id) async {
    try {
      await CategoriasService.eliminarCategoria(id);
      final listaActual = state.value ?? [];
      state = AsyncData(
        listaActual.where((c) => c.id != id).toList(),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

// Provider para categoría seleccionada (para notas)
class CategoriaSeleccionadaNotifier extends Notifier<Categoria?> {
  @override
  Categoria? build() {
    return null;
  }

  void seleccionar(Categoria? categoria) {
    state = categoria;
  }
}

final categoriaSeleccionadaProvider = NotifierProvider<CategoriaSeleccionadaNotifier, Categoria?>(() {
  return CategoriaSeleccionadaNotifier();
});
