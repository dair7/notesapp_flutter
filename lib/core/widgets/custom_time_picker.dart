import 'package:flutter/material.dart';

Future<TimeOfDay?> mostrarTimePickerPersonalizado({
  required BuildContext context,
  required TimeOfDay horaInicial,
}) {
  return showGeneralDialog<TimeOfDay>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black.withOpacity(0.85),
    pageBuilder: (_, __, ___) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Material(
          color: Colors.transparent,
          child: _CustomTimePicker(horaInicial: horaInicial),
        ),
      ),
    ),
  );
}

class _CustomTimePicker extends StatefulWidget {
  final TimeOfDay horaInicial;
  const _CustomTimePicker({required this.horaInicial});

  @override
  State<_CustomTimePicker> createState() => _CustomTimePickerState();
}

class _CustomTimePickerState extends State<_CustomTimePicker> {
  late int _hora;   // 1-12
  late int _minuto; // 0-59
  late bool _esAm;

  late FixedExtentScrollController _ctrlHora;
  late FixedExtentScrollController _ctrlMinuto;

  static const double _itemH = 52;

  @override
  void initState() {
    super.initState();
    final h24 = widget.horaInicial.hour;
    _esAm   = h24 < 12;
    _hora   = h24 % 12 == 0 ? 12 : h24 % 12;
    _minuto = widget.horaInicial.minute;

    _ctrlHora   = FixedExtentScrollController(initialItem: _hora - 1);
    _ctrlMinuto = FixedExtentScrollController(initialItem: _minuto);
  }

  @override
  void dispose() {
    _ctrlHora.dispose();
    _ctrlMinuto.dispose();
    super.dispose();
  }

  void _confirmar() {
    int h24 = _hora % 12 + (_esAm ? 0 : 12);
    Navigator.pop(context, TimeOfDay(hour: h24, minute: _minuto));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    final esModoOscuro = Theme.of(context).brightness == Brightness.dark;

    final bgCard = esModoOscuro ? Colors.black : Colors.white;
    final borderColor = esModoOscuro
        ? Colors.white.withOpacity(0.12)
        : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1.5),
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
                'Seleccionar hora',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.4),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // ─── Hora grande ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Row(
              children: [
                Text(
                  '${_hora.toString().padLeft(2, '0')}:${_minuto.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _esAm ? 'AM' : 'PM',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── Ruedas de scroll + AM/PM ─────────
          SizedBox(
            height: _itemH * 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Resaltado del ítem central (solo sobre las ruedas)
                Positioned(
                  top: _itemH,
                  left: 24,
                  right: 100,
                  child: Container(
                    height: _itemH,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withOpacity(0.25)),
                    ),
                  ),
                ),

                Row(
                  children: [
                    Expanded(child: _ruedaHoras(cs, accent)),
                    Text(
                      ':',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface.withOpacity(0.4),
                      ),
                    ),
                    Expanded(child: _ruedaMinutos(cs, accent)),

                    // AM/PM al lado de las ruedas
                    Padding(
                      padding: const EdgeInsets.only(right: 16, left: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _botonAmPm('AM', _esAm, cs, accent),
                            _botonAmPm('PM', !_esAm, cs, accent),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── Botones ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.onSurface.withOpacity(0.6),
                      side: BorderSide(color: cs.outlineVariant),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('Aceptar',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruedaHoras(ColorScheme cs, Color accent) {
    return ListWheelScrollView.useDelegate(
      controller: _ctrlHora,
      itemExtent: _itemH,
      perspective: 0.003,
      diameterRatio: 2.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) => setState(() => _hora = i + 1),
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: 12,
        builder: (_, i) => _itemRueda(
            '${(i + 1).toString().padLeft(2, '0')}', i + 1 == _hora, cs, accent),
      ),
    );
  }

  Widget _ruedaMinutos(ColorScheme cs, Color accent) {
    return ListWheelScrollView.useDelegate(
      controller: _ctrlMinuto,
      itemExtent: _itemH,
      perspective: 0.003,
      diameterRatio: 2.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) => setState(() => _minuto = i),
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: 60,
        builder: (_, i) =>
            _itemRueda(i.toString().padLeft(2, '0'), i == _minuto, cs, accent),
      ),
    );
  }

  Widget _itemRueda(String texto, bool seleccionado, ColorScheme cs, Color accent) {
    return Center(
      child: Text(
        texto,
        style: TextStyle(
          fontSize: seleccionado ? 26 : 20,
          fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
          color: seleccionado ? accent : cs.onSurface.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _botonAmPm(String label, bool activo, ColorScheme cs, Color accent) {
    return GestureDetector(
      onTap: () => setState(() => _esAm = label == 'AM'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: activo ? Colors.white : cs.onSurface.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}
