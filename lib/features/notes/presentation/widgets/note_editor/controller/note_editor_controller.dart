import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/note_block.dart';
import '../models/rich_text_controller.dart';
import '../serializer/note_serializer.dart';

/// Gestiona el estado completo del editor de notas.
///
/// Responsabilidades:
/// - Mantener la lista de [NoteBlock]s
/// - Conservar UN ÚNICO [RichTextController] y [FocusNode] activos
///   (el teclado virtual nunca se cierra al cambiar de bloque porque el
///    mismo TextField siempre está montado en el árbol)
/// - Exponer operaciones de bloque: activar, fusionar, dividir, imagen
/// - Calcular el contador de palabras con debounce
/// - Disparar el auto-guardado vía callbacks (sin acoplarse a Riverpod)
class NoteEditorController extends ChangeNotifier {

  // ── Controladores de UI ───────────────────────────────────────

  final RichTextController activeCtrl    = RichTextController();
  final FocusNode          activeFocus   = FocusNode();
  final TextEditingController titleCtrl  = TextEditingController();
  final ValueNotifier<String> wordCountNotifier = ValueNotifier('');

  /// [GlobalKey] asignada al TextField activo.
  /// Preserva la conexión IME aunque el bloque cambie de posición en el árbol.
  final GlobalKey activeFieldKey = GlobalKey();

  // ── Estado interno ────────────────────────────────────────────

  List<NoteBlock> _blocks      = [];
  int    _activeIndex          = 0;
  double _fontSize             = 16.0;
  bool   _merging              = false;

  /// true durante una fusión de bloques. El screen lo usa para evitar que
  /// [WidgetsBindingObserver.didChangeMetrics] cierre el teclado.
  bool get isMerging => _merging;

  // ── Callbacks de guardado ─────────────────────────────────────

  VoidCallback? onSaveRequested;
  VoidCallback? onSaveImmediate;

  // ── Timers ────────────────────────────────────────────────────

  Timer? _wordCountDebounce;
  Timer? _saveDebounce;

  // ── Getters ───────────────────────────────────────────────────

  List<NoteBlock> get blocks             => List.unmodifiable(_blocks);
  int    get activeIndex                 => _activeIndex;
  double get fontSize                    => _fontSize;
  bool   get isCursorBold               => activeCtrl.isCursorBold;
  bool   get isCursorHighlight          => activeCtrl.isCursorHighlight;
  int    get imageCount                  => _blocks.where((b) => b.isImage).length;
  bool   get activeBlockIsChecklist     =>
      _activeIndex < _blocks.length && _blocks[_activeIndex].isChecklist;

  // ── Inicialización ────────────────────────────────────────────

  void initialize({String rawContent = '', String title = ''}) {
    titleCtrl.text = title;
    _fontSize      = NoteSerializer.extractFontSize(rawContent);
    _blocks        = NoteSerializer.parse(rawContent);
    _normalizeBlocks();
    _activeIndex   = 0;
    _loadActiveBlock();
    Future.microtask(_scheduleWordCount);
  }

  // ── Activación de bloques ─────────────────────────────────────

  void activateBlock(int index) {
    if (index == _activeIndex) { activeFocus.requestFocus(); return; }
    if (index < 0 || index >= _blocks.length) return;
    if (_blocks[index].isImage) return;
    _flushActiveBlock();
    _activeIndex = index;
    _loadActiveBlock();
    notifyListeners();
    activeFocus.requestFocus();
  }

  void _flushActiveBlock() {
    if (_activeIndex >= _blocks.length) return;
    final block           = _blocks[_activeIndex];
    block.rawText         = activeCtrl.text;
    block.boldRanges      = List.from(activeCtrl.boldRanges);
    block.highlightRanges = List.from(activeCtrl.highlightRanges);
  }

  void _loadActiveBlock() {
    if (_activeIndex >= _blocks.length) return;
    final block = _blocks[_activeIndex];
    activeCtrl.loadFromRanges(block.rawText, block.boldRanges, block.highlightRanges);
  }

  // ── Callbacks del TextField ───────────────────────────────────

