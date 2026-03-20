import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/reminders/domain/recordatorio_model.dart';
import 'package:notes_app/features/reminders/presentation/providers/reminders_provider.dart';

class RemindersListScreen extends ConsumerWidget {
  const RemindersListScreen({super.key});

  /// Calcula texto relativo de tiempo
  String _tiempoRestante(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = fecha.difference(ahora);

    if (diferencia.isNegative) {
      // Ya pasó
      if (diferencia.inMinutes.abs() < 60) {
        return 'Hace ${diferencia.inMinutes.abs()} min';
      } else if (diferencia.inHours.abs() < 24) {
        return 'Hace ${diferencia.inHours.abs()} h';
      } else {
        return 'Hace ${diferencia.inDays.abs()} día${diferencia.inDays.abs() == 1 ? '' : 's'}';
      }
    } else {
      // Futuro
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
    if (diferencia.isNegative) return Colors.redAccent; // Vencido
    if (diferencia.inHours < 1) return Colors.orange;   // Urgente
    if (diferencia.inHours < 6) return const Color(0xFF2A9D8F); // Pronto
    return Colors.blueAccent;                             // Tranquilo
  }

  IconData _iconoUrgencia(DateTime fecha, bool completado) {
    if (completado) return Icons.check_circle;
    final diferencia = fecha.difference(DateTime.now());
    if (diferencia.isNegative) return Icons.warning_amber_rounded;
    if (diferencia.inHours < 1) return Icons.notifications_active;
    return Icons.notifications_outlined;
  }

  void _confirmarEliminar(BuildContext context, WidgetRef ref, Recordatorio recordatorio) {
    final nombreNota = recordatorio.notaTitulo ?? 'Sin nota';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar recordatorio', style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold)),
        content: Text('¿Eliminar el recordatorio de "$nombreNota"?', style: const TextStyle(color: Color(0xFF2D3142))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              ref.read(remindersProvider.notifier).deleteRecordatorio(recordatorio.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Recordatorio eliminado 🗑️'),
                  backgroundColor: const Color(0xFF2A9D8F),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);

    return Column(
      children: [
        // ─── HEADER ───────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 40),
              decoration: const BoxDecoration(
                color: Color(0xFF2A9D8F),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recordatorios',
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
                        '$pendientes pendiente${pendientes == 1 ? '' : 's'} · $completados completado${completados == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
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

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Progreso circular
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progreso,
                                strokeWidth: 4,
                                backgroundColor: Colors.grey.withOpacity(0.15),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2A9D8F)),
                              ),
                              Text(
                                '${(progreso * 100).toInt()}%',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$completados de $total completados',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          pendientes == 0 ? Icons.celebration : Icons.pending_actions,
                          color: const Color(0xFF2A9D8F),
                          size: 24,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 48),

        // ─── LISTA DE RECORDATORIOS ──────────────────
        Expanded(
          child: remindersAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF2A9D8F)),
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
            data: (recordatorios) {
              // ─── ESTADO VACÍO ────────────────────
              if (recordatorios.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        const Text(
                          'No tienes recordatorios',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Los recordatorios se crearán cuando asocies uno a tus notas',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Separar pendientes primero, completados abajo
              final pendientes = recordatorios.where((r) => !r.completado).toList()
                ..sort((a, b) => a.fecha.compareTo(b.fecha)); // Los más próximos primero
              final completados = recordatorios.where((r) => r.completado).toList();
              final ordenados = [...pendientes, ...completados];

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                itemCount: ordenados.length,
                itemBuilder: (context, index) {
                  final recordatorio = ordenados[index];

                  // Separador visual entre pendientes y completados
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
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            _confirmarEliminar(context, ref, recordatorio);
                            return false;
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
                          ),
                          child: _buildReminderCard(context, ref, recordatorio),
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

  /// Tarjeta de recordatorio — mismo estilo visual del proyecto
  Widget _buildReminderCard(BuildContext context, WidgetRef ref, Recordatorio recordatorio) {
    final color = _colorUrgencia(recordatorio.fecha, recordatorio.completado);
    final icono = _iconoUrgencia(recordatorio.fecha, recordatorio.completado);
    final nombreNota = recordatorio.notaTitulo ?? 'Nota sin título';
    final esCompletado = recordatorio.completado;

    return GestureDetector(
      onTap: () {
        ref.read(remindersProvider.notifier).toggleCompletado(recordatorio.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: esCompletado ? Colors.grey.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: esCompletado ? Colors.grey.withOpacity(0.15) : color.withOpacity(0.2),
          ),
          boxShadow: esCompletado
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // ─── Icono / checkbox ────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icono, color: color, size: 22),
            ),
            const SizedBox(width: 14),

            // ─── Info ────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombreNota,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: esCompletado ? Colors.grey : const Color(0xFF2D3142),
                      decoration: esCompletado ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 13, color: Colors.grey.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text(
                        _formatFechaCompleta(recordatorio.fecha),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ─── Badge de tiempo ─────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                esCompletado ? '✓ Hecho' : _tiempoRestante(recordatorio.fecha),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
