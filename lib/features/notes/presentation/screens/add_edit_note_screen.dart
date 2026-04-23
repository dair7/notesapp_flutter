import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:notes_app/core/utils/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/notes/domain/nota_model.dart';
import 'package:notes_app/core/enums/estado_note_type.dart';
import 'package:notes_app/features/notes/presentation/providers/notes_provider.dart';
import 'package:notes_app/features/reminders/presentation/screens/add_reminder_screen.dart';
import 'package:share_plus/share_plus.dart';

// ── Rango de texto con formato ───────────────────────────────
class _Rango {
  final int inicio;
  final int fin;
  const _Rango(this.inicio, this.fin);
}

// ── Controller con negrita y resaltado inline por selección o cursor ──
class _RichController extends TextEditingController {
  final List<_Rango> _negrita   = [];
  final List<_Rango> _resaltado = [];
  bool _cursorNegrita   = false;
  bool _cursorResaltado = false;

  bool get cursorNegrita   => _cursorNegrita;
  bool get cursorResaltado => _cursorResaltado;
  List<_Rango> get rangos          => List.unmodifiable(_negrita);
  List<_Rango> get rangosResaltado => List.unmodifiable(_resaltado);

  // ── Toggle de formatos ────────────────────────────────────
  void toggleNegrita() => _toggleFormato(
        _negrita,
        () => _cursorNegrita = !_cursorNegrita,
        (bo) => _negrita.any((r) => r.inicio < bo && bo < r.fin),
        (r) { _quitar(_negrita, r.inicio, r.fin); _cursorNegrita = false; },
        () => _cursorNegrita = false,
      );

  void toggleResaltado() => _toggleFormato(
        _resaltado,
        () => _cursorResaltado = !_cursorResaltado,
        (bo) => _resaltado.any((r) => r.inicio < bo && bo < r.fin),
        (r) { _quitar(_resaltado, r.inicio, r.fin); _cursorResaltado = false; },
        () => _cursorResaltado = false,
      );

  // bo = baseOffset del cursor
  // dentroDeSpan: true si cursor está estrictamente dentro (no en los bordes)
  // quitarSpan: elimina el span encontrado
  // desactivarCursor: apaga el modo cursor
  void _toggleFormato(
    List<_Rango> lista,
    void Function() flipCursor,
    bool Function(int bo) dentroDeSpan,
    void Function(_Rango r) quitarSpan,
    void Function() desactivarCursor,
  ) {
    final sel = selection;
    if (sel.isCollapsed) {
      final bo = sel.baseOffset;
      _Rango? spanActual;
      for (final r in lista) {
        if (r.inicio < bo && bo < r.fin) { spanActual = r; break; }
      }
      if (spanActual != null) {
        // Cursor estrictamente dentro del span → quitarlo
        quitarSpan(spanActual);
      } else {
        // Cursor en el borde o fuera → alternar modo cursor
        flipCursor();
      }
      notifyListeners();
      return;
    }
    // Con selección: aplicar/quitar formato y desactivar modo cursor
    if (_listaCubre(lista, sel.start, sel.end)) {
      _quitar(lista, sel.start, sel.end);
    } else {
      _agregar(lista, sel.start, sel.end);
    }
    desactivarCursor();
    notifyListeners();
  }

  // ── Consultas de estado ───────────────────────────────────
  bool esCursorNegrita() {
    final sel = selection;
    final bo = sel.baseOffset;
    if (sel.isCollapsed) return _cursorNegrita   || _negrita  .any((r) => r.inicio < bo && bo < r.fin);
    return _listaCubre(_negrita, sel.start, sel.end);
  }

  bool esCursorResaltado() {
    final sel = selection;
    final bo = sel.baseOffset;
    if (sel.isCollapsed) return _cursorResaltado || _resaltado.any((r) => r.inicio < bo && bo < r.fin);
    return _listaCubre(_resaltado, sel.start, sel.end);
  }

  bool _posEn(List<_Rango> lista, int pos) =>
      pos >= 0 && lista.any((r) => r.inicio <= pos && pos < r.fin);

  bool _listaCubre(List<_Rango> lista, int start, int end) {
    if (end <= start) return false;
    for (int i = start; i < end; i++) {
      if (!_posEn(lista, i)) return false;
    }
    return true;
  }

  // ── Manipulación de rangos ────────────────────────────────
  void _agregar(List<_Rango> lista, int start, int end) {
    _quitar(lista, start, end);
    lista.add(_Rango(start, end));
    _fusionar(lista);
  }

  void _quitar(List<_Rango> lista, int start, int end) {
    final res = <_Rango>[];
    for (final r in lista) {
      if (r.fin <= start || r.inicio >= end) { res.add(r); continue; }
      if (r.inicio < start) res.add(_Rango(r.inicio, start));
      if (r.fin > end)      res.add(_Rango(end, r.fin));
    }
    lista..clear()..addAll(res);
  }

  void _fusionar(List<_Rango> lista) {
    lista.sort((a, b) => a.inicio.compareTo(b.inicio));
    final res = <_Rango>[];
    for (final r in lista) {
      if (res.isNotEmpty && r.inicio <= res.last.fin) {
        final l = res.removeLast();
        res.add(_Rango(l.inicio, r.fin > l.fin ? r.fin : l.fin));
      } else {
        res.add(r);
      }
    }
    lista..clear()..addAll(res);
  }

  // ── Ajuste de rangos al editar ────────────────────────────
  @override
  set value(TextEditingValue nv) {
    final oldText = text;
    final newText = nv.text;
    if (newText != oldText &&
        (_negrita.isNotEmpty || _resaltado.isNotEmpty ||
         _cursorNegrita || _cursorResaltado)) {
      _ajustarRangos(oldText, newText);
    }
    super.value = nv;
  }

  void _ajustarRangos(String oldText, String newText) {
    if (newText.isEmpty) { _negrita.clear(); _resaltado.clear(); return; }
    int start = 0;
    while (start < oldText.length && start < newText.length &&
        oldText[start] == newText[start]) { start++; }
    final delta = newText.length - oldText.length;
    if (delta == 0) return;

    void ajustar(List<_Rango> lista, bool cursorActivo) {
      if (delta > 0) {
        for (int i = 0; i < lista.length; i++) {
          final r = lista[i];
          lista[i] = _Rango(
            r.inicio > start ? r.inicio + delta : r.inicio,
            r.fin    >  start ? r.fin   + delta : r.fin,
          );
        }
        if (cursorActivo) _agregar(lista, start, start + delta);
      } else {
        final deleteEnd = start - delta;
        _quitar(lista, start, deleteEnd);
        for (int i = 0; i < lista.length; i++) {
          final r = lista[i];
          lista[i] = _Rango(
            (r.inicio > deleteEnd ? r.inicio + delta : r.inicio).clamp(0, newText.length),
            (r.fin    > deleteEnd ? r.fin    + delta : r.fin   ).clamp(0, newText.length),
          );
        }
        lista.removeWhere((r) => r.inicio >= r.fin);
      }
    }

    ajustar(_negrita,   _cursorNegrita);
    ajustar(_resaltado, _cursorResaltado);
  }

