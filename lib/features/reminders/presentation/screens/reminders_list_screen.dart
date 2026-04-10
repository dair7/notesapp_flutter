import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/reminders/domain/recordatorio_model.dart';
import 'package:notes_app/features/reminders/presentation/providers/reminders_provider.dart';
import 'package:notes_app/core/widgets/custom_date_picker.dart';
import 'package:notes_app/core/widgets/custom_time_picker.dart';
import 'package:notes_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:notes_app/core/utils/app_snackbar.dart';

// Filtros disponibles para la lista
enum _FiltroRecordatorio { todos, pendientes, completados }

class RemindersListScreen extends ConsumerStatefulWidget {
  const RemindersListScreen({super.key});

  @override
  ConsumerState<RemindersListScreen> createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends ConsumerState<RemindersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _FiltroRecordatorio _filtro = _FiltroRecordatorio.todos;
  bool _isSearching = false;
  Color _accentColor = const Color(0xFF2A9D8F);

  // Modo selección múltiple
  bool _modoSeleccion = false;
  final Set<int> _seleccionados = {};
  bool _ignorarTap = false;
  bool? _seleccionandoCompletadas; // true = solo completadas, false = solo pendientes

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Calcula texto relativo de tiempo
  String _tiempoRestante(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = fecha.difference(ahora);

    if (diferencia.isNegative) {
      if (diferencia.inMinutes.abs() < 60) {
        return 'Hace ${diferencia.inMinutes.abs()} min';
      } else if (diferencia.inHours.abs() < 24) {
        return 'Hace ${diferencia.inHours.abs()} h';
      } else {
        return 'Hace ${diferencia.inDays.abs()} día${diferencia.inDays.abs() == 1 ? '' : 's'}';
      }
    } else {
      if (diferencia.inMinutes < 60) {
        return 'En ${diferencia.inMinutes} min';
      } else if (diferencia.inHours < 24) {
        return 'En ${diferencia.inHours} h';
      } else {
        return 'En ${diferencia.inDays} día${diferencia.inDays == 1 ? '' : 's'}';
      }
    }
  }

  String _formatFechaCompleta(DateTime date) {
    final meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return "${date.day} ${meses[date.month - 1]} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  /// Determina color según urgencia
  Color _colorUrgencia(DateTime fecha, bool completado) {
    if (completado) return Colors.grey;
    final diferencia = fecha.difference(DateTime.now());
    if (diferencia.isNegative) return Colors.redAccent;
    if (diferencia.inHours < 1) return Colors.orange;
    if (diferencia.inHours < 6) return _accentColor;
    return Colors.blueAccent;
  }

  IconData _iconoUrgencia(DateTime fecha, bool completado) {
    if (completado) return Icons.check_circle;
    final diferencia = fecha.difference(DateTime.now());
    if (diferencia.isNegative) return Icons.warning_amber_rounded;
    if (diferencia.inHours < 1) return Icons.notifications_active;
    return Icons.notifications_outlined;
  }

  /// Aplica búsqueda y filtro activo a la lista completa
  List<Recordatorio> _aplicarFiltros(List<Recordatorio> todos) {
    var resultado = todos;

    // Filtro de estado
    if (_filtro == _FiltroRecordatorio.pendientes) {
      resultado = resultado.where((r) => !r.completado).toList();
    } else if (_filtro == _FiltroRecordatorio.completados) {
      resultado = resultado.where((r) => r.completado).toList();
    }

    // Búsqueda por título de nota
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      resultado = resultado.where((r) =>
        (r.notaTitulo ?? '').toLowerCase().contains(q)
      ).toList();
    }

    return resultado;
  }


  Future<void> _editarRecordatorio(Recordatorio recordatorio) async {
    final ahora = DateTime.now();

    final fecha = await mostrarDatePickerPersonalizado(
      context: context,
      fechaInicial: recordatorio.fecha.isAfter(ahora) ? recordatorio.fecha : ahora.add(const Duration(days: 1)),
      fechaMinima: ahora,
      fechaMaxima: DateTime(ahora.year + 5),
    );
    if (fecha == null || !mounted) return;

    final hora = await mostrarTimePickerPersonalizado(
      context: context,
      horaInicial: TimeOfDay.fromDateTime(recordatorio.fecha),
    );
    if (hora == null || !mounted) return;

    final nuevaFecha = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);

