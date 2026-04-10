import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/notes/domain/nota_model.dart';
import 'package:notes_app/features/notes/presentation/providers/notes_provider.dart';
import 'package:notes_app/features/reminders/domain/recordatorio_model.dart';
import 'package:notes_app/features/reminders/presentation/providers/reminders_provider.dart';
import 'package:notes_app/core/widgets/custom_date_picker.dart';
import 'package:notes_app/core/widgets/custom_time_picker.dart';
import 'package:notes_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:notes_app/core/utils/app_snackbar.dart';

class AddReminderScreen extends ConsumerStatefulWidget {
  final Nota? notaPreseleccionada;

  const AddReminderScreen({super.key, this.notaPreseleccionada});

  @override
  ConsumerState<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends ConsumerState<AddReminderScreen> {
  Nota? _notaSeleccionada;
  DateTime _fechaSeleccionada = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _horaSeleccionada = TimeOfDay.fromDateTime(
    DateTime.now().add(const Duration(hours: 1)),
  );
  Prioridad _prioridad = Prioridad.MEDIA;
  bool _isLoading = false;
  Color _accentColor = const Color(0xFF2A9D8F);

  @override
  void initState() {
    super.initState();
    _notaSeleccionada = widget.notaPreseleccionada;
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await mostrarDatePickerPersonalizado(
      context: context,
      fechaInicial: _fechaSeleccionada,
      fechaMinima: DateTime.now(),
      fechaMaxima: DateTime.now().add(const Duration(days: 365)),
    );
    if (fecha != null) setState(() => _fechaSeleccionada = fecha);
  }

  Future<void> _seleccionarHora() async {
    final hora = await mostrarTimePickerPersonalizado(
      context: context,
      horaInicial: _horaSeleccionada,
    );
    if (hora != null) setState(() => _horaSeleccionada = hora);
  }

  DateTime get _fechaHoraFinal {
    return DateTime(
      _fechaSeleccionada.year,
      _fechaSeleccionada.month,
      _fechaSeleccionada.day,
      _horaSeleccionada.hour,
      _horaSeleccionada.minute,
    );
  }

  String _formatFecha(DateTime date) {
    final meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${date.day} de ${meses[date.month - 1]}, ${date.year}';
  }

  Future<void> _guardarRecordatorio() async {
    if (_notaSeleccionada == null || _notaSeleccionada!.id == null) {
      AppSnackBar.error(context, 'Selecciona una nota primero');
      return;
    }

    if (_fechaHoraFinal.isBefore(DateTime.now())) {
      AppSnackBar.error(context, 'La fecha debe ser en el futuro');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(remindersProvider.notifier).addRecordatorio(
        _notaSeleccionada!.id!,
        _fechaHoraFinal,
        _prioridad,
      );
      if (mounted) {
        AppSnackBar.exito(context, 'Tarea creada');
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppSnackBar.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    _accentColor = ref.watch(settingsProvider).accentColor;
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        elevation: 0,
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text(
          'Nueva Tarea',
          style: TextStyle(color: cs.onSurface, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _guardarRecordatorio,
              icon: _isLoading
                  ? SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor),
                    )
                  : Icon(Icons.check, color: _accentColor),
              label: Text(
                'Guardar',
                style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Seleccionar Nota ──────────────────
            Text('Nota asociada',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 10),

            notesAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: _accentColor)),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
              data: (notas) {
                if (notas.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('No tienes notas. Crea una nota primero.',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: notas.map((nota) {
                      final isSelected = _notaSeleccionada?.id == nota.id;
                      return GestureDetector(
                        onTap: () => setState(() => _notaSeleccionada = nota),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _accentColor.withOpacity(0.08)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.2)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? _accentColor : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? _accentColor
                                        : cs.onSurface.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  nota.titulo,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            const SizedBox(height: 28),

            // ─── Seleccionar Fecha ─────────────────
            Text('Fecha',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _seleccionarFecha,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: _accentColor, size: 20),
                    const SizedBox(width: 12),
                    Text(_formatFecha(_fechaSeleccionada),
                      style: TextStyle(fontSize: 15, color: cs.onSurface)),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.3)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ─── Seleccionar Hora ──────────────────
            Text('Hora',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _seleccionarHora,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: _accentColor, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '${_horaSeleccionada.hour.toString().padLeft(2, '0')}:${_horaSeleccionada.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 15, color: cs.onSurface),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.3)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ─── Selector de Prioridad ────────────
            Text('Prioridad',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 10),
            Row(
              children: Prioridad.values.map((p) {
                final isSelected = _prioridad == p;
                final color = p == Prioridad.ALTA
                    ? Colors.redAccent
                    : p == Prioridad.MEDIA
                        ? Colors.orange
                        : Colors.blueAccent;
                final label = p == Prioridad.ALTA ? 'Alta' : p == Prioridad.MEDIA ? 'Media' : 'Baja';
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _prioridad = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withOpacity(0.12) : cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? color : cs.outlineVariant.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.flag_rounded, color: isSelected ? color : cs.onSurface.withOpacity(0.3), size: 20),
                          const SizedBox(height: 4),
                          Text(label, style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? color : cs.onSurface.withOpacity(0.5),
                          )),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // ─── Resumen ──────────────────────────
            if (_notaSeleccionada != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _accentColor.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.notifications_outlined,
                          color: _accentColor, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _notaSeleccionada!.titulo,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatFecha(_fechaHoraFinal)} a las ${_horaSeleccionada.hour.toString().padLeft(2, '0')}:${_horaSeleccionada.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