  // ── Fusión con bloque anterior preservando ambos formatos ──
  void fusionarConAnterior(
    String textoPrevio,
    List<_Rango> prevNegrita,
    List<_Rango> prevResaltado,
  ) {
    final offset = textoPrevio.length;

    final desN = _negrita  .map((r) => _Rango(r.inicio + offset, r.fin + offset)).toList();
    _negrita  ..clear()..addAll(prevNegrita)  ..addAll(desN);
    _fusionar(_negrita);

    final desR = _resaltado.map((r) => _Rango(r.inicio + offset, r.fin + offset)).toList();
    _resaltado..clear()..addAll(prevResaltado)..addAll(desR);
    _fusionar(_resaltado);

    super.value = TextEditingValue(
      text: textoPrevio + text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  // ── Renderizado de spans (negrita + resaltado + región IME) ──
  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final hasComposing = withComposing && value.isComposingRangeValid;

    final needsCursorFormat = (_cursorNegrita || _cursorResaltado) && hasComposing;
    if ((_negrita.isEmpty && _resaltado.isEmpty) && !hasComposing && !needsCursorFormat) {
      return TextSpan(style: style, text: text);
    }

    // Recolectar puntos de corte: formatos + región de composición IME
    final Set<int> cortes = {0, text.length};
    for (final r in _negrita)   { cortes.add(r.inicio.clamp(0, text.length)); cortes.add(r.fin.clamp(0, text.length)); }
    for (final r in _resaltado) { cortes.add(r.inicio.clamp(0, text.length)); cortes.add(r.fin.clamp(0, text.length)); }
    if (hasComposing) {
      cortes.add(value.composing.start.clamp(0, text.length));
      cortes.add(value.composing.end.clamp(0, text.length));
    }
    final puntos = cortes.toList()..sort();

    // Caso simple: un solo segmento → span plano (evita que Flutter pierda el cursor)
    if (puntos.length == 2 && !hasComposing) {
      final esBold = _posEn(_negrita,   0);
      final esHigh = _posEn(_resaltado, 0);
      return TextSpan(
        text: text,
        style: (style ?? const TextStyle()).copyWith(
          fontWeight:      esBold ? FontWeight.bold : null,
          backgroundColor: esHigh ? const Color(0xFFFFEB3B).withValues(alpha: 0.7) : null,
        ),
      );
    }

    final spans = <InlineSpan>[];
    for (int i = 0; i < puntos.length - 1; i++) {
      final s = puntos[i], e = puntos[i + 1];
      if (s >= e) continue;

      final esComposing = hasComposing &&
          value.composing.start <= s && e <= value.composing.end;
      final esBold = _posEn(_negrita,   s) || (_cursorNegrita   && esComposing);
      final esHigh = _posEn(_resaltado, s) || (_cursorResaltado && esComposing);

      spans.add(TextSpan(
        text: text.substring(s, e),
        style: (style ?? const TextStyle()).copyWith(
          fontWeight:      esBold ? FontWeight.bold : null,
          backgroundColor: esHigh ? const Color(0xFFFFEB3B).withValues(alpha: 0.7) : null,
          decoration: esComposing && !esBold && !esHigh ? TextDecoration.underline : null,
        ),
      ));
    }
    return TextSpan(style: style, children: spans);
  }

  // ── Serialización: **negrita**, ==resaltado== ─────────────
  String textoConFormato() {
    if (_negrita.isEmpty && _resaltado.isEmpty) return text;

    // Eventos: (posición, marcadorAbrir, marcadorCerrar)
    // Usamos un recorrido por puntos de corte igual que buildTextSpan
    final Set<int> cortes = {0, text.length};
    for (final r in _negrita)   { cortes.add(r.inicio.clamp(0, text.length)); cortes.add(r.fin.clamp(0, text.length)); }
    for (final r in _resaltado) { cortes.add(r.inicio.clamp(0, text.length)); cortes.add(r.fin.clamp(0, text.length)); }
    final puntos = cortes.toList()..sort();

    final buf = StringBuffer();
    bool boldAbierto = false, highAbierto = false;

    for (int i = 0; i < puntos.length - 1; i++) {
      final s = puntos[i], e = puntos[i + 1];
      if (s >= e) continue;
      final esBold = _posEn(_negrita,   s);
      final esHigh = _posEn(_resaltado, s);

      // Cerrar formatos que ya no aplican
      if (highAbierto && !esHigh) { buf.write('=='); highAbierto = false; }
      if (boldAbierto && !esBold) { buf.write('**'); boldAbierto = false; }
      // Abrir formatos nuevos
      if (esBold && !boldAbierto) { buf.write('**'); boldAbierto = true; }
      if (esHigh && !highAbierto) { buf.write('=='); highAbierto = true; }

      buf.write(text.substring(s, e));
    }
    // Cerrar lo que quede abierto
    if (boldAbierto) buf.write('**');
    if (highAbierto) buf.write('==');

    return buf.toString();
  }

  // Carga texto plano y rangos de formato directamente (sin marcadores).
  // Usado al dividir un bloque en varios (p.ej. al crear un checklist en
  // una línea intermedia) para preservar negrita/resaltado de cada parte.
  void cargarConRangos(
    String textoPlano,
    List<_Rango> negrita,
    List<_Rango> resaltado,
  ) {
    _negrita..clear()..addAll(negrita);
    _resaltado..clear()..addAll(resaltado);
    _cursorNegrita   = false;
    _cursorResaltado = false;
    super.value = TextEditingValue(text: textoPlano);
  }

  void cargarDesde(String textoFormateado) {
    _negrita.clear();
    _resaltado.clear();
    _cursorNegrita   = false;
    _cursorResaltado = false;

    if (!textoFormateado.contains('**') && !textoFormateado.contains('==')) {
      super.value = TextEditingValue(text: textoFormateado);
      return;
    }

    final buf = StringBuffer();
    int i = 0, realPos = 0;
    bool enBold = false, enHigh = false;
    int boldIni = 0, highIni = 0;

    while (i < textoFormateado.length) {
      // Detectar marcador de negrita **
      if (i + 1 < textoFormateado.length &&
          textoFormateado[i] == '*' && textoFormateado[i + 1] == '*') {
        i += 2;
        if (!enBold) { boldIni = realPos; enBold = true; }
        else { if (realPos > boldIni) _negrita.add(_Rango(boldIni, realPos)); enBold = false; }
      }
      // Detectar marcador de resaltado ==
      else if (i + 1 < textoFormateado.length &&
          textoFormateado[i] == '=' && textoFormateado[i + 1] == '=') {
        i += 2;
        if (!enHigh) { highIni = realPos; enHigh = true; }
        else { if (realPos > highIni) _resaltado.add(_Rango(highIni, realPos)); enHigh = false; }
      }
      else {
        buf.write(textoFormateado[i++]);
        realPos++;
      }
    }
    super.value = TextEditingValue(text: buf.toString());
  }
}

// ── Modelo interno de cada bloque de contenido ──────────────
class _Bloque {
  bool esChecklist;
  bool hecho;
  // Soporte de imagen inline
  bool esImagen;
  String? rutaImagen;
  bool imagenMitad; // false = ancho completo, true = mitad izquierda
  // Comentario integrado en el bloque de imagen
  bool mostrarComentario;
  final TextEditingController comentarioCtrl;
  final FocusNode comentarioFocus;
  // Key para localizar la imagen en pantalla (Overlay)
  final GlobalKey imagenKey = GlobalKey();
  final _RichController ctrl;
  final FocusNode focus;

