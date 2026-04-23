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
import 'package:notes_app/core/utils/excepciones.dart';

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
      fechaMaxima: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (fecha != null) setState(() => _fechaSeleccionada = fecha);
  }

  Future<void> _seleccionarHora() async {
    final ahora = DateTime.now();
    final esHoy = _fechaSeleccionada.year == ahora.year &&
        _fechaSeleccionada.month == ahora.month &&
        _fechaSeleccionada.day == ahora.day;

    final hora = await mostrarTimePickerPersonalizado(
      context: context,
      horaInicial: _horaSeleccionada,
      horaMinima: esHoy ? TimeOfDay.fromDateTime(ahora) : null,
    );
    if (hora != null) setState(() => _horaSeleccionada = hora);
  }

  DateTime get _fechaHoraFinal => DateTime(
        _fechaSeleccionada.year,
        _fechaSeleccionada.month,
        _fechaSeleccionada.day,
        _horaSeleccionada.hour,
        _horaSeleccionada.minute,
      );

  String _formatFechaCorta(DateTime date) {
    final ahora = DateTime.now();
    final manana = DateTime(ahora.year, ahora.month, ahora.day + 1);
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final d = DateTime(date.year, date.month, date.day);

    if (d == hoy) return 'Hoy';
    if (d == manana) return 'Mañana';

    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${meses[date.month - 1]}';
  }

  String _formatFechaCompleta(DateTime date) {
    const meses = [
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
      if (mounted) AppSnackBar.errorDesdeExcepcion(context, e);
    }
  }

  /// Abre el bottom sheet para seleccionar una nota
  void _abrirSelectorNotas(List<Nota> notas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotaSelectorSheet(
        notas: notas,
        notaSeleccionada: _notaSeleccionada,
        accentColor: _accentColor,
        onSeleccionar: (nota) {
          setState(() => _notaSeleccionada = nota);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    _accentColor = ref.watch(settingsProvider).accentColor;
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLow,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text(
          'Nueva Tarea',
          style: TextStyle(
              color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _guardarRecordatorio,
              icon: _isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _accentColor),
                    )
                  : Icon(Icons.check_rounded, color: _accentColor),
              label: Text(
                'Guardar',
                style: TextStyle(
                    color: _accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ─── SECCIÓN 1: Nota ───────────────────────────────────
            _buildSectionLabel(cs, Icons.edit_note_rounded, 'Nota asociada'),
            const SizedBox(height: 10),

            notesAsync.when(
              loading: () => _buildSkeletonCard(cs),
              error: (e, _) => _buildErrorCard(cs, e),
              data: (notas) => notas.isEmpty
                  ? _buildEmptyNotasCard(cs)
                  : _buildNotaSelectorCard(cs, notas),
            ),

            const SizedBox(height: 24),

            // ─── SECCIÓN 2: Cuándo ─────────────────────────────────
            _buildSectionLabel(cs, Icons.schedule_rounded, 'Cuándo'),
            const SizedBox(height: 10),

            Row(
              children: [
                // Chip Fecha
                Expanded(
                  child: _buildPickerTile(
                    cs: cs,
                    icon: Icons.calendar_today_rounded,
                    label: 'Fecha',
                    value: _formatFechaCorta(_fechaSeleccionada),
                    onTap: _seleccionarFecha,
                  ),
                ),
                const SizedBox(width: 12),
                // Chip Hora
                Expanded(
                  child: _buildPickerTile(
                    cs: cs,
                    icon: Icons.access_time_rounded,
                    label: 'Hora',
                    value:
                        '${_horaSeleccionada.hour.toString().padLeft(2, '0')}:${_horaSeleccionada.minute.toString().padLeft(2, '0')}',
                    onTap: _seleccionarHora,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── SECCIÓN 3: Prioridad ──────────────────────────────
            _buildSectionLabel(cs, Icons.flag_rounded, 'Prioridad'),
            const SizedBox(height: 10),

            Row(
              children: Prioridad.values.map((p) {
                final isSelected = _prioridad == p;
                final color = p == Prioridad.ALTA
                    ? Colors.redAccent
                    : p == Prioridad.MEDIA
                        ? Colors.orange
                        : Colors.blueAccent;
                final label = p == Prioridad.ALTA
                    ? 'Alta'
                    : p == Prioridad.MEDIA
                        ? 'Media'
                        : 'Baja';
                final icono = p == Prioridad.ALTA
                    ? Icons.keyboard_double_arrow_up_rounded
                    : p == Prioridad.MEDIA
                        ? Icons.remove_rounded
                        : Icons.keyboard_double_arrow_down_rounded;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _prioridad = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: p != Prioridad.BAJA
                          ? const EdgeInsets.only(right: 10)
                          : EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.1)
                            : cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : cs.outlineVariant.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(icono,
                              color: isSelected
                                  ? color
                                  : cs.onSurface.withValues(alpha: 0.3),
                              size: 22),
                          const SizedBox(height: 5),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? color
                                  : cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // ─── RESUMEN ───────────────────────────────────────────
            if (_notaSeleccionada != null) ...[
              const SizedBox(height: 28),
              _buildResumen(cs),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Helper: Etiqueta de sección ──────────────────────────────
  Widget _buildSectionLabel(ColorScheme cs, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _accentColor),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.6),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ─── Card selector de nota ─────────────────────────────────────
  Widget _buildNotaSelectorCard(ColorScheme cs, List<Nota> notas) {
    final haySeleccion = _notaSeleccionada != null;

    return GestureDetector(
      onTap: () => _abrirSelectorNotas(notas),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: haySeleccion
              ? _accentColor.withValues(alpha: 0.06)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: haySeleccion
                ? _accentColor.withValues(alpha: 0.35)
                : cs.outlineVariant.withValues(alpha: 0.3),
            width: haySeleccion ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: haySeleccion
                    ? _accentColor.withValues(alpha: 0.12)
                    : cs.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                haySeleccion
                    ? Icons.note_alt_rounded
                    : Icons.add_circle_outline_rounded,
                color: haySeleccion
                    ? _accentColor
                    : cs.onSurface.withValues(alpha: 0.35),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    haySeleccion
                        ? _notaSeleccionada!.titulo
                        : 'Toca para seleccionar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: haySeleccion
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: haySeleccion
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.4),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (haySeleccion) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${notas.length} nota${notas.length == 1 ? '' : 's'} disponible${notas.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: _accentColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              color: haySeleccion
                  ? _accentColor
                  : cs.onSurface.withValues(alpha: 0.25),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Chip de fecha / hora ──────────────────────────────────────
  Widget _buildPickerTile({
    required ColorScheme cs,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: _accentColor),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Resumen ────────────────────────────────────────────────────
  Widget _buildResumen(ColorScheme cs) {
    final colorPrioridad = _prioridad == Prioridad.ALTA
        ? Colors.redAccent
        : _prioridad == Prioridad.MEDIA
            ? Colors.orange
            : Colors.blueAccent;
    final labelPrioridad = _prioridad == Prioridad.ALTA
        ? 'Alta'
        : _prioridad == Prioridad.MEDIA
            ? 'Media'
            : 'Baja';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accentColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.notifications_active_rounded,
                color: _accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _notaSeleccionada!.titulo,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatFechaCompleta(_fechaHoraFinal)} · ${_horaSeleccionada.hour.toString().padLeft(2, '0')}:${_horaSeleccionada.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: colorPrioridad.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: colorPrioridad.withValues(alpha: 0.3)),
            ),
            child: Text(
              labelPrioridad,
              style: TextStyle(
                  color: colorPrioridad,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Estado vacío sin notas ────────────────────────────────────
  Widget _buildEmptyNotasCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.note_add_outlined,
              color: cs.onSurface.withValues(alpha: 0.3), size: 22),
          const SizedBox(width: 12),
          Text(
            'No tienes notas. Crea una primero.',
            style:
                TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ─── Skeleton mientras carga ───────────────────────────────────
  Widget _buildSkeletonCard(ColorScheme cs) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: _accentColor)),
    );
  }

  // ─── Error al cargar notas ─────────────────────────────────────
  Widget _buildErrorCard(ColorScheme cs, Object e) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Error al cargar notas',
                style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.8), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Bottom Sheet de selección de nota con buscador
// ═══════════════════════════════════════════════════════════════
class _NotaSelectorSheet extends StatefulWidget {
  final List<Nota> notas;
  final Nota? notaSeleccionada;
  final Color accentColor;
  final ValueChanged<Nota> onSeleccionar;

  const _NotaSelectorSheet({
    required this.notas,
    required this.notaSeleccionada,
    required this.accentColor,
    required this.onSeleccionar,
  });

  @override
  State<_NotaSelectorSheet> createState() => _NotaSelectorSheetState();
}

class _NotaSelectorSheetState extends State<_NotaSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Nota> get _filtradas {
    if (_query.isEmpty) return widget.notas;
    final q = _query.toLowerCase();
    return widget.notas
        .where((n) => n.titulo.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtradas = _filtradas;

    return Container(
      // Máximo 80% de la pantalla
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Título ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.note_alt_rounded,
                    color: widget.accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Seleccionar nota',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.notas.length} nota${widget.notas.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Buscador ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Buscar nota...',
                  hintStyle: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.35),
                      fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: cs.onSurface.withValues(alpha: 0.35), size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          child: Icon(Icons.close_rounded,
                              color: cs.onSurface.withValues(alpha: 0.35),
                              size: 18),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Lista de notas ────────────────────────────
          Flexible(
            child: filtradas.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 40,
                            color: cs.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: 10),
                        Text(
                          'Sin resultados para "$_query"',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.4),
                              fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    itemCount: filtradas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final nota = filtradas[index];
                      final isSelected =
                          widget.notaSeleccionada?.id == nota.id;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onSeleccionar(nota),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? widget.accentColor.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                // Indicador de selección
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? widget.accentColor
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? widget.accentColor
                                          : cs.onSurface
                                              .withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded,
                                          size: 13, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    nota.titulo,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? cs.onSurface
                                          : cs.onSurface
                                              .withValues(alpha: 0.8),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded,
                                      color: widget.accentColor, size: 18),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