    try {
      await ref.read(remindersProvider.notifier).actualizarFecha(recordatorio.id!, nuevaFecha);
      if (mounted) {
        AppSnackBar.exito(context, 'Tarea actualizada');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _confirmarEliminar(Recordatorio recordatorio) {
    final nombreNota = recordatorio.notaTitulo ?? 'Sin nota';
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.85),
      pageBuilder: (ctx, _, __) {
        final cs = Theme.of(ctx).colorScheme;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      nombreNota,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¿Eliminar esta tarea? No se puede deshacer.',
                      style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.45)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(remindersProvider.notifier).deleteRecordatorio(recordatorio.id);
                          Navigator.pop(ctx);
                          AppSnackBar.exito(context, 'Tarea eliminada');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.onSurface.withOpacity(0.6),
                          side: BorderSide(color: cs.outlineVariant),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Cancelar', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _entrarModoSeleccion(int id, bool esCompletado) {
    setState(() {
      _modoSeleccion = true;
      _seleccionandoCompletadas = esCompletado;
      _seleccionados.add(id);
    });
  }

  void _salirModoSeleccion() {
    setState(() {
      _modoSeleccion = false;
      _seleccionados.clear();
      _seleccionandoCompletadas = null;
    });
  }

  void _toggleSeleccion(int id, bool esCompletado) {
    // Solo permite seleccionar del mismo tipo
    if (esCompletado != _seleccionandoCompletadas) return;
    setState(() {
      if (_seleccionados.contains(id)) {
        _seleccionados.remove(id);
        if (_seleccionados.isEmpty) {
          _modoSeleccion = false;
          _seleccionandoCompletadas = null;
        }
      } else {
        _seleccionados.add(id);
      }
    });
  }

  void _eliminarSeleccionados() {
    final count = _seleccionados.length;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.85),
      pageBuilder: (ctx, _, __) {
        final cs = Theme.of(ctx).colorScheme;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 28),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Eliminar $count tarea${count == 1 ? '' : 's'}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Esta acción no se puede deshacer.',
                      style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.45)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ids = List<int>.from(_seleccionados);
                          _salirModoSeleccion();
                          for (final id in ids) {
                            await ref.read(remindersProvider.notifier).deleteRecordatorio(id);
                          }
                          if (mounted) {
                            AppSnackBar.exito(context, '$count tarea${count == 1 ? '' : 's'} eliminada${count == 1 ? '' : 's'}');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text('Eliminar $count tarea${count == 1 ? '' : 's'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.onSurface.withOpacity(0.6),
                          side: BorderSide(color: cs.outlineVariant),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Cancelar', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _mostrarOpcionesCompletado(Recordatorio recordatorio) {
    final nombreNota = recordatorio.notaTitulo ?? 'Sin nota';
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.85),
      pageBuilder: (ctx, _, __) {
        final cs = Theme.of(ctx).colorScheme;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.task_alt_rounded, color: _accentColor, size: 28),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      nombreNota,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tarea completada',
                      style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.45)),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(remindersProvider.notifier).toggleCompletado(recordatorio.id);
                        },
                        icon: const Icon(Icons.replay_rounded, size: 20),
                        label: const Text('Reactivar tarea',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmarEliminar(recordatorio);
                        },
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text('Eliminar',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(remindersProvider);
    _accentColor = ref.watch(settingsProvider).accentColor;
    final accentColor = _accentColor;
    final accentDark = Color.lerp(accentColor, Colors.black, 0.15)!;

    return Column(
      children: [
        // ─── HEADER ───────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, left: 24, right: 16, bottom: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isSearching) ...[
                          const Text(
                            'Tareas',
                            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          remindersAsync.when(
                            loading: () => const Text('Cargando...', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            error: (_, __) => const Text('Error al cargar', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            data: (recordatorios) {
                              final pendientes = recordatorios.where((r) => !r.completado).length;
                              final completados = recordatorios.where((r) => r.completado).length;
                              return Text(
                                '$pendientes tarea${pendientes == 1 ? '' : 's'} pendiente${pendientes == 1 ? '' : 's'} · $completados completada${completados == 1 ? '' : 's'}',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              );
                            },
                          ),
                        ] else ...[
                          // Barra de búsqueda dentro del header
                          Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: const TextStyle(color: Colors.white),
                              onChanged: (v) => setState(() => _searchQuery = v),
                              decoration: InputDecoration(
                                hintText: 'Buscar por título de nota...',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                                prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                  // Botón buscar / cerrar búsqueda
                  IconButton(
                    icon: Icon(
                      _isSearching ? Icons.close : Icons.search,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                          _searchQuery = '';
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            // ─── RESUMEN RÁPIDO ──────────────────────
            Positioned(
              bottom: -30,
              left: 24,
              right: 24,
              child: remindersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (recordatorios) {
                  final pendientes = recordatorios.where((r) => !r.completado).length;
                  final completados = recordatorios.where((r) => r.completado).length;
                  final total = recordatorios.length;
                  final progreso = total > 0 ? completados / total : 0.0;

                  return Builder(builder: (context) {
                    final cs = Theme.of(context).colorScheme;
                    return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progreso,
                                strokeWidth: 4,
                                backgroundColor: cs.onSurface.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                              ),
                              Text(
                                '${(progreso * 100).toInt()}%',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurface),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pendientes == 0 ? '¡Todo completado!' : '$pendientes por hacer',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$completados de $total completados',
                                style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          pendientes == 0 ? Icons.celebration : Icons.pending_actions,
                          color: accentColor,
                          size: 24,
                        ),
                      ],
                    ),
                    );
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 48),

        // ─── BANNER DE VENCIDOS ───────────────────────
        remindersAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (recordatorios) {
            final vencidos = recordatorios.where((r) =>
              !r.completado && r.fecha.isBefore(DateTime.now())
            ).length;

            if (vencidos == 0) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$vencidos recordatorio${vencidos == 1 ? '' : 's'} vencido${vencidos == 1 ? '' : 's'} sin completar',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // ─── CHIPS DE FILTRO / BARRA DE SELECCIÓN ─────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _modoSeleccion
              ? _buildBarraSeleccion()
              : Padding(
                  key: const ValueKey('chips'),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _buildFiltroChip('Todos', _FiltroRecordatorio.todos),
                      const SizedBox(width: 8),
                      _buildFiltroChip('Pendientes', _FiltroRecordatorio.pendientes),
                      const SizedBox(width: 8),
                      _buildFiltroChip('Completados', _FiltroRecordatorio.completados),
                    ],
                  ),
                ),
        ),

        const SizedBox(height: 12),

        // ─── LISTA DE RECORDATORIOS ──────────────────
        Expanded(
          child: remindersAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: accentColor),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text('Error: $error', style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            data: (todosLosRecordatorios) {
              // Estado vacío sin filtros
              if (todosLosRecordatorios.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        const Text(
                          'No tienes tareas',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Crea una tarea asociándola a una de tus notas',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final filtrados = _aplicarFiltros(todosLosRecordatorios);

              // Estado vacío con filtros activos
              if (filtrados.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 56, color: Colors.grey.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        const Text(
                          'Sin resultados',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() {
                            _filtro = _FiltroRecordatorio.todos;
                            _searchController.clear();
                            _searchQuery = '';
                            _isSearching = false;
                          }),
                          child: Text('Limpiar filtros', style: TextStyle(color: accentColor)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Separar pendientes primero ordenados por prioridad luego fecha, completados abajo
              int _pesoprioridad(Prioridad p) =>
                  p == Prioridad.ALTA ? 0 : p == Prioridad.MEDIA ? 1 : 2;

              final pendientes = filtrados.where((r) => !r.completado).toList()
                ..sort((a, b) {
                  final cmp = _pesoprioridad(a.prioridad).compareTo(_pesoprioridad(b.prioridad));
                  return cmp != 0 ? cmp : a.fecha.compareTo(b.fecha);
                });
              final completados = filtrados.where((r) => r.completado).toList();
              final ordenados = [...pendientes, ...completados];

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                itemCount: ordenados.length,
                itemBuilder: (context, index) {
                  final recordatorio = ordenados[index];
                  final mostrarSeparador = index == pendientes.length && completados.isNotEmpty;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mostrarSeparador) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              const Text('Completados', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
                            ],
                          ),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Dismissible(
                          key: ValueKey(recordatorio.id),
                          direction: _modoSeleccion
                              ? DismissDirection.none
                              : DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            if (recordatorio.completado) {
                              _mostrarOpcionesCompletado(recordatorio);
                            } else {
                              _confirmarEliminar(recordatorio);
                            }
                            return false;
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: recordatorio.completado
                                  ? _accentColor.withOpacity(0.15)
                                  : Colors.redAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: recordatorio.completado
                                ? Icon(Icons.replay_rounded, color: _accentColor, size: 28)
                                : const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
                          ),
                          child: _buildReminderCard(recordatorio),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),

      ],
    );
  }

  // ─── BARRA DE SELECCIÓN ───────────────────────────
  Widget _buildBarraSeleccion() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('seleccion'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _salirModoSeleccion,
              child: Icon(Icons.close_rounded, color: cs.onSurface.withOpacity(0.5), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_seleccionados.length} seleccionada${_seleccionados.length == 1 ? '' : 's'}',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface),
              ),
            ),
            GestureDetector(
              onTap: _eliminarSeleccionados,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CHIP DE FILTRO ───────────────────────────────
  Widget _buildFiltroChip(String label, _FiltroRecordatorio valor) {
    final activo = _filtro == valor;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _filtro = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? _accentColor : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? _accentColor : cs.outlineVariant.withOpacity(0.4),
          ),
          boxShadow: activo
              ? [BoxShadow(color: _accentColor.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: activo ? Colors.white : cs.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  // ─── Badge de prioridad ───────────────────────────
  Widget _buildPrioridadBadge(Prioridad prioridad) {
    final color = prioridad == Prioridad.ALTA
        ? Colors.redAccent
        : prioridad == Prioridad.MEDIA
            ? Colors.orange
            : Colors.blueAccent;
    final label = prioridad == Prioridad.ALTA ? 'Alta' : prioridad == Prioridad.MEDIA ? 'Media' : 'Baja';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── TARJETA DE TAREA ─────────────────────────────
  Widget _buildReminderCard(Recordatorio recordatorio) {
    final color = _colorUrgencia(recordatorio.fecha, recordatorio.completado);
    final icono = _iconoUrgencia(recordatorio.fecha, recordatorio.completado);
    final nombreNota = recordatorio.notaTitulo ?? 'Nota sin título';
    final esCompletado = recordatorio.completado;
    final id = recordatorio.id ?? -1;
    final estaSeleccionado = _seleccionados.contains(id);
    final esBloqueado = _modoSeleccion && _seleccionandoCompletadas != null && esCompletado != _seleccionandoCompletadas;

    return GestureDetector(
      onTap: () {
        if (_ignorarTap) { _ignorarTap = false; return; }
        if (_modoSeleccion) {
          _toggleSeleccion(id, esCompletado);
        } else if (!esCompletado) {
          ref.read(remindersProvider.notifier).toggleCompletado(recordatorio.id);
        }
      },
      onLongPress: () {
        if (!_modoSeleccion) {
          _ignorarTap = true;
          _entrarModoSeleccion(id, esCompletado);
        }
      },
      child: Builder(builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: estaSeleccionado
              ? Colors.redAccent.withOpacity(0.07)
              : esBloqueado
                  ? cs.surfaceContainerLowest.withOpacity(0.35)
                  : esCompletado
                      ? cs.surfaceContainerLowest.withOpacity(0.7)
                      : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: estaSeleccionado
                ? Colors.redAccent.withOpacity(0.4)
                : esCompletado
                    ? cs.outlineVariant.withOpacity(0.2)
                    : color.withOpacity(0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ─── Icono / Checkbox ──────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: estaSeleccionado
                    ? Colors.redAccent.withOpacity(0.15)
                    : color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: estaSeleccionado
                    ? Border.all(color: Colors.redAccent, width: 2)
                    : null,
              ),
              child: Icon(
                estaSeleccionado ? Icons.check_rounded : icono,
                color: estaSeleccionado ? Colors.redAccent : color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // ─── Info ─────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + botón editar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          nombreNota,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: esCompletado ? cs.onSurface.withOpacity(0.38) : cs.onSurface,
                            decoration: esCompletado ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!esCompletado) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _editarRecordatorio(recordatorio),
                          child: Icon(Icons.edit_outlined, size: 20, color: cs.onSurface.withOpacity(0.75)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Fecha + badges (solo pendientes)
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: cs.onSurface.withOpacity(0.35)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _formatFechaCompleta(recordatorio.fecha),
                          style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!esCompletado) ...[
                        const Spacer(),
                        _buildPrioridadBadge(recordatorio.prioridad),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _tiempoRestante(recordatorio.fecha),
                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ─── Badge "✓ Hecho" centrado verticalmente (solo completados) ───
            if (esCompletado) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '✓ Hecho',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        );
      }),
    );
  }
}
