import 'package:flutter/material.dart';
import 'note_block.dart';

/// Controller de texto enriquecido para el editor de notas.
///
/// Extiende [TextEditingController] para añadir soporte de:
/// - Negrita inline (`**texto**`)
/// - Resaltado inline (`==texto==`)
/// - Ajuste automático de rangos de formato al editar
/// - Serialización/deserialización del formato a texto plano con marcadores
/// - Fusión con el bloque anterior (para el merge sin cerrar el teclado)
///
/// Esta es la migración directa de `_RichController` del editor original,
/// con nombres públicos y usando [FormatRange] en lugar de `_Rango`.
class RichTextController extends TextEditingController {

  // ── Rangos de formato activos ─────────────────────────────────
  final List<FormatRange> _boldRanges      = [];
  final List<FormatRange> _highlightRanges = [];

  // ── Modo cursor: el próximo texto escrito tendrá este formato ─
  bool _cursorBold      = false;
  bool _cursorHighlight = false;

  // ── Lectura de estado (para la toolbar y el NoteEditorController) ─

  /// true si el cursor está en modo negrita o dentro de un span bold.
  bool get isCursorBold {
    final sel = selection;
    final bo  = sel.baseOffset;
    if (sel.isCollapsed) {
      return _cursorBold || _boldRanges.any((r) => r.start <= bo && bo < r.end);
    }
    return _listCovers(_boldRanges, sel.start, sel.end);
  }

  /// true si el cursor está en modo resaltado o dentro de un span highlight.
  bool get isCursorHighlight {
    final sel = selection;
    final bo  = sel.baseOffset;
    if (sel.isCollapsed) {
      return _cursorHighlight ||
          _highlightRanges.any((r) => r.start <= bo && bo < r.end);
    }
    return _listCovers(_highlightRanges, sel.start, sel.end);
  }

  /// Copia de los rangos de negrita actuales.
  /// Usar para guardar en [NoteBlock] al hacer flush del bloque activo.
  List<FormatRange> get boldRanges => List.unmodifiable(_boldRanges);

  /// Copia de los rangos de resaltado actuales.
  List<FormatRange> get highlightRanges => List.unmodifiable(_highlightRanges);

  // ── Acciones de formato ───────────────────────────────────────

  void toggleBold() => _toggleFormat(
        _boldRanges,
        () => _cursorBold = !_cursorBold,
        (bo) => _boldRanges.any((r) => r.start < bo && bo < r.end),
        (r) { _removeRange(_boldRanges, r.start, r.end); _cursorBold = false; },
        () => _cursorBold = false,
      );

  void toggleHighlight() => _toggleFormat(
        _highlightRanges,
        () => _cursorHighlight = !_cursorHighlight,
        (bo) => _highlightRanges.any((r) => r.start < bo && bo < r.end),
        (r) { _removeRange(_highlightRanges, r.start, r.end); _cursorHighlight = false; },
        () => _cursorHighlight = false,
      );

  void _toggleFormat(
    List<FormatRange> lista,
    void Function() flipCursor,
    bool Function(int bo) isInsideSpan,
    void Function(FormatRange r) removeSpan,
    void Function() deactivateCursor,
  ) {
    final sel = selection;
    if (sel.isCollapsed) {
      final bo = sel.baseOffset;
      FormatRange? spanActual;
      for (final r in lista) {
        if (r.start < bo && bo < r.end) { spanActual = r; break; }
      }
      if (spanActual != null) {
        removeSpan(spanActual);
      } else {
        flipCursor();
      }
      notifyListeners();
      return;
    }
    if (_listCovers(lista, sel.start, sel.end)) {
      _removeRange(lista, sel.start, sel.end);
    } else {
      _addRange(lista, sel.start, sel.end);
    }
    deactivateCursor();
    notifyListeners();
  }

  // ── Serialización ─────────────────────────────────────────────

  /// Devuelve el texto con marcadores de formato insertados.
  /// Ejemplo: "hola **mundo** y ==esto=="
  String serializeText() {
    if (_boldRanges.isEmpty && _highlightRanges.isEmpty) return text;

    final Set<int> cuts = {0, text.length};
    for (final r in _boldRanges) {
      cuts.add(r.start.clamp(0, text.length));
      cuts.add(r.end.clamp(0, text.length));
    }
    for (final r in _highlightRanges) {
      cuts.add(r.start.clamp(0, text.length));
      cuts.add(r.end.clamp(0, text.length));
    }
    final points = cuts.toList()..sort();

    final buf        = StringBuffer();
    bool boldOpen    = false;
    bool highOpen    = false;

    for (int i = 0; i < points.length - 1; i++) {
      final s = points[i], e = points[i + 1];
      if (s >= e) continue;
      final isBold = _posIn(_boldRanges,      s);
      final isHigh = _posIn(_highlightRanges, s);

      // Cerrar formatos que ya no aplican (orden inverso al de apertura)
      if (highOpen && !isHigh) { buf.write('=='); highOpen = false; }
      if (boldOpen && !isBold) { buf.write('**'); boldOpen = false; }
      // Abrir formatos nuevos
      if (isBold && !boldOpen) { buf.write('**'); boldOpen = true; }
      if (isHigh && !highOpen) { buf.write('=='); highOpen = true; }

      buf.write(text.substring(s, e));
    }
    if (boldOpen) buf.write('**');
    if (highOpen) buf.write('==');

    return buf.toString();
  }

