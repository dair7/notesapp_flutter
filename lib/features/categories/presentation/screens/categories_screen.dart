import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../domain/categoria_model.dart';
import '../providers/categories_provider.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriasAsync = ref.watch(categoriasNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(categoriasNotifierProvider.notifier).refrescar(),
          ),
        ],
      ),
      body: categoriasAsync.when(
        data: (categorias) => _buildCategoriasList(context, ref, categorias),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error al cargar categorías',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(categoriasNotifierProvider.notifier).refrescar(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoriaForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
    );
  }

  Widget _buildCategoriasList(BuildContext context, WidgetRef ref, List<Categoria> categorias) {
    if (categorias.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay categorías',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea una categoría para organizar tus notas',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categorias.length,
      itemBuilder: (context, index) {
        final categoria = categorias[index];
        return _buildCategoriaCard(context, ref, categoria);
      },
    );
  }

  Widget _buildCategoriaCard(BuildContext context, WidgetRef ref, Categoria categoria) {
    final color = _parseColor(categoria.colorHex);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        title: Text(
          categoria.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: categoria.fechaCreacion != null
            ? Text(
                'Creada: ${_formatFecha(categoria.fechaCreacion!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showCategoriaForm(context, ref, categoria: categoria),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _confirmarEliminar(context, ref, categoria),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoriaForm(BuildContext context, WidgetRef ref, {Categoria? categoria}) {
    final nombreController = TextEditingController(text: categoria?.nombre ?? '');
    String colorSeleccionado = categoria?.colorHex ?? '#2A9D8F';
    final coloresPredefinidos = [
      '#FF5733', // Rojo
      '#33FF57', // Verde
      '#3357FF', // Azul
      '#FF33F5', // Rosa
      '#F5FF33', // Amarillo
      '#33FFF5', // Cyan
      '#FF8C33', // Naranja
      '#8C33FF', // Púrpura
      '#2A9D8F', // Teal
      '#E63946', // Rojo oscuro
      '#457B9D', // Azul grisáceo
      '#1D3557', // Azul marino
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(categoria == null ? 'Nueva Categoría' : 'Editar Categoría'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej: Trabajo, Personal, Estudio...',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Color',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: coloresPredefinidos.map((color) {
                    final isSelected = colorSeleccionado == color;
                    return InkWell(
                      onTap: () => setState(() => colorSeleccionado = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _parseColor(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final nombre = nombreController.text.trim();
                if (nombre.isEmpty) {
                  AppSnackBar.error(context, 'El nombre es obligatorio');
                  return;
                }

                Navigator.pop(context);

                try {
                  if (categoria == null) {
                    await ref.read(categoriasNotifierProvider.notifier)
                        .crearCategoria(nombre, colorHex: colorSeleccionado);
                    if (context.mounted) {
                      AppSnackBar.exito(context, 'Categoría creada exitosamente');
                    }
                  } else {
                    await ref.read(categoriasNotifierProvider.notifier)
                        .actualizarCategoria(categoria.id, nombre, colorHex: colorSeleccionado);
                    if (context.mounted) {
                      AppSnackBar.exito(context, 'Categoría actualizada exitosamente');
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppSnackBar.error(context, 'Error: $e');
                  }
                }
              },
              child: Text(categoria == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, WidgetRef ref, Categoria categoria) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text(
          '¿Estás seguro de que deseas eliminar la categoría "${categoria.nombre}"?\n\n'
          'Las notas asociadas a esta categoría quedarán sin categoría.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(categoriasNotifierProvider.notifier)
                    .eliminarCategoria(categoria.id);
                if (context.mounted) {
                  AppSnackBar.exito(context, 'Categoría eliminada');
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackBar.error(context, 'Error al eliminar: $e');
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return Colors.grey;
    }
    try {
      return Color(int.parse(colorHex.replaceFirst('#', ''), radix: 16) + 0xFF000000);
    } catch (e) {
      return Colors.grey;
    }
  }

  String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }
}
