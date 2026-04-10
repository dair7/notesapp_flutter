import 'package:flutter/material.dart';

enum _Fase { anio, mes, dia }

/// Muestra un diálogo centrado con selector de fecha personalizado.
/// Flujo: Año → Mes → Día automáticamente.
/// Retorna un [DateTime] o null si se cancela.
Future<DateTime?> mostrarDatePickerPersonalizado({
  required BuildContext context,
  required DateTime fechaInicial,
  required DateTime fechaMinima,
  required DateTime fechaMaxima,
}) {
  return showGeneralDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black.withOpacity(0.85),
    pageBuilder: (_, __, ___) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Material(
          color: Colors.transparent,
          child: _CustomDatePicker(
            fechaInicial: fechaInicial,
            fechaMinima: fechaMinima,
            fechaMaxima: fechaMaxima,
          ),
        ),
      ),
    ),
  );
}

class _CustomDatePicker extends StatefulWidget {
  final DateTime fechaInicial;
  final DateTime fechaMinima;
  final DateTime fechaMaxima;

  const _CustomDatePicker({
    required this.fechaInicial,
    required this.fechaMinima,
    required this.fechaMaxima,
  });

  @override
  State<_CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<_CustomDatePicker> {
  late int _anioSel;
  late int _mesSel;
  late int _diaSel;
  _Fase _fase = _Fase.anio;

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  static const _diasSemana = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];

  @override
  void initState() {
    super.initState();
    _anioSel = widget.fechaInicial.year;
    _mesSel  = widget.fechaInicial.month;
    _diaSel  = widget.fechaInicial.day;
    _fase    = _Fase.dia;
  }

  bool get _puedeRetroceder {
    final mesAnterior = _mesSel == 1
        ? DateTime(_anioSel - 1, 12)
        : DateTime(_anioSel, _mesSel - 1);
    return !mesAnterior.isBefore(
      DateTime(widget.fechaMinima.year, widget.fechaMinima.month),
    );
  }

  void _seleccionarAnio(int anio) {
    setState(() {
      _anioSel = anio;
      _fase = _Fase.mes;
    });
  }

  void _seleccionarMes(int mes) {
    setState(() {
      _mesSel = mes;
      final diasEnMes = DateUtils.getDaysInMonth(_anioSel, mes);
      if (_diaSel > diasEnMes) _diaSel = diasEnMes;
      _fase = _Fase.dia;
    });
  }

  void _confirmar() {
    Navigator.pop(context, DateTime(_anioSel, _mesSel, _diaSel));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    final bg = cs.surfaceContainerLowest;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Título ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Seleccionar fecha',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.4),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // ─── Header ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Row(
              children: [
                if (_fase == _Fase.dia) ...[
                  Text(
                    '$_diaSel ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _fase = _Fase.anio),
                    child: Row(
                      children: [
                        Text(
                          '${_meses[_mesSel - 1]} $_anioSel',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down_rounded,
                            color: accent, size: 28),
                      ],
                    ),
                  ),
                ] else ...[
                  Text(
                    _fase == _Fase.anio ? 'Selecciona el año' : 'Selecciona el mes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() =>
                        _fase = _fase == _Fase.mes ? _Fase.anio : _Fase.dia),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back_ios_rounded, size: 12, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            _fase == _Fase.mes ? '$_anioSel' : 'Volver',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── Contenido según fase ─────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _fase == _Fase.anio
                ? _vistaAnios(cs, accent)
                : _fase == _Fase.mes
                    ? _vistaMeses(cs, accent)
                    : _vistaDias(cs, accent),
          ),

          // ─── Botones ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.onSurface.withOpacity(0.6),
                      side: BorderSide(color: cs.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _fase == _Fase.dia ? _confirmar : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: accent.withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Vista: lista de años ─────────────────────
  Widget _vistaAnios(ColorScheme cs, Color accent) {
    final anios = List.generate(
      widget.fechaMaxima.year - widget.fechaMinima.year + 1,
      (i) => widget.fechaMinima.year + i,
    );
    return SizedBox(
      key: const ValueKey('anios'),
      height: 220,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 2.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: anios.length,
        itemBuilder: (_, i) {
          final anio = anios[i];
          final seleccionado = anio == _anioSel;
          return GestureDetector(
            onTap: () => _seleccionarAnio(anio),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: seleccionado ? accent : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$anio',
                style: TextStyle(
                  fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                  color: seleccionado ? Colors.white : cs.onSurface,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Vista: grid de meses ─────────────────────
  Widget _vistaMeses(ColorScheme cs, Color accent) {
    return Padding(
      key: const ValueKey('meses'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (_, i) {
          final mes = i + 1;
          final seleccionado = mes == _mesSel;
          return GestureDetector(
            onTap: () => _seleccionarMes(mes),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: seleccionado ? accent : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _meses[i].substring(0, 3),
                style: TextStyle(
                  fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                  color: seleccionado ? Colors.white : cs.onSurface,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Vista: calendario de días ────────────────
  Widget _vistaDias(ColorScheme cs, Color accent) {
    final primerDia = DateTime(_anioSel, _mesSel, 1);
    final offsetInicio = (primerDia.weekday - 1);
    final diasEnMes = DateUtils.getDaysInMonth(_anioSel, _mesSel);
    final hoy = DateTime.now();

    return Padding(
      key: const ValueKey('dias'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Navegación mes anterior / siguiente
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: _puedeRetroceder ? cs.onSurface.withOpacity(0.6) : cs.onSurface.withOpacity(0.2),
                onPressed: _puedeRetroceder ? () => setState(() {
                  if (_mesSel == 1) { _mesSel = 12; _anioSel--; }
                  else _mesSel--;
                }) : null,
              ),
              Text(
                '${_meses[_mesSel - 1]} $_anioSel',
                style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: cs.onSurface.withOpacity(0.6),
                onPressed: () => setState(() {
                  if (_mesSel == 12) { _mesSel = 1; _anioSel++; }
                  else _mesSel++;
                }),
              ),
            ],
          ),

          // Cabecera días de la semana
          SizedBox(
            height: 24,
            child: Row(
              children: _diasSemana.map((d) => Expanded(
                child: Center(
                  child: Text(d,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),

          // Grid de días
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: offsetInicio + diasEnMes,
            itemBuilder: (_, i) {
              if (i < offsetInicio) return const SizedBox.shrink();
              final dia = i - offsetInicio + 1;
              final esteDate = DateTime(_anioSel, _mesSel, dia);
              final seleccionado = dia == _diaSel;
              final esHoy = esteDate.year == hoy.year &&
                  esteDate.month == hoy.month &&
                  esteDate.day == hoy.day;
              final deshabilitado = esteDate.isBefore(
                  DateTime(widget.fechaMinima.year, widget.fechaMinima.month, widget.fechaMinima.day));

              return GestureDetector(
                onTap: deshabilitado ? null : () => setState(() => _diaSel = dia),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: seleccionado
                        ? accent
                        : esHoy
                            ? accent.withOpacity(0.12)
                            : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$dia',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                        color: seleccionado
                            ? Colors.white
                            : deshabilitado
                                ? cs.onSurface.withOpacity(0.2)
                                : esHoy
                                    ? accent
                                    : cs.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
