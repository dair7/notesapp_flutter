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

// ── Rango de texto en negrita ────────────────────────────────
class _Rango {
  final int inicio;
  final int fin;
  const _Rango(this.inicio, this.fin);
}

// ── Controller con negrita inline por selección o cursor ─────
class _RichController extends TextEditingController {
  final List<_Rango> _negrita = [];
  bool _cursorNegrita = false;

  bool get cursorNegrita => _cursorNegrita;
  List<_Rango> get rangos => List.unmodifiable(_negrita);

  void toggleNegrita() {
    final sel = selection;
    if (sel.isCollapsed) {
      _cursorNegrita = !_cursorNegrita;
      notifyListeners();
      return;
    }
    if (_rangoCubierto(sel.start, sel.end)) {
      _quitarEnRango(sel.start, sel.end);
    } else {
      _agregarEnRango(sel.start, sel.end);
    }
    notifyListeners();
  }

  bool esCursorNegrita() {
    final sel = selection;
    if (sel.isCollapsed) return _cursorNegrita || _posEnNegrita(sel.baseOffset - 1);
    return _rangoCubierto(sel.start, sel.end);
  }

  bool _posEnNegrita(int pos) =>
      pos >= 0 && _negrita.any((r) => r.inicio <= pos && pos < r.fin);

  bool _rangoCubierto(int start, int end) {
    if (end <= start) return false;
    for (int i = start; i < end; i++) {
      if (!_posEnNegrita(i)) return false;
    }
    return true;
  }

  void _agregarEnRango(int start, int end) {
    _quitarEnRango(start, end);
    _negrita.add(_Rango(start, end));
    _ordenarYFusionar();
  }

  void _quitarEnRango(int start, int end) {
    final res = <_Rango>[];
    for (final r in _negrita) {
      if (r.fin <= start || r.inicio >= end) { res.add(r); continue; }
      if (r.inicio < start) res.add(_Rango(r.inicio, start));
      if (r.fin > end) res.add(_Rango(end, r.fin));
    }
    _negrita..clear()..addAll(res);
  }

  void _ordenarYFusionar() {
    _negrita.sort((a, b) => a.inicio.compareTo(b.inicio));
    final res = <_Rango>[];
    for (final r in _negrita) {
      if (res.isNotEmpty && r.inicio <= res.last.fin) {
        final l = res.removeLast();
        res.add(_Rango(l.inicio, r.fin > l.fin ? r.fin : l.fin));
      } else {
        res.add(r);
      }
    }
    _negrita..clear()..addAll(res);
  }

  @override
  set value(TextEditingValue nv) {
    final oldText = text;
    final newText = nv.text;
    if (newText != oldText && (_negrita.isNotEmpty || _cursorNegrita)) {
      _ajustarRangos(oldText, newText);
    }
    super.value = nv;
  }

  void _ajustarRangos(String oldText, String newText) {
    if (newText.isEmpty) { _negrita.clear(); return; }
    int start = 0;
    while (start < oldText.length && start < newText.length &&
        oldText[start] == newText[start]) start++;
    final delta = newText.length - oldText.length;
    if (delta == 0) return;

    if (delta > 0) {
      for (int i = 0; i < _negrita.length; i++) {
        final r = _negrita[i];
        _negrita[i] = _Rango(
          r.inicio > start ? r.inicio + delta : r.inicio,
          r.fin >= start   ? r.fin   + delta : r.fin,
        );
      }
      if (_cursorNegrita) _agregarEnRango(start, start + delta);
    } else {
      final deleteEnd = start - delta;
      _quitarEnRango(start, deleteEnd);
      for (int i = 0; i < _negrita.length; i++) {
        final r = _negrita[i];
        final ni = (r.inicio > deleteEnd ? r.inicio + delta : r.inicio).clamp(0, newText.length);
        final nf = (r.fin    > deleteEnd ? r.fin    + delta : r.fin   ).clamp(0, newText.length);
        _negrita[i] = _Rango(ni, nf);
      }
      _negrita.removeWhere((r) => r.inicio >= r.fin);
    }
  }