  _Bloque({
    required String texto,
    this.esChecklist = false,
    this.hecho = false,
    this.esImagen = false,
    this.rutaImagen,
    this.imagenMitad = false,
    String comentario = '',
    this.mostrarComentario = false,
    // Si se proveen, [texto] se interpreta como texto plano y los rangos se
    // aplican directamente. Sin rangos, [texto] se parsea como formato `**` / `==`.
    List<_Rango>? negritaRangos,
    List<_Rango>? resaltadoRangos,
  })  : ctrl = _RichController(),
        focus = FocusNode(),
        comentarioCtrl = TextEditingController(text: comentario),
        comentarioFocus = FocusNode() {
    if (negritaRangos != null || resaltadoRangos != null) {
      ctrl.cargarConRangos(texto, negritaRangos ?? const [], resaltadoRangos ?? const []);
    } else {
      ctrl.cargarDesde(texto);
    }
  }

  void dispose() {
    ctrl.dispose();
    focus.dispose();
    comentarioCtrl.dispose();
    comentarioFocus.dispose();
  }
}


// ────────────────────────────────────────────────────────────
class AddEditNoteScreen extends ConsumerStatefulWidget {
  final Nota? notaToEdit;
  const AddEditNoteScreen({super.key, this.notaToEdit});

  @override
  ConsumerState<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends ConsumerState<AddEditNoteScreen>
    with WidgetsBindingObserver {
  late TextEditingController _tituloController;
  final TextEditingController _etiquetaController = TextEditingController();
  late List<_Bloque> _bloques;

  bool _merging    = false; // guard para evitar fusiones re-entrantes
  bool _fusionando = false; // evita que didChangeMetrics llame unfocus() durante merge
  List<String> _etiquetas = [];
  final ImagePicker _picker = ImagePicker();
  _Bloque? _comentarioActivo; // bloque cuyo comentario está siendo editado
  OverlayEntry? _overlayEntry; // barra flotante de imagen activa
  _Bloque? _bloqueConOverlay;  // imagen actualmente seleccionada (borde amarillo)
  final ScrollController _scrollController = ScrollController();

  // Estado de sincronización con el servidor
  _EstadoSync _estadoSync = _EstadoSync.sincronizado;
  bool _isDisposed = false; // evita setState durante el desmontaje
  Timer? _timerReintento;
  int? _idNotaCreada; // id asignado por el servidor tras el primer auto-guardado
  bool _errorMostrado = false; // evita mostrar el toast en cada reintento
  bool _modoEnfocado = false;
  // Índice del último bloque enfocado (capturado antes de que el tap robe el foco)
  int _ultimoBloqueIdx = 0;

  // Formato global del contenido
  double _tamanoFuente = 16.0;
  static const double _tamanoMin = 12.0;
  static const double _tamanoMax = 24.0;

  // Contador (actualizado con debounce para no hacer rebuild en cada tecla)
  final _contadorNotifier = ValueNotifier<String>('');
  Timer? _debounceContador;

  // Auto guardado
  Timer? _debounceGuardado;
  bool _guardadoAutomatico = false; // true si ya fue creada por auto guardado

  // ── Metadatos de formato (negrita, resaltado, tamaño fuente) ─
  void _cargarFormato(String raw) {
    if (!raw.startsWith('[fmt:')) return;
    final end = raw.indexOf(']');
    if (end < 0) return;
    for (final parte in raw.substring(5, end).split(',')) {
      final kv = parte.split('=');
      if (kv.length != 2) continue;
      switch (kv[0]) {
        case 'fs': _tamanoFuente = double.tryParse(kv[1]) ?? 16.0; break;
      }
    }
  }

  String _extraerContenido(String raw) {
    if (!raw.startsWith('[fmt:')) return raw;
    final nl = raw.indexOf('\n');
    if (nl < 0) return '';
    // Separar texto de imágenes embebidas
    final resto = raw.substring(nl + 1);
    final sepIdx = resto.indexOf('\n---imgs---\n');
    return sepIdx >= 0 ? resto.substring(0, sepIdx) : resto;
  }

  List<String> _extraerImagenes(String raw) {
    final sepIdx = raw.indexOf('\n---imgs---\n');
    if (sepIdx < 0) return [];
    return raw
        .substring(sepIdx + '\n---imgs---\n'.length)
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
  }

  String _serializarConFormato() {
    final meta = '[fmt:b=0,r=0,fs=${_tamanoFuente.toInt()}]';
    return '$meta\n${_serializar()}';
  }

  // ── Parseo/serialización de bloques ─────────────────────────
  // Las líneas regulares consecutivas se agrupan en un solo bloque para que
  // Enter y Backspace sean manejados nativamente por el TextField, sin cambios
  // de foco entre bloques que cierran el teclado virtual en Android.
  List<_Bloque> _parsear(String contenido) {
    if (contenido.isEmpty) return [_Bloque(texto: '')];
    final lineas = contenido.split('\n');
    final bloques = <_Bloque>[];
    final buffer = <String>[];

    void flushBuffer() {
      if (buffer.isEmpty) return;
      bloques.add(_Bloque(texto: buffer.join('\n')));
      buffer.clear();
    }

    for (final linea in lineas) {
      if (linea.startsWith('[img:')) {
        // Formato: [img:full:/ruta] o [img:full:/ruta|comentario]
        flushBuffer();
        final inner = linea.substring(5, linea.endsWith(']') ? linea.length - 1 : linea.length);
        final colonIdx = inner.indexOf(':');
        if (colonIdx > 0) {
          final size = inner.substring(0, colonIdx);
          final resto = inner.substring(colonIdx + 1);
          final pipeIdx = resto.indexOf('|');
          final ruta = pipeIdx >= 0 ? resto.substring(0, pipeIdx) : resto;
          final comentario = pipeIdx >= 0
              ? resto.substring(pipeIdx + 1).replaceAll('⏎', '\n')
              : '';
          bloques.add(_Bloque(
            texto: '',
            esImagen: true,
            rutaImagen: ruta,
            imagenMitad: size == 'half',
            comentario: comentario,
            mostrarComentario: comentario.isNotEmpty,
          ));
        }
      } else if (linea.startsWith('[ ] ')) {
        flushBuffer();
        bloques.add(_Bloque(texto: linea.substring(4), esChecklist: true, hecho: false));
      } else if (linea.startsWith('[x] ')) {
        flushBuffer();
        bloques.add(_Bloque(texto: linea.substring(4), esChecklist: true, hecho: true));
      } else if (linea == '---imgs---') {
        // Ignorar separador del formato antiguo
        flushBuffer();
      } else {
        buffer.add(linea);
      }
    }
    flushBuffer();

    return bloques.isEmpty ? [_Bloque(texto: '')] : bloques;
  }

  String _serializar() {
    return _bloques.map((b) {
      if (b.esImagen) {
        final comentario = b.comentarioCtrl.text.replaceAll('\n', '⏎');
        final extra = comentario.isNotEmpty ? '|$comentario' : '';
        return '[img:${b.imagenMitad ? 'half' : 'full'}:${b.rutaImagen}$extra]';
      }
      if (b.esChecklist) return '${b.hecho ? '[x]' : '[ ]'} ${b.ctrl.textoConFormato()}';
      return b.ctrl.textoConFormato();
    }).join('\n');
  }

  // ── Contador de palabras — usa ValueNotifier, NUNCA llama setState ─
  void _actualizarContador() {
    _debounceContador?.cancel();
    _debounceContador = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final texto = _serializar();
      final chars = texto.length;
      final words = texto.trim().isEmpty ? 0 : texto.trim().split(RegExp(r'\s+')).length;
      _contadorNotifier.value =
          '$words ${words == 1 ? 'palabra' : 'palabras'} · $chars caracteres';
    });
    // Programar auto guardado 3s después de la última tecla
    _programarAutoGuardado();
  }