  /// Carga texto plano y rangos de formato directamente (sin serialización).
  ///
  /// Usado por [NoteEditorController] al activar un bloque: evita el ciclo
  /// serialize → parse que introduciría ruido de string.
  void loadFromRanges(
    String plainText,
    List<FormatRange> bold,
    List<FormatRange> highlight,
  ) {
    _boldRanges
      ..clear()
      ..addAll(bold);
    _highlightRanges
      ..clear()
      ..addAll(highlight);
    _cursorBold      = false;
    _cursorHighlight = false;
    super.value = TextEditingValue(text: plainText);
  }

  /// Carga texto con marcadores de formato y construye los rangos internos.
  /// Equivalente a `cargarDesde()` del controlador original.
  void loadFromSerialized(String formattedText) {
    _boldRanges.clear();
    _highlightRanges.clear();
    _cursorBold      = false;
    _cursorHighlight = false;

    if (!formattedText.contains('**') && !formattedText.contains('==')) {
      super.value = TextEditingValue(text: formattedText);
      return;
    }

    final buf = StringBuffer();
    int i = 0, realPos = 0;
    bool inBold = false, inHigh = false;
    int boldStart = 0, highStart = 0;

    while (i < formattedText.length) {
      // Marcador de negrita **
      if (i + 1 < formattedText.length &&
          formattedText[i] == '*' && formattedText[i + 1] == '*') {
        i += 2;
        if (!inBold) {
          boldStart = realPos;
          inBold = true;
        } else {
          if (realPos > boldStart) {
            _boldRanges.add(FormatRange(boldStart, realPos));
          }
          inBold = false;
        }
      }
      // Marcador de resaltado ==
      else if (i + 1 < formattedText.length &&
          formattedText[i] == '=' && formattedText[i + 1] == '=') {
        i += 2;
        if (!inHigh) {
          highStart = realPos;
          inHigh = true;
        } else {
          if (realPos > highStart) {
            _highlightRanges.add(FormatRange(highStart, realPos));
          }
          inHigh = false;
        }
      }
      // Carácter normal
      else {
        buf.write(formattedText[i++]);
        realPos++;
      }
    }
    super.value = TextEditingValue(text: buf.toString());
  }