  // Fusionar con el bloque anterior preservando rangos
  void fusionarConAnterior(String textoPrevio, List<_Rango> rangosPrevio) {
    final desplazados = _negrita
        .map((r) => _Rango(r.inicio + textoPrevio.length, r.fin + textoPrevio.length))
        .toList();
    _negrita..clear()..addAll(rangosPrevio)..addAll(desplazados);
    _ordenarYFusionar();
    super.value = TextEditingValue(
      text: textoPrevio + text,
      selection: TextSelection.collapsed(offset: textoPrevio.length),
    );
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (_negrita.isEmpty || text.isEmpty) return TextSpan(style: style, text: text);
    final spans = <InlineSpan>[];
    int pos = 0;
    final sorted = List<_Rango>.from(_negrita)..sort((a, b) => a.inicio.compareTo(b.inicio));
    for (final r in sorted) {
      final ini = r.inicio.clamp(0, text.length);
      final fin = r.fin.clamp(ini, text.length);
      if (ini > pos) spans.add(TextSpan(style: style, text: text.substring(pos, ini)));
      if (ini < fin) {
        spans.add(TextSpan(
          style: (style ?? const TextStyle()).copyWith(fontWeight: FontWeight.bold),
          text: text.substring(ini, fin),
        ));
        pos = fin;
      }
    }
    if (pos < text.length) spans.add(TextSpan(style: style, text: text.substring(pos)));
    return TextSpan(style: style, children: spans);
  }

  // Serializar con marcadores **...** para persistencia
  String textoConFormato() {
    if (_negrita.isEmpty) return text;
    final sorted = List<_Rango>.from(_negrita)..sort((a, b) => a.inicio.compareTo(b.inicio));
    final buf = StringBuffer();
    int pos = 0;
    for (final r in sorted) {
      final ini = r.inicio.clamp(0, text.length);
      final fin = r.fin.clamp(ini, text.length);
      if (ini > pos) buf.write(text.substring(pos, ini));
      if (ini < fin) {
        buf.write('**'); buf.write(text.substring(ini, fin)); buf.write('**');
        pos = fin;
      }
    }
    if (pos < text.length) buf.write(text.substring(pos));
    return buf.toString();
  }