  void onActiveTextChanged(String newText) {
    if (_activeIndex >= _blocks.length) return;
    final block = _blocks[_activeIndex];

    if (!block.isChecklist) {
      _scheduleWordCount();
      _scheduleSave();
      return;
    }

    // Checklist vacío + Backspace → fusionar con el bloque anterior
    if (newText.isEmpty && _activeIndex > 0) {
      _mergeWithPrevious(_activeIndex);
      return;
    }

    // Enter en checklist → crear nuevo ítem debajo
    final newlinePos = newText.indexOf('\n');
    if (newlinePos >= 0) {
      final before = newText.substring(0, newlinePos);
      final after  = newText.substring(newlinePos + 1);
      activeCtrl.value = TextEditingValue(
        text: before,
        selection: TextSelection.collapsed(offset: before.length),
      );
      _flushActiveBlock();
      final newBlock = NoteBlock.checklist(after, isDone: false);
      _blocks.insert(_activeIndex + 1, newBlock);
      _activeIndex++;
      _loadActiveBlock();
      notifyListeners();
      activeFocus.requestFocus();
      _scheduleWordCount();
      _scheduleSave();
      return;
    }

    _scheduleWordCount();
    _scheduleSave();
  }

  void handleBackspaceAtStart() {
    if (_merging) return;
    if (_activeIndex <= 0 || _activeIndex >= _blocks.length) return;
    if (_blocks[_activeIndex - 1].isImage) return;
    _mergeWithPrevious(_activeIndex);
  }

  void _mergeWithPrevious(int index) {
    if (_merging || index <= 0 || index >= _blocks.length) return;
    _merging = true;

    final prev    = _blocks[index - 1];
    if (_activeIndex != index) _activeIndex = index;

    activeCtrl.mergeWithPrevious(prev.rawText, prev.boldRanges, prev.highlightRanges);
    _blocks.removeAt(index - 1);
    _activeIndex = index - 1;
    _blocks[_activeIndex].rawText         = activeCtrl.text;
    _blocks[_activeIndex].boldRanges      = List.from(activeCtrl.boldRanges);
    _blocks[_activeIndex].highlightRanges = List.from(activeCtrl.highlightRanges);

    notifyListeners();
    activeFocus.requestFocus();
    _merging = false;
    _scheduleWordCount();
    _scheduleSave();
  }

  // ── Checklist ─────────────────────────────────────────────────