  /// Fusiona el contenido del bloque anterior hacia este controller.
  ///
  /// El controlador queda con: [prevText][texto_actual]
  /// El cursor se posiciona en el punto de unión (offset = prevText.length).
  /// Los rangos de ambos bloques se preservan y fusionan.
  ///
  /// Este es el mecanismo central del Bug 1 fix: el TextField activo nunca
  /// se destruye — solo se actualiza su contenido con el bloque fusionado.
  void mergeWithPrevious(
    String prevText,
    List<FormatRange> prevBold,
    List<FormatRange> prevHighlight,
  ) {
    final offset = prevText.length;

    // Desplazar los rangos del bloque actual por el offset del previo
    final shiftedBold = _boldRanges.map((r) => r.shift(offset)).toList();
    _boldRanges
      ..clear()
      ..addAll(prevBold)
      ..addAll(shiftedBold);
    _mergeOverlapping(_boldRanges);

    final shiftedHigh = _highlightRanges.map((r) => r.shift(offset)).toList();
    _highlightRanges
      ..clear()
      ..addAll(prevHighlight)
      ..addAll(shiftedHigh);
    _mergeOverlapping(_highlightRanges);

    // Actualizar el texto con el cursor en el punto de unión
    super.value = TextEditingValue(
      text: prevText + text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  // ── Ajuste de rangos al editar ────────────────────────────────

  @override
  set value(TextEditingValue nv) {
    final oldText = text;
    final newText = nv.text;
    if (newText != oldText &&
        (_boldRanges.isNotEmpty || _highlightRanges.isNotEmpty ||
            _cursorBold || _cursorHighlight)) {
      _adjustRanges(oldText, newText);
    }
    super.value = nv;
  }

  void _adjustRanges(String oldText, String newText) {
    if (newText.isEmpty) {
      _boldRanges.clear();
      _highlightRanges.clear();
      return;
    }

    int start = 0;
    while (start < oldText.length &&
        start < newText.length &&
        oldText[start] == newText[start]) {
      start++;
    }
    final delta = newText.length - oldText.length;
    if (delta == 0) return;

    void adjust(List<FormatRange> lista, bool cursorActive) {
      if (delta > 0) {
        // Inserción: desplazar rangos que empiezan después del punto de inserción
        for (int i = 0; i < lista.length; i++) {
          final r = lista[i];
          lista[i] = FormatRange(
            r.start > start ? r.start + delta : r.start,
            r.end   > start ? r.end   + delta : r.end,
          );
        }
        if (cursorActive) _addRange(lista, start, start + delta);
      } else {
        // Borrado: eliminar rangos que quedan dentro del rango borrado y ajustar
        final deleteEnd = start - delta;
        _removeRange(lista, start, deleteEnd);
        for (int i = 0; i < lista.length; i++) {
          final r = lista[i];
          lista[i] = FormatRange(
            (r.start > deleteEnd ? r.start + delta : r.start)
                .clamp(0, newText.length),
            (r.end   > deleteEnd ? r.end   + delta : r.end)
                .clamp(0, newText.length),
          );
        }
        lista.removeWhere((r) => r.start >= r.end);
      }
    }

    adjust(_boldRanges,      _cursorBold);
    adjust(_highlightRanges, _cursorHighlight);
  }

  // ── Renderizado de spans ──────────────────────────────────────

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final hasComposing = withComposing && value.isComposingRangeValid;

    // Sin formato y sin composición IME: span simple (preserva comportamiento del cursor)
    if (_boldRanges.isEmpty &&
        _highlightRanges.isEmpty &&
        !hasComposing &&
        !(_cursorBold || _cursorHighlight)) {
      return TextSpan(style: style, text: text);
    }

    // Puntos de corte: inicio/fin de cada rango + límites IME
    final Set<int> cuts = {0, text.length};
    for (final r in _boldRanges) {
      cuts.add(r.start.clamp(0, text.length));
      cuts.add(r.end.clamp(0, text.length));
    }
    for (final r in _highlightRanges) {
      cuts.add(r.start.clamp(0, text.length));
      cuts.add(r.end.clamp(0, text.length));
    }
    if (hasComposing) {
      cuts.add(value.composing.start.clamp(0, text.length));
      cuts.add(value.composing.end.clamp(0, text.length));
    }
    final points = cuts.toList()..sort();

    // Caso simple: un segmento sin IME → span plano (evita pérdida del cursor)
    if (points.length == 2 && !hasComposing) {
      final isBold = _posIn(_boldRanges,      0);
      final isHigh = _posIn(_highlightRanges, 0);
      return TextSpan(
        text: text,
        style: (style ?? const TextStyle()).copyWith(
          fontWeight:      isBold ? FontWeight.bold : null,
          backgroundColor: isHigh
              ? const Color(0xFFFFEB3B).withValues(alpha: 0.7)
              : null,
        ),
      );
    }

    final spans = <InlineSpan>[];
    for (int i = 0; i < points.length - 1; i++) {
      final s = points[i], e = points[i + 1];
      if (s >= e) continue;

      final isComposing = hasComposing &&
          value.composing.start <= s &&
          e <= value.composing.end;
      final isBold = _posIn(_boldRanges,      s) || (_cursorBold      && isComposing);
      final isHigh = _posIn(_highlightRanges, s) || (_cursorHighlight && isComposing);

      spans.add(TextSpan(
        text: text.substring(s, e),
        style: (style ?? const TextStyle()).copyWith(
          fontWeight:      isBold ? FontWeight.bold : null,
          backgroundColor: isHigh
              ? const Color(0xFFFFEB3B).withValues(alpha: 0.7)
              : null,
          decoration: isComposing && !isBold && !isHigh
              ? TextDecoration.underline
              : null,
        ),
      ));
    }
    return TextSpan(style: style, children: spans);
  }

  // ── Helpers internos de rangos ────────────────────────────────

  /// true si la posición [pos] está dentro de algún rango de [lista].
  bool _posIn(List<FormatRange> lista, int pos) =>
      pos >= 0 && lista.any((r) => r.start <= pos && pos < r.end);

  /// true si todos los caracteres entre [start] y [end] están cubiertos por [lista].
  bool _listCovers(List<FormatRange> lista, int start, int end) {
    if (end <= start) return false;
    for (int i = start; i < end; i++) {
      if (!_posIn(lista, i)) return false;
    }
    return true;
  }

  void _addRange(List<FormatRange> lista, int start, int end) {
    _removeRange(lista, start, end);
    lista.add(FormatRange(start, end));
    _mergeOverlapping(lista);
  }

  void _removeRange(List<FormatRange> lista, int start, int end) {
    final result = <FormatRange>[];
    for (final r in lista) {
      if (r.end <= start || r.start >= end) {
        result.add(r);
        continue;
      }
      if (r.start < start) result.add(FormatRange(r.start, start));
      if (r.end   > end)   result.add(FormatRange(end,     r.end));
    }
    lista
      ..clear()
      ..addAll(result);
  }

  void _mergeOverlapping(List<FormatRange> lista) {
    lista.sort((a, b) => a.start.compareTo(b.start));
    final result = <FormatRange>[];
    for (final r in lista) {
      if (result.isNotEmpty && r.start <= result.last.end) {
        final last = result.removeLast();
        result.add(FormatRange(last.start, r.end > last.end ? r.end : last.end));
      } else {
        result.add(r);
      }
    }
    lista
      ..clear()
      ..addAll(result);
  }
}