  // ── Auto guardado con debounce corto (texto mientras se escribe) ─
  void _programarAutoGuardado() {
    _debounceGuardado?.cancel();
    _debounceGuardado = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _ejecutarAutoGuardado();
    });
  }

  // ── Guardado inmediato sin debounce (imágenes) ───────────────
  void _guardarInmediato() {
    _debounceGuardado?.cancel();
    if (mounted) _ejecutarAutoGuardado();
  }

  // ── Guardado con debounce corto (título: evita llamada por cada tecla) ─
  void _programarAutoGuardadoTitulo() {
    _debounceGuardado?.cancel();
    _debounceGuardado = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _ejecutarAutoGuardado();
    });
  }

  Future<void> _ejecutarAutoGuardado() async {
    final titulo = _tituloController.text.trim();
    final textoPlano = _serializar().trim();
    if (titulo.isEmpty && textoPlano.isEmpty) return;
    // Evitar llamadas simultáneas
    if (_estadoSync == _EstadoSync.guardando) return;

    // Solo actualizar UI si el widget sigue montado (no llamar setState durante dispose)
    if (!_isDisposed && mounted) setState(() => _estadoSync = _EstadoSync.guardando);
    _timerReintento?.cancel();

    try {
      final esEdicion = widget.notaToEdit != null || _guardadoAutomatico;
      final nota = Nota(
        id: esEdicion ? (widget.notaToEdit?.id ?? _idNotaCreada) : null,
        titulo: titulo.isEmpty ? 'Sin título' : titulo,
        contenido: _serializarConFormato(),
        fechaCreacion: widget.notaToEdit?.fechaCreacion ?? DateTime.now(),
        estado: widget.notaToEdit?.estado ?? EstadoNoteType.ACTIVA,
        color: null,
        etiquetas: _etiquetas,
      );
      if (esEdicion) {
        await ref.read(notesProvider.notifier).updateNota(nota);
      } else {
        final notaCreada = await ref.read(notesProvider.notifier).addNota(nota);
        _idNotaCreada = notaCreada.id;
        _guardadoAutomatico = true;
      }
      if (!_isDisposed && mounted) {
        setState(() => _estadoSync = _EstadoSync.sincronizado);
        _errorMostrado = false;
      }
    } catch (_) {
      if (!_isDisposed && mounted) {
        setState(() => _estadoSync = _EstadoSync.pendiente);
        if (!_errorMostrado) {
          _errorMostrado = true;
          AppSnackBar.error(context, 'Sin conexión — reintentando automáticamente');
        }
        _iniciarReintento();
      }
    }
  }

  // Reintenta la sincronización cada 5 segundos hasta lograrlo
  void _iniciarReintento() {
    _timerReintento?.cancel();
    _timerReintento = Timer(const Duration(seconds: 5), () {
      if (mounted) _ejecutarAutoGuardado();
    });
  }

  // ── Aplica una acción de formato manteniendo el foco (teclado visible) ─
  void _aplicarFormato(VoidCallback accion) {
    setState(accion);
  }

  // ── Toggle checklist en el bloque enfocado ──────────────────
  void _toggleChecklistBloqueActual() {
    final idx = _ultimoBloqueIdx.clamp(0, _bloques.length - 1);
    final bloque = _bloques[idx];

    if (bloque.esChecklist) {
      // Checklist → regular: quitar flag
      setState(() { bloque.esChecklist = false; bloque.hecho = false; });
      return;
    }

    final texto = bloque.ctrl.text;
    final lineas = texto.split('\n');

    // Bloque con una sola línea → convertir directamente, sin dividir
    if (lineas.length <= 1) {
      setState(() => bloque.esChecklist = true);
      return;
    }

    // Bloque con varias líneas: solo convertir la línea donde está el cursor.
    // Se divide en hasta 3 partes: [texto antes] + [línea actual → checklist] + [texto después]
    final cursorOffset = bloque.ctrl.selection.baseOffset
        .clamp(0, texto.length);

    // Capturar los rangos de formato originales ANTES de crear los bloques nuevos
    // para poder trocearlos por línea y preservar negrita/resaltado en cada parte.
    final negritaOrig   = List<_Rango>.from(bloque.ctrl.rangos);
    final resaltadoOrig = List<_Rango>.from(bloque.ctrl.rangosResaltado);

    // Offset de inicio de cada línea dentro del texto completo
    final offsetsLinea = <int>[];
    int off = 0;
    for (final linea in lineas) {
      offsetsLinea.add(off);
      off += linea.length + 1; // +1 por el '\n'
    }

    // Calcular en qué índice de línea está el cursor
    int lineaIdx = 0;
    for (int i = 0; i < lineas.length; i++) {
      final finLinea = offsetsLinea[i] + lineas[i].length;
      if (cursorOffset <= finLinea) { lineaIdx = i; break; }
      if (i == lineas.length - 1) lineaIdx = i;
    }
    lineaIdx = lineaIdx.clamp(0, lineas.length - 1);

    final nuevos = <_Bloque>[];

    // Parte 1: líneas antes de la línea actual (bloque regular, si existen)
    if (lineaIdx > 0) {
      final partText = lineas.sublist(0, lineaIdx).join('\n');
      final partEnd  = offsetsLinea[lineaIdx] - 1; // excluye el '\n' final
      nuevos.add(_Bloque(
        texto: partText,
        negritaRangos:   _sliceRangos(negritaOrig,   0, partEnd),
        resaltadoRangos: _sliceRangos(resaltadoOrig, 0, partEnd),
      ));
    }

    // Parte 2: línea del cursor → checklist (con formato preservado)
    final checkFrom = offsetsLinea[lineaIdx];
    final checkEnd  = checkFrom + lineas[lineaIdx].length;
    nuevos.add(_Bloque(
      texto: lineas[lineaIdx],
      esChecklist: true,
      negritaRangos:   _sliceRangos(negritaOrig,   checkFrom, checkEnd),
      resaltadoRangos: _sliceRangos(resaltadoOrig, checkFrom, checkEnd),
    ));

    // Parte 3: líneas después de la línea actual (bloque regular, si existen)
    if (lineaIdx < lineas.length - 1) {
      final afterFrom = offsetsLinea[lineaIdx + 1];
      final afterText = lineas.sublist(lineaIdx + 1).join('\n');
      final afterEnd  = afterFrom + afterText.length;
      nuevos.add(_Bloque(
        texto: afterText,
        negritaRangos:   _sliceRangos(negritaOrig,   afterFrom, afterEnd),
        resaltadoRangos: _sliceRangos(resaltadoOrig, afterFrom, afterEnd),
      ));
    }

    // Índice del bloque checklist recién creado para reasignar foco
    final idxChecklist = idx + (lineaIdx > 0 ? 1 : 0);

    setState(() {
      _bloques.removeAt(idx);
      _bloques.insertAll(idx, nuevos);
    });

    // Devolver el foco al ítem checklist para que el teclado no se cierre
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && idxChecklist < _bloques.length) {
        _bloques[idxChecklist].focus.requestFocus();
      }
    });
  }

  // Recorta [rangos] al intervalo [from, to] y reajusta los offsets a 0.
  // Se usa al dividir un bloque multi-línea en sub-bloques para preservar
  // negrita/resaltado de cada trozo.
  List<_Rango> _sliceRangos(List<_Rango> rangos, int from, int to) {
    final result = <_Rango>[];
    for (final r in rangos) {
      final s = r.inicio.clamp(from, to);
      final e = r.fin.clamp(from, to);
      if (e > s) result.add(_Rango(s - from, e - from));
    }
    return result;
  }

  bool get _bloqueActualEsChecklist {
    final idx = _ultimoBloqueIdx.clamp(0, _bloques.length - 1);
    return _bloques[idx].esChecklist;
  }

  bool get _negritaActiva {
    final idx = _ultimoBloqueIdx.clamp(0, _bloques.length - 1);
    return _bloques[idx].ctrl.esCursorNegrita();
  }

  bool get _resaltadoActivo {
    final idx = _ultimoBloqueIdx.clamp(0, _bloques.length - 1);
    return _bloques[idx].ctrl.esCursorResaltado();
  }

  // ── Fusión inversa: solo se usa para ítems checklist.
  // Los bloques regulares nunca necesitan fusionarse porque no se dividen.
  void _fusionarConAnterior(int idx) {
    if (_merging || idx <= 0 || idx >= _bloques.length) return;
    _merging    = true;
    _fusionando = true;
    final previo = _bloques[idx - 1];
    final actual = _bloques[idx];
    actual.esChecklist = previo.esChecklist;
    actual.hecho = previo.hecho;
    actual.ctrl.fusionarConAnterior(previo.ctrl.text, previo.ctrl.rangos, previo.ctrl.rangosResaltado);
    setState(() => _bloques.removeAt(idx - 1));
    // Solicitar foco de inmediato (antes del próximo frame) para que el teclado
    // no tenga tiempo de detectar la pérdida de foco y cerrarse.
    actual.focus.requestFocus();
    _merging = false;
    // Liberar el guard después del frame para cubrir la ventana de metrics.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fusionando = false;
    });
  }


  // ── Cambios de texto por bloque ──────────────────────────────
  void _onBloqueChanged(int index, String texto) {
    if (index >= _bloques.length) return;
    final bloque = _bloques[index];

    // Bloques regulares: Enter y Backspace son gestionados nativamente por el
    // TextField (maxLines: null). No dividir ni fusionar → el teclado virtual
    // nunca pierde la conexión IME al escribir múltiples líneas.
    if (!bloque.esChecklist) {
      _actualizarContador();
      return;
    }

    // ── Lógica exclusiva de ítems checklist ──
    if (texto.isEmpty && index > 0) {
      _fusionarConAnterior(index);
      return;
    }
    if (!texto.contains('\n')) {
      _actualizarContador();
      return;
    }
    // Enter en checklist → crear nuevo ítem
    final ctrl = bloque.ctrl;
    final newlinePos = texto.indexOf('\n');
    final antes = texto.substring(0, newlinePos);
    final despues = texto.substring(newlinePos + 1);
    ctrl.value = TextEditingValue(
      text: antes,
      selection: TextSelection.collapsed(offset: antes.length),
    );
    final nuevoBloque = _Bloque(texto: despues, esChecklist: true, hecho: false);
    setState(() => _bloques.insert(index + 1, nuevoBloque));
    Future.microtask(() => nuevoBloque.focus.requestFocus());
    _actualizarContador();
  }

  KeyEventResult _onBloqueKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return KeyEventResult.ignored;
    if (index <= 0 || index >= _bloques.length) return KeyEventResult.ignored;
    final bloque = _bloques[index];

    // Checklist vacío → fusionar con el anterior
    if (bloque.esChecklist && bloque.ctrl.text.isEmpty) {
      _fusionarConAnterior(index);
      return KeyEventResult.handled;
    }

    // Cualquier bloque con cursor en posición 0 → fusionar con el anterior
    // (permite borrar el checklist de arriba con backspace natural)
    if (bloque.ctrl.selection.baseOffset == 0 && bloque.ctrl.selection.isCollapsed) {
      final previo = _bloques[index - 1];
      if (previo.esImagen) return KeyEventResult.ignored;
      // Quitar el check del bloque anterior si lo era
      previo.esChecklist = false;
      previo.hecho = false;
      _fusionarConAnterior(index);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ── Compartir (solo texto limpio, sin marcadores ni imágenes) ─
  Future<void> _compartirNota() async {
    final titulo = _tituloController.text.trim();

    final buffer = StringBuffer();
    if (titulo.isNotEmpty) {
      buffer.writeln(titulo);
      buffer.writeln();
    }
    for (final b in _bloques) {
      if (b.esImagen) continue;
      final linea = b.ctrl.text.trim();
      if (linea.isEmpty) continue;
      if (b.esChecklist) {
        buffer.writeln('${b.hecho ? '☑' : '☐'} $linea');
      } else {
        buffer.writeln(linea);
      }
    }

    final texto = buffer.toString().trim();
    if (texto.isEmpty) {
      AppSnackBar.error(context, 'La nota está vacía');
      return;
    }
    await Share.share(texto, subject: titulo.isNotEmpty ? titulo : null);
  }

  // ── Modo enfocado ───────────────────────────────────────────
  void _toggleModoEnfocado() {
    if (_modoEnfocado) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    setState(() => _modoEnfocado = !_modoEnfocado);
  }

  // ── Modal para elegir fuente de imagen ──────────────────────
  void _mostrarModalImagen() {
    if (_bloques.where((b) => b.esImagen).length >= 5) {
      AppSnackBar.error(context, 'Límite de 5 imágenes por nota');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de arrastre
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Agregar imagen',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              // Opción galería
              _opcionModal(
                icon: Icons.photo_library_outlined,
                label: 'Seleccionar de la galería',
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarImagen(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
              // Opción cámara
              _opcionModal(
                icon: Icons.camera_alt_outlined,
                label: 'Tomar foto con la cámara',
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarImagen(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opcionModal({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? const Color(0xFF2A9D8F);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(fontSize: 15, color: color != null ? c : Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ── Picker de imagen (galería / cámara) ──────────────────────
  Future<void> _seleccionarImagen(ImageSource fuente) async {
    try {
      // Galería: sin recompresión para preservar la calidad original.
      // Cámara: se limita resolución para no guardar fotos de 20MB+.
      final imagen = await _picker.pickImage(
        source: fuente,
        imageQuality: fuente == ImageSource.camera ? 90 : null,
        maxWidth:     fuente == ImageSource.camera ? 2160 : null,
        maxHeight:    fuente == ImageSource.camera ? 2160 : null,
      );
      if (imagen == null) return;

      // Copiar al directorio permanente de la app para que sobreviva limpiezas de caché
      final dirApp = await getApplicationDocumentsDirectory();
      final dirImagenes = Directory(p.join(dirApp.path, 'notas_imagenes'));
      if (!await dirImagenes.exists()) await dirImagenes.create(recursive: true);

      final nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}${p.extension(imagen.path)}';
      final rutaFinal = p.join(dirImagenes.path, nombreArchivo);
      await File(imagen.path).copy(rutaFinal);

      setState(() {
        _bloques.add(_Bloque(texto: '', esImagen: true, rutaImagen: rutaFinal));
        _normalizarBloques();
      });
      // Guardar inmediatamente al agregar una imagen
      _guardarInmediato();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'No se pudo obtener la imagen');
    }
  }

  double _prevBottomInset = 0;
  bool _tecladoVisible = false;

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    final abierto = bottomInset > 0;

    // Transición visible → oculto: quitar foco (solo si no estamos fusionando bloques)
    if (_prevBottomInset > 0 && bottomInset == 0 && mounted && !_fusionando) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (_comentarioActivo != null) {
        setState(() {
          _comentarioActivo = null;
          _tecladoVisible = false;
        });
        _prevBottomInset = bottomInset;
        return;
      }
    }

    if (abierto != _tecladoVisible && mounted) {
      setState(() => _tecladoVisible = abierto);
    }
    _prevBottomInset = bottomInset;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tituloController = TextEditingController(text: widget.notaToEdit?.titulo ?? '');
    // Guardar 600ms después del último cambio en el título
    _tituloController.addListener(_programarAutoGuardadoTitulo);
    final contenidoRaw = widget.notaToEdit?.contenido ?? '';
    _cargarFormato(contenidoRaw);
    _bloques = _parsear(_extraerContenido(contenidoRaw));
    // Migración: convertir imágenes del formato antiguo (---imgs---) a bloques inline al final
    for (final ruta in _extraerImagenes(contenidoRaw)) {
      _bloques.add(_Bloque(texto: '', esImagen: true, rutaImagen: ruta));
    }
    _normalizarBloques();
    _etiquetas = List<String>.from(widget.notaToEdit?.etiquetas ?? []);
    _etiquetaController.addListener(() => setState(() {}));
    _scrollController.addListener(_ocultarBarraFlotante);
    Future.microtask(_actualizarContador);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Guardar cuando la app pasa a segundo plano
    if (state == AppLifecycleState.paused) _ejecutarAutoGuardado();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timerReintento?.cancel();
    _debounceGuardado?.cancel();
    // Quitar listener antes de dispose para evitar callbacks sobre estado destruido
    _tituloController.removeListener(_programarAutoGuardadoTitulo);
    // Guardar al salir: capturar datos antes de destruir los controllers
    _ejecutarAutoGuardado();
    WidgetsBinding.instance.removeObserver(this);
    _debounceContador?.cancel();
    _contadorNotifier.dispose();
    _tituloController.dispose();
    _etiquetaController.dispose();
    for (final b in _bloques) { b.dispose(); }
    _overlayEntry?.remove();
    _scrollController.dispose();
    if (_modoEnfocado) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? cs.surfaceContainerLowest
          : Colors.white,
      appBar: _modoEnfocado ? null : _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _buildAreaContenido()),
              // Mostrar la barra de comentario aunque el teclado aún no esté visible,
              // para que el TextField esté montado antes de llamar requestFocus()
              if (!_modoEnfocado && (_tecladoVisible || _comentarioActivo != null))
                _comentarioActivo != null
                    ? _buildBarraComentario(_comentarioActivo!)
                    : _buildBarraInferior(),
            ],
          ),
          if (_modoEnfocado)
            Positioned(
              bottom: 24, right: 24,
              child: GestureDetector(
                onTap: _toggleModoEnfocado,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inverseSurface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Salir del foco', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── APP BAR ──────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? cs.surfaceContainerLowest
          : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: cs.onSurface),
      actions: [
        // Indicador de estado de sincronización
        if (_estadoSync == _EstadoSync.guardando)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurface.withValues(alpha: 0.4)),
              ),
            ),
          )
        else if (_estadoSync == _EstadoSync.pendiente)
          IconButton(
            icon: const Icon(Icons.cloud_off_rounded, color: Colors.orange),
            tooltip: 'Sin sincronizar — toca para reintentar',
            onPressed: _ejecutarAutoGuardado,
          ),
        IconButton(
          icon: Icon(Icons.share_outlined, color: cs.onSurface),
          tooltip: 'Compartir',
          onPressed: _compartirNota,
        ),
        if (widget.notaToEdit?.id != null)
          IconButton(
            icon: Icon(Icons.notifications_none_outlined, color: cs.onSurface),
            tooltip: 'Recordatorio',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AddReminderScreen(notaPreseleccionada: widget.notaToEdit))),
          ),
      ],
    );
  }

  // ── ÁREA DE CONTENIDO (título + bloques) ─────────────────────
  Widget _buildAreaContenido() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(22, _modoEnfocado ? 56 : 18, 22, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 14),
            child: TextField(
              controller: _tituloController,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                height: 1.3,
              ),
              decoration: InputDecoration(
                hintText: 'Título',
                hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 26, fontWeight: FontWeight.w700),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 28, left: 14),
            child: ValueListenableBuilder<String>(
              valueListenable: _contadorNotifier,
              builder: (_, valor, _) => Text(
                valor,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
              ),
            ),
          ),
          ..._bloques.asMap().entries.map((e) => _buildBloque(e.key, e.value)),
          // Área tappable vacía debajo del contenido
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final ultimo = _bloques.last;
              // Si el último bloque es texto regular y está vacío, enfocarlo
              if (!ultimo.esImagen && !ultimo.esChecklist) {
                ultimo.focus.requestFocus();
              } else {
                // Agregar bloque regular nuevo y enfocarlo
                final nuevo = _Bloque(texto: '');
                setState(() => _bloques.add(nuevo));
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => nuevo.focus.requestFocus(),
                );
              }
            },
            child: const SizedBox(width: double.infinity, height: 200),
          ),
        ],
      ),
    );
  }

  // ── Bloque de imagen inline con barra flotante ───────────────
  Widget _buildBloqueImagen(int idx, _Bloque bloque) {
    final cs = Theme.of(context).colorScheme;
    final ruta = bloque.rutaImagen ?? '';
    final halfW = (MediaQuery.of(context).size.width - 44) / 2;
    final ancho = bloque.imagenMitad ? halfW : double.infinity;

    // Widget de la imagen con comentario (reutilizado en ambos layouts)
    final seleccionada = _bloqueConOverlay == bloque;
    final imagenContainer = GestureDetector(
      onTap: () => _mostrarBarraFlotante(idx, bloque),
      child: Container(
        key: bloque.imagenKey,
        width: ancho,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionada
                ? const Color(0xFFE8B237)
                : cs.outlineVariant,
            width: seleccionada ? 2.2 : 1,
          ),
          boxShadow: seleccionada
              ? [
                  BoxShadow(
                    color: const Color(0xFFE8B237).withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.file(
                File(ruta),
                width: ancho,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, _, _) => Container(
                  width: ancho, height: 180,
                  color: cs.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_outlined,
                      color: cs.onSurfaceVariant, size: 40),
                ),
              ),
              // Comentario guardado (solo lectura)
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: bloque.mostrarComentario &&
                          bloque.comentarioCtrl.text.isNotEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.08),
                            border: Border(
                              top: BorderSide(
                                  color: cs.primary.withValues(alpha: 0.2),
                                  width: 1),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.notes_rounded,
                                  size: 15,
                                  color: cs.primary.withValues(alpha: 0.7)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  bloque.comentarioCtrl.text,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurfaceVariant,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
    );  // cierra GestureDetector → imagenContainer

    // Layout: si es mitad de ancho, imagen a la izq + área tappable a la derecha
    if (bloque.imagenMitad) {
      // El siguiente bloque debe ser texto (garantizado por _normalizarBloques)
      final idxSiguiente =
          idx + 1 < _bloques.length && !_bloques[idx + 1].esImagen ? idx + 1 : null;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              imagenContainer,
              const SizedBox(width: 8),
              // Área tappable a la derecha: al tocarla, enfoca el bloque de texto siguiente
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (idxSiguiente != null) {
                      _bloques[idxSiguiente].focus.requestFocus();
                    }
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Layout normal: imagen a ancho completo
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: imagenContainer,
    );
  }

  // ── Barra flotante via Overlay ────────────────────────────────
  void _mostrarBarraFlotante(int idx, _Bloque bloque) {
    _ocultarBarraFlotante();
    // Marca la imagen seleccionada para mostrar el borde amarillo
    setState(() => _bloqueConOverlay = bloque);

    final box = bloque.imagenKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final cs = Theme.of(context).colorScheme;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screenW = MediaQuery.of(context).size.width;
    const barH = 54.0;
    const barW = 248.0; // 4 iconos × 62px

    // Centrada vertical y horizontalmente en la imagen
    final top = pos.dy + (size.height - barH) / 2;
    final left = (pos.dx + size.width / 2 - barW / 2).clamp(8.0, screenW - barW - 8);

    _overlayEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _ocultarBarraFlotante,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            top: top,
            left: left,
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: barH,
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cs.surfaceContainerLowest.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _iconoOverlay(Icons.comment_outlined, () {
                      _ocultarBarraFlotante();
                      setState(() {
                        bloque.mostrarComentario = true;
                        _comentarioActivo = bloque;
                      });
                      // Esperar al siguiente frame para que el TextField esté montado
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => bloque.comentarioFocus.requestFocus(),
                      );
                    }, color: cs.onSurface),
                    _iconoOverlay(Icons.draw_outlined, () {
                      _ocultarBarraFlotante();
                      AppSnackBar.error(context, 'Próximamente');
                    }, color: cs.onSurface),
                    _iconoOverlay(
                      bloque.imagenMitad
                          ? Icons.fullscreen_rounded
                          : Icons.photo_size_select_large_outlined,
                      () {
                        _ocultarBarraFlotante();
                        setState(() => bloque.imagenMitad = !bloque.imagenMitad);
                        // Guardar inmediatamente al cambiar el layout de la imagen
                        _guardarInmediato();
                      },
                      color: cs.onSurface,
                    ),
                    _iconoOverlay(Icons.delete_outline_rounded, () {
                      _ocultarBarraFlotante();
                      setState(() {
                        _bloques.removeAt(idx);
                        _normalizarBloques();
                      });
                      // Guardar inmediatamente al eliminar la imagen
                      _guardarInmediato();
                    }, color: cs.error),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _ocultarBarraFlotante() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    // Los callers siempre hacen su propio setState; basta con limpiar la variable
    _bloqueConOverlay = null;
  }

  // Garantiza que siempre haya un bloque de texto entre imágenes consecutivas
  // y que la lista no termine con una imagen (para poder seguir escribiendo).
  void _normalizarBloques() {
    bool cambio = true;
    while (cambio) {
      cambio = false;
      for (int i = 0; i < _bloques.length; i++) {
        if (_bloques[i].esImagen) {
          final esUltimo = i == _bloques.length - 1;
          final siguienteEsImagen = !esUltimo && _bloques[i + 1].esImagen;
          if (esUltimo || siguienteEsImagen) {
            _bloques.insert(i + 1, _Bloque(texto: ''));
            cambio = true;
            break;
          }
        }
      }
    }
  }

  Widget _iconoOverlay(IconData icon, VoidCallback onTap,
      {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 62, height: 54,
        child: Icon(icon, color: color, size: 25),
      ),
    );
  }


  // ── Bloque unificado: key DIRECTAMENTE en el TextField para que Flutter
  // preserve la conexión IME cuando el bloque cambia de posición en la lista.
  Widget _buildBloque(int idx, _Bloque bloque) {
    if (bloque.esImagen) return _buildBloqueImagen(idx, bloque);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: bloque.esChecklist ? 15 : 13),
      child: Row(
        // Checklist: centrado (checkbox alineado con el texto).
        // Regular: arriba (el espaciador izquierdo no flota al centro en bloques multi-línea).
        crossAxisAlignment: bloque.esChecklist ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),
          // Checkbox: solo ocupa espacio cuando hay checklist
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: bloque.esChecklist ? 30.0 : 6.05,
            height: 30,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: bloque.esChecklist
                ? GestureDetector(
                    behavior: HitTestBehavior.deferToChild,
                    onTap: () => setState(() => bloque.hecho = !bloque.hecho),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: bloque.hecho ? cs.primary : Colors.transparent,
                          border: Border.all(
                            color: bloque.hecho ? cs.primary : cs.onSurface.withValues(alpha: 0.35),
                            width: 1.6,
                          ),
                        ),
                        child: bloque.hecho
                            ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                            : null,
                      ),
                    ),
                  )
                : null,
          ),
          // KEY en el TextField directamente → preserva la conexión IME
          Expanded(
            child: TextField(
                key: ObjectKey(bloque),
                controller: bloque.ctrl,
                focusNode: bloque.focus
                  ..onKeyEvent = (node, event) => _onBloqueKeyEvent(idx, event),
                onChanged: (v) => _onBloqueChanged(idx, v),
              style: TextStyle(
                fontSize: _tamanoFuente,
                fontWeight: FontWeight.normal,
                decoration: bloque.hecho ? TextDecoration.lineThrough : TextDecoration.none,
                decorationColor: cs.onSurfaceVariant,
                color: bloque.hecho ? cs.onSurface.withValues(alpha: 0.38) : cs.onSurface,
                height: 2.2,
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              enableInteractiveSelection: true,
              decoration: InputDecoration(
                hintText: idx == 0 ? 'Empieza a escribir...' : null,
                hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
        ],
      ),
    );
  }

  // ── BARRA DE COMENTARIO (reemplaza la barra inferior mientras se escribe) ──
  Widget _buildBarraComentario(_Bloque bloque) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.notes_rounded, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Focus(
              onFocusChange: (tieneFoco) {
                if (!tieneFoco) setState(() => _comentarioActivo = null);
              },
              child: TextField(
                controller: bloque.comentarioCtrl,
                focusNode: bloque.comentarioFocus,
                style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Escribe un comentario...',
                  hintStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              bloque.comentarioFocus.unfocus();
              setState(() => _comentarioActivo = null);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: cs.primary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Listo',
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── BARRA INFERIOR (rediseñada) ──────────────────────────────
  Widget _buildBarraInferior() {
    return Listener(
      // En onPointerDown (antes de que Flutter transfiera el foco) guardamos el índice
      // Y re-enfocamos inmediatamente para que el teclado nunca se cierre
      onPointerDown: (_) {
        final idx = _bloques.indexWhere((b) => b.focus.hasFocus);
        if (idx != -1) {
          _ultimoBloqueIdx = idx;
          _bloques[idx].focus.requestFocus();
        }
      },
      child: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_etiquetas.isNotEmpty) ...[_buildChipsEtiquetas(), const SizedBox(height: 6)],
          // Fila de herramientas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Negrita
              _toolbarBtnB(() {
                final idx = _ultimoBloqueIdx.clamp(0, _bloques.length - 1);
                _bloques[idx].ctrl.toggleNegrita();
                setState(() {});
              }, _negritaActiva),
              // Resaltado
              _toolbarBtnResaltado(() {
                final idx = _ultimoBloqueIdx.clamp(0, _bloques.length - 1);
                _bloques[idx].ctrl.toggleResaltado();
                setState(() {});
              }, _resaltadoActivo),
              // Separador visual
              Container(width: 1, height: 22, color: Theme.of(context).colorScheme.outlineVariant),
              // Tamaño de fuente
              _toolbarBtnA('+', () => _aplicarFormato(() => _tamanoFuente = (_tamanoFuente + 2).clamp(_tamanoMin, _tamanoMax))),
              _toolbarBtnA('-', () => _aplicarFormato(() => _tamanoFuente = (_tamanoFuente - 2).clamp(_tamanoMin, _tamanoMax))),
              // Separador visual
              Container(width: 1, height: 22, color: Theme.of(context).colorScheme.outlineVariant),
              // Checklist
              _toolbarBtn(Icons.check_box_outlined, _toggleChecklistBloqueActual, _bloqueActualEsChecklist),
              // Separador visual
              Container(width: 1, height: 22, color: Theme.of(context).colorScheme.outlineVariant),
              // Imagen y dibujo
              _toolbarBtn(Icons.image_outlined, _mostrarModalImagen, false),
              _toolbarBtn(Icons.gesture_rounded, null, false),
            ],
          ),
        ],
      ),
    ),   // cierre Container
    );   // cierre Listener
  }

  // ── Helpers toolbar ──────────────────────────────────────────
  Widget _toolbarBtn(IconData icon, VoidCallback? onTap, bool activo) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activo ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.13) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 22,
          color: activo ? Theme.of(context).colorScheme.primary
              : onTap == null ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _toolbarBtnA(String signo, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36, alignment: Alignment.center,
        child: RichText(text: TextSpan(children: [
          TextSpan(text: 'A', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          WidgetSpan(
            baseline: TextBaseline.alphabetic,
            alignment: PlaceholderAlignment.top,
            child: Text(signo, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ])),
      ),
    );
  }

  // Botón resaltador (letra A con fondo amarillo)
  Widget _toolbarBtnResaltado(VoidCallback onTap, bool activo) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36, height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activo ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.13) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 7,
              child: Container(
                width: 18, height: 7,
                color: activo ? Colors.yellow.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
            Text('A', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold,
              color: activo ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
            )),
          ],
        ),
      ),
    );
  }

  Widget _toolbarBtnB(VoidCallback onTap, bool activo) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36, height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activo ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.13) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('B', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold,
          color: activo ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
        )),
      ),
    );
  }

  Widget _buildChipsEtiquetas() {
    return Wrap(
      spacing: 6, runSpacing: 4,
      children: _etiquetas.map((tag) => Chip(
        label: Text(tag, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
        deleteIcon: const Icon(Icons.close_rounded, size: 14),
        onDeleted: () => setState(() => _etiquetas.remove(tag)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      )).toList(),
    );
  }

}

// ── Estados de sincronización con el servidor ────────────────
enum _EstadoSync { guardando, sincronizado, pendiente }

// ── Visor de imagen a pantalla completa con zoom ─────────────
class _VisorImagen extends StatefulWidget {
  final String ruta;
  final String heroTag;
  const _VisorImagen({required this.ruta, required this.heroTag});

  @override
  State<_VisorImagen> createState() => _VisorImagenState();
}

class _VisorImagenState extends State<_VisorImagen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: Stack(
        children: [
          // Imagen con zoom y paneo
          Center(
            child: Hero(
              tag: widget.heroTag,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Image.file(
                  File(widget.ruta),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
          // Botón cerrar
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(12),
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