  void cargarDesde(String textoFormateado) {
    _negrita.clear();
    _cursorNegrita = false;
    if (!textoFormateado.contains('**')) {
      super.value = TextEditingValue(text: textoFormateado);
      return;
    }
    final buf = StringBuffer();
    int i = 0, realPos = 0;
    while (i < textoFormateado.length) {
      if (i + 1 < textoFormateado.length &&
          textoFormateado[i] == '*' && textoFormateado[i + 1] == '*') {
        i += 2;
        final ini = realPos;
        while (i < textoFormateado.length) {
          if (i + 1 < textoFormateado.length &&
              textoFormateado[i] == '*' && textoFormateado[i + 1] == '*') { i += 2; break; }
          buf.write(textoFormateado[i++]); realPos++;
        }
        if (realPos > ini) _negrita.add(_Rango(ini, realPos));
      } else {
        buf.write(textoFormateado[i++]); realPos++;
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
  })  : ctrl = _RichController()..cargarDesde(texto),
        focus = FocusNode(),
        comentarioCtrl = TextEditingController(text: comentario),
        comentarioFocus = FocusNode();

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

  bool _isLoading = false;
  bool _merging = false; // guard para evitar fusiones re-entrantes
  List<String> _etiquetas = [];
  final ImagePicker _picker = ImagePicker();
  _Bloque? _comentarioActivo; // bloque cuyo comentario está siendo editado
  OverlayEntry? _overlayEntry; // barra flotante de imagen activa
  final ScrollController _scrollController = ScrollController();
  bool _modoEnfocado = false;
  // Índice del último bloque enfocado (capturado antes de que el tap robe el foco)
  int _ultimoBloqueIdx = 0;

  // Formato global del contenido (negrita es ahora inline por bloque)
  bool _resaltado = false;
  double _tamanoFuente = 16.0;
  static const double _tamanoMin = 12.0;
  static const double _tamanoMax = 24.0;

  // Contador (actualizado con debounce para no hacer rebuild en cada tecla)
  final _contadorNotifier = ValueNotifier<String>('');
  Timer? _debounceContador;

  // ── Metadatos de formato (negrita, resaltado, tamaño fuente) ─
  void _cargarFormato(String raw) {
    if (!raw.startsWith('[fmt:')) return;
    final end = raw.indexOf(']');
    if (end < 0) return;
    for (final parte in raw.substring(5, end).split(',')) {
      final kv = parte.split('=');
      if (kv.length != 2) continue;
      switch (kv[0]) {
        case 'r': _resaltado = kv[1] == '1'; break;
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
    final meta = '[fmt:b=0,r=${_resaltado ? 1 : 0},fs=${_tamanoFuente.toInt()}]';
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
      // Checklist → regular: quitar flag (el texto se une al bloque regular adyacente en el próximo guardado)
      setState(() { bloque.esChecklist = false; bloque.hecho = false; });
      return;
    }

    // Regular → checklist: si el bloque tiene varias líneas, dividir cada una en su propio ítem
    final lineas = bloque.ctrl.text.split('\n');
    if (lineas.length <= 1) {
      setState(() => bloque.esChecklist = true);
      return;
    }
    final nuevosBloques = lineas.map((l) => _Bloque(texto: l, esChecklist: true)).toList();
    setState(() {
      _bloques.removeAt(idx);
      _bloques.insertAll(idx, nuevosBloques);
    });
  }

  bool get _bloqueActualEsChecklist {
    final idx = _ultimoBloqueIdx.clamp(0, _bloques.length - 1);
    return _bloques[idx].esChecklist;
  }

  bool get _negritaActiva {
    final idx = _ultimoBloqueIdx.clamp(0, _bloques.length - 1);
    return _bloques[idx].ctrl.esCursorNegrita();
  }

  // ── Fusión inversa: solo se usa para ítems checklist.
  // Los bloques regulares nunca necesitan fusionarse porque no se dividen.
  void _fusionarConAnterior(int idx) {
    if (_merging || idx <= 0 || idx >= _bloques.length) return;
    _merging = true;
    final previo = _bloques[idx - 1];
    final actual = _bloques[idx];
    actual.esChecklist = previo.esChecklist;
    actual.hecho = previo.hecho;
    actual.ctrl.fusionarConAnterior(previo.ctrl.text, previo.ctrl.rangos);
    setState(() => _bloques.removeAt(idx - 1));
    actual.focus.requestFocus();
    _merging = false;
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

  // ── Backspace en ítem checklist vacío → fusionar con el anterior.
  // Solo aplica a checklists; los bloques regulares no necesitan este handler.
  KeyEventResult _onBloqueKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return KeyEventResult.ignored;
    if (index <= 0 || index >= _bloques.length) return KeyEventResult.ignored;
    final bloque = _bloques[index];
    if (bloque.esChecklist && bloque.ctrl.text.isEmpty) {
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

  // ── Etiquetas ───────────────────────────────────────────────
  void _agregarEtiqueta(String texto) {
    final tag = texto.trim().toLowerCase();
    if (tag.isNotEmpty && !_etiquetas.contains(tag) && _etiquetas.length < 5) {
      setState(() { _etiquetas.add(tag); _etiquetaController.clear(); });
    } else {
      _etiquetaController.clear();
    }
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
                    color: Colors.black.withOpacity(0.12),
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
          color: c.withOpacity(0.06),
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
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'No se pudo obtener la imagen');
    }
  }

  // ── Guardar ─────────────────────────────────────────────────
  Future<void> _guardarNota() async {
    final titulo = _tituloController.text.trim();
    final textoPlano = _serializar().trim();
    if (titulo.isEmpty && textoPlano.isEmpty) {
      AppSnackBar.error(context, 'La nota está vacía');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final esEdicion = widget.notaToEdit != null;
      final nota = Nota(
        id: esEdicion ? widget.notaToEdit!.id : null,
        titulo: titulo.isEmpty ? 'Sin título' : titulo,
        contenido: _serializarConFormato(),
        fechaCreacion: esEdicion ? widget.notaToEdit!.fechaCreacion : DateTime.now(),
        estado: esEdicion ? widget.notaToEdit!.estado : EstadoNoteType.ACTIVA,
        color: null,
        etiquetas: _etiquetas,
      );
      if (esEdicion) {
        await ref.read(notesProvider.notifier).updateNota(nota);
      } else {
        await ref.read(notesProvider.notifier).addNota(nota);
      }
      if (mounted) {
        if (_modoEnfocado) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        AppSnackBar.exito(context, esEdicion ? 'Nota actualizada' : 'Nota guardada');
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) AppSnackBar.error(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  double _prevBottomInset = 0;
  bool _tecladoVisible = false;

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    final abierto = bottomInset > 0;

    // Transición visible → oculto: quitar foco
    if (_prevBottomInset > 0 && bottomInset == 0 && mounted) {
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
  void dispose() {
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
      backgroundColor: cs.surfaceContainerLow,
      appBar: _modoEnfocado ? null : _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _buildAreaContenido()),
              if (!_modoEnfocado && _tecladoVisible)
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
                    color: Theme.of(context).colorScheme.inverseSurface.withOpacity(0.85),
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
      backgroundColor: cs.surfaceContainerLow,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: cs.onSurface),
      title: Text(widget.notaToEdit != null ? 'Editar Nota' : 'Nueva Nota',
          style: TextStyle(color: cs.onSurface, fontSize: 16)),
      actions: [
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
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: TextButton.icon(
            onPressed: _isLoading ? null : _guardarNota,
            icon: _isLoading
                ? SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                : Icon(Icons.check, color: cs.primary),
            label: Text('Guardar',
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
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
            padding: const EdgeInsets.only(bottom: 6),
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
            padding: const EdgeInsets.only(bottom: 28),
            child: ValueListenableBuilder<String>(
              valueListenable: _contadorNotifier,
              builder: (_, valor, __) => Text(
                valor,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withOpacity(0.6)),
              ),
            ),
          ),
          ..._bloques.asMap().entries.map((e) => _buildBloque(e.key, e.value)),
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
    final imagenContainer = GestureDetector(
      onTap: () => _mostrarBarraFlotante(idx, bloque),
      child: Container(
        key: bloque.imagenKey,
        width: ancho,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant, width: 1),
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
                errorBuilder: (_, __, ___) => Container(
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
                            color: cs.primary.withOpacity(0.08),
                            border: Border(
                              top: BorderSide(
                                  color: cs.primary.withOpacity(0.2),
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
                                  color: cs.primary.withOpacity(0.7)),
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
                      color: Colors.black.withOpacity(0.18),
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
                      Future.microtask(() => bloque.comentarioFocus.requestFocus());
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
                      },
                      color: cs.onSurface,
                    ),
                    _iconoOverlay(Icons.delete_outline_rounded, () {
                      _ocultarBarraFlotante();
                      setState(() {
                        _bloques.removeAt(idx);
                        _normalizarBloques();
                      });
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


  // ── Visor de imagen a pantalla completa ──────────────────────
  void _verImagenCompleta(String ruta, String heroTag) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _VisorImagen(ruta: ruta, heroTag: heroTag),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
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
                    onTap: () => setState(() => bloque.hecho = !bloque.hecho),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: bloque.hecho ? cs.primary : Colors.transparent,
                          border: Border.all(
                            color: bloque.hecho ? cs.primary : cs.onSurface.withOpacity(0.35),
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
                backgroundColor: _resaltado && !bloque.hecho ? Colors.yellow.withOpacity(0.45) : null,
                decoration: bloque.hecho ? TextDecoration.lineThrough : TextDecoration.none,
                decorationColor: cs.onSurfaceVariant,
                color: bloque.hecho ? cs.onSurface.withOpacity(0.38) : cs.onSurface,
                height: 2.2,
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
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
              backgroundColor: cs.primary.withOpacity(0.1),
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
              _toolbarBtnResaltado(() => _aplicarFormato(() => _resaltado = !_resaltado), _resaltado),
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
          color: activo ? Theme.of(context).colorScheme.primary.withOpacity(0.13) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 22,
          color: activo ? Theme.of(context).colorScheme.primary
              : onTap == null ? Theme.of(context).colorScheme.onSurface.withOpacity(0.2)
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
          color: activo ? Theme.of(context).colorScheme.primary.withOpacity(0.13) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 7,
              child: Container(
                width: 18, height: 7,
                color: activo ? Colors.yellow.withOpacity(0.7) : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
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
          color: activo ? Theme.of(context).colorScheme.primary.withOpacity(0.13) : Colors.transparent,
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
        backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      )).toList(),
    );
  }

  Widget _buildInputEtiqueta() {
    return Row(
      children: [
        Icon(Icons.label_outline_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _etiquetaController,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: _etiquetas.length >= 5 ? 'Máximo 5 etiquetas' : 'Agregar etiqueta...',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
            ),
            enabled: _etiquetas.length < 5,
            textCapitalization: TextCapitalization.none,
            onSubmitted: _agregarEtiqueta,
          ),
        ),
        if (_etiquetaController.text.trim().isNotEmpty)
          GestureDetector(
            onTap: () => _agregarEtiqueta(_etiquetaController.text),
            child: Icon(Icons.add_circle_outline_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
          ),
      ],
    );
  }
}

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
      backgroundColor: Colors.black,
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
                  errorBuilder: (_, __, ___) => const Icon(
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
                    color: Colors.black.withOpacity(0.5),
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