  void toggleChecklistAtCursor() {
    _flushActiveBlock();
    final idx   = _activeIndex.clamp(0, _blocks.length - 1);
    final block = _blocks[idx];

    // ── Checklist → texto: quitar el check preservando formato ───
    if (block.isChecklist) {
      final replacement = NoteBlock.text(
        block.rawText,
        boldRanges:      block.boldRanges,
        highlightRanges: block.highlightRanges,
      );
      _blocks[idx] = replacement;
      _activeIndex  = idx;
      // No llamamos _loadActiveBlock(): el activeCtrl ya tiene el texto y
      // los rangos correctos (guardados por _flushActiveBlock al inicio).
      // Llamarlo solo resetearía el cursor y _cursorBold innecesariamente.
      notifyListeners();
      activeFocus.requestFocus();
      _scheduleSave();
      return;
    }

    // Capturar los rangos ANTES de modificar nada
    final boldRanges      = List<FormatRange>.from(block.boldRanges);
    final highlightRanges = List<FormatRange>.from(block.highlightRanges);

    final text  = activeCtrl.text;
    final lines = text.split('\n');

    // ── Bloque de una línea → convertir directamente, preservar formato ──
    if (lines.length <= 1) {
      final replacement = NoteBlock.checklist(block.rawText, isDone: false);
      replacement.boldRanges      = boldRanges;
      replacement.highlightRanges = highlightRanges;
      _blocks[idx] = replacement;
      _activeIndex  = idx;
      // No llamamos _loadActiveBlock(): el activeCtrl ya tiene el contenido
      // correcto desde _flushActiveBlock y preserva la posición del cursor
      // y el estado _cursorBold, evitando que el botón B se desactive.
      notifyListeners();
      activeFocus.requestFocus();
      _scheduleSave();
      return;
    }

    // ── Bloque multi-línea: dividir y asignar rangos a cada parte ──
    //
    // Primero calculamos el offset (en el texto completo) donde comienza
    // cada línea, para poder recortar los rangos de formato correctamente.
    final lineOffsets = <int>[];
    int off = 0;
    for (final line in lines) {
      lineOffsets.add(off);
      off += line.length + 1; // +1 por el '\n'
    }

    final cursorOffset = activeCtrl.selection.baseOffset.clamp(0, text.length);
    int lineIdx = 0;
    for (int i = 0; i < lines.length; i++) {
      final lineEnd = lineOffsets[i] + lines[i].length;
      if (cursorOffset <= lineEnd) { lineIdx = i; break; }
      if (i == lines.length - 1) lineIdx = i;
    }
    lineIdx = lineIdx.clamp(0, lines.length - 1);

    final newBlocks = <NoteBlock>[];

    // Parte anterior (texto regular)
    if (lineIdx > 0) {
      final partText = lines.sublist(0, lineIdx).join('\n');
      final partEnd  = lineOffsets[lineIdx] - 1; // excluye el '\n' final
      newBlocks.add(NoteBlock.text(
        partText,
        boldRanges:      _sliceRanges(boldRanges,      0, partEnd),
        highlightRanges: _sliceRanges(highlightRanges, 0, partEnd),
      ));
    }

    // Línea del cursor → checklist (con formato preservado)
    final checkFrom = lineOffsets[lineIdx];
    final checkEnd  = checkFrom + lines[lineIdx].length;
    final cl = NoteBlock.checklist(lines[lineIdx], isDone: false);
    cl.boldRanges      = _sliceRanges(boldRanges,      checkFrom, checkEnd);
    cl.highlightRanges = _sliceRanges(highlightRanges, checkFrom, checkEnd);
    newBlocks.add(cl);

    // Parte posterior (texto regular)
    if (lineIdx < lines.length - 1) {
      final afterFrom = lineOffsets[lineIdx + 1];
      final afterText = lines.sublist(lineIdx + 1).join('\n');
      final afterEnd  = afterFrom + afterText.length;
      newBlocks.add(NoteBlock.text(
        afterText,
        boldRanges:      _sliceRanges(boldRanges,      afterFrom, afterEnd),
        highlightRanges: _sliceRanges(highlightRanges, afterFrom, afterEnd),
      ));
    }

    final checklistIdx = idx + (lineIdx > 0 ? 1 : 0);
    _blocks.removeAt(idx);
    _blocks.insertAll(idx, newBlocks);
    _activeIndex = checklistIdx;
    _loadActiveBlock();
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) => activeFocus.requestFocus());
    _scheduleSave();
  }

  void toggleChecklistDone(int index) {
    if (index < 0 || index >= _blocks.length) return;
    if (!_blocks[index].isChecklist) return;
    _blocks[index].isDone = !_blocks[index].isDone;
    notifyListeners();
    _scheduleSave();
  }

  // ── Imágenes ──────────────────────────────────────────────────

  Future<void> insertImage(String sourcePath) async {
    if (imageCount >= 5) throw const ImageLimitException();
    final dir    = await getApplicationDocumentsDirectory();
    final imgDir = Directory(p.join(dir.path, 'notas_imagenes'));
    if (!await imgDir.exists()) await imgDir.create(recursive: true);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}';
    final destPath = p.join(imgDir.path, fileName);
    await File(sourcePath).copy(destPath);
    _flushActiveBlock();
    _blocks.add(NoteBlock.image(imagePath: destPath));
    _normalizeBlocks();
    notifyListeners();
    _saveImmediately();
  }

  void deleteImage(int index) {
    if (index < 0 || index >= _blocks.length || !_blocks[index].isImage) return;
    if (_activeIndex > index) _activeIndex--;
    _blocks.removeAt(index);
    _normalizeBlocks();
    if (_activeIndex >= _blocks.length) _activeIndex = (_blocks.length - 1).clamp(0, _blocks.length - 1);
    notifyListeners();
    _saveImmediately();
  }

  void toggleImageHalf(int index) {
    if (index < 0 || index >= _blocks.length || !_blocks[index].isImage) return;
    _blocks[index].imageHalf = !_blocks[index].imageHalf;
    notifyListeners();
    _saveImmediately();
  }

  void updateImageComment(int index, String comment) {
    if (index < 0 || index >= _blocks.length || !_blocks[index].isImage) return;
    _blocks[index].imageComment = comment;
    _scheduleSave();
  }

  // ── Formato ───────────────────────────────────────────────────

  void toggleBold()      { activeCtrl.toggleBold();      notifyListeners(); }
  void toggleHighlight() { activeCtrl.toggleHighlight(); notifyListeners(); }

  void setFontSize(double size) {
    if (size == _fontSize) return;
    _fontSize = size;
    notifyListeners();
    _scheduleSave();
  }

  // ── Serialización ─────────────────────────────────────────────

  String buildSerializedContent() {
    _flushActiveBlock();
    return NoteSerializer.serialize(_blocks, _fontSize);
  }

  String buildPlainText() {
    _flushActiveBlock();
    final buf   = StringBuffer();
    final title = titleCtrl.text.trim();
    if (title.isNotEmpty) { buf.writeln(title); buf.writeln(); }
    for (final b in _blocks) {
      if (b.isImage) continue;
      final line = b.rawText.trim();
      if (line.isEmpty) continue;
      buf.writeln(b.isChecklist ? '${b.isDone ? '☑' : '☐'} $line' : line);
    }
    return buf.toString().trim();
  }

  // ── Utilidades de rangos ──────────────────────────────────────

  /// Recorta [ranges] al intervalo [from, to] y reajusta los offsets a 0.
  List<FormatRange> _sliceRanges(List<FormatRange> ranges, int from, int to) {
    final result = <FormatRange>[];
    for (final r in ranges) {
      final s = r.start.clamp(from, to);
      final e = r.end.clamp(from, to);
      if (e > s) result.add(FormatRange(s - from, e - from));
    }
    return result;
  }

  // ── Normalización ─────────────────────────────────────────────

  void _normalizeBlocks() {
    if (_blocks.isEmpty) { _blocks.add(NoteBlock.emptyText()); return; }
    bool changed = true;
    while (changed) {
      changed = false;
      for (int i = 0; i < _blocks.length; i++) {
        if (_blocks[i].isImage) {
          final isLast      = i == _blocks.length - 1;
          final nextIsImage = !isLast && _blocks[i + 1].isImage;
          if (isLast || nextIsImage) {
            _blocks.insert(i + 1, NoteBlock.emptyText());
            changed = true;
            break;
          }
        }
      }
    }
  }

  // ── Auto-guardado ─────────────────────────────────────────────

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () => onSaveRequested?.call());
  }

  void _saveImmediately() {
    _saveDebounce?.cancel();
    onSaveImmediate?.call();
  }

  // ── Contador de palabras ──────────────────────────────────────

  void _scheduleWordCount() {
    _wordCountDebounce?.cancel();
    _wordCountDebounce = Timer(const Duration(milliseconds: 600), _updateWordCount);
  }

  void _updateWordCount() {
    _flushActiveBlock();
    final allText = _blocks.where((b) => !b.isImage).map((b) => b.rawText).join(' ');
    final chars   = allText.length;
    final words   = allText.trim().isEmpty ? 0 : allText.trim().split(RegExp(r'\s+')).length;
    wordCountNotifier.value = '$words ${words == 1 ? 'palabra' : 'palabras'} · $chars caracteres';
  }

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _wordCountDebounce?.cancel();
    activeCtrl.dispose();
    activeFocus.dispose();
    titleCtrl.dispose();
    wordCountNotifier.dispose();
    super.dispose();
  }
}

/// Lanzada por [NoteEditorController.insertImage] cuando se alcanza el
/// límite de 5 imágenes por nota.
class ImageLimitException implements Exception {
  const ImageLimitException();
}
