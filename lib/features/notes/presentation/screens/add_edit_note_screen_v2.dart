import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:notes_app/core/utils/app_snackbar.dart';
import 'package:notes_app/core/enums/estado_note_type.dart';
import 'package:notes_app/features/notes/domain/nota_model.dart';
import 'package:notes_app/features/notes/presentation/providers/notes_provider.dart';
import 'package:notes_app/features/reminders/presentation/screens/add_reminder_screen.dart';

import '../widgets/note_editor/controller/note_editor_controller.dart';
import '../widgets/note_editor/active_text_block.dart';
import '../widgets/note_editor/format_toolbar.dart';
import '../widgets/note_editor/image_block.dart';
import '../widgets/note_editor/inactive_block.dart';

// ── Estado de sincronización ──────────────────────────────────────────
enum _SyncState { saving, synced, pending }

/// Versión 2 del editor de notas — arquitectura modular.
///
/// Diferencias clave respecto a [AddEditNoteScreen]:
/// - Un único [TextField] siempre montado → teclado nunca se cierra al
///   fusionar bloques con Backspace.
/// - [SelectionArea] envuelve los bloques inactivos → selección cruzada.
/// - Lógica extraída a [NoteEditorController] — el screen solo orquesta UI.
/// - Bloques inactivos renderizan como [SelectableText] (no editable).
class AddEditNoteScreenV2 extends ConsumerStatefulWidget {
  final Nota? notaToEdit;
  const AddEditNoteScreenV2({super.key, this.notaToEdit});

  @override
  ConsumerState<AddEditNoteScreenV2> createState() =>
      _AddEditNoteScreenV2State();
}

class _AddEditNoteScreenV2State extends ConsumerState<AddEditNoteScreenV2>
    with WidgetsBindingObserver {

  // ── Controller del editor ─────────────────────────────────────
  late final NoteEditorController _ctrl;

  // ── Estado UI local (no pertenece al controller) ──────────────
  final TextEditingController _tagInputCtrl = TextEditingController();
  List<String> _tags           = [];
  _SyncState   _syncState      = _SyncState.synced;
  bool         _isDisposed     = false;
  Timer?       _retryTimer;
  int?         _createdNoteId;
  bool         _errorShown     = false;
  bool         _focusedMode    = false;
  bool         _keyboardVisible = false;
  double       _prevBottomInset = 0;

  final ScrollController _scrollCtrl   = ScrollController();
  final ImagePicker      _picker       = ImagePicker();

  static const double _fontSizeMin = 12.0;
  static const double _fontSizeMax = 24.0;

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _ctrl = NoteEditorController();
    _ctrl.initialize(
      rawContent: widget.notaToEdit?.contenido ?? '',
      title:      widget.notaToEdit?.titulo    ?? '',
    );
    _tags = List.from(widget.notaToEdit?.etiquetas ?? []);

    // Conectar auto-guardado al controller
    _ctrl.onSaveRequested = _doAutoSave;
    _ctrl.onSaveImmediate = _doAutoSave;

    // Guardar 600 ms después del último cambio en el título
    _ctrl.titleCtrl.addListener(_onTitleChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _doAutoSave();
  }

  @override
  void didChangeMetrics() {
    final inset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    final open = inset > 0;

    // Teclado cerrado por el sistema: quitar foco
    // (pero NO durante una fusión de bloques — el teclado debe seguir abierto)
    if (_prevBottomInset > 0 && inset == 0 && mounted && !_ctrl.isMerging) {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    if (open != _keyboardVisible && mounted) {
      setState(() => _keyboardVisible = open);
    }
    _prevBottomInset = inset;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _retryTimer?.cancel();
    _ctrl.titleCtrl.removeListener(_onTitleChanged);
    _doAutoSave(); // guardar al salir
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    _tagInputCtrl.dispose();
    _scrollCtrl.dispose();
    if (_focusedMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  // ── Auto-guardado ─────────────────────────────────────────────

  Timer? _saveDebounce;

  void _onTitleChanged() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _doAutoSave);
  }

  Future<void> _doAutoSave() async {
    final titulo    = _ctrl.titleCtrl.text.trim();
    final contenido = _ctrl.buildSerializedContent().trim();
    if (titulo.isEmpty && contenido.isEmpty) return;
    if (_syncState == _SyncState.saving) return;

    if (!_isDisposed && mounted) {
      setState(() => _syncState = _SyncState.saving);
    }
    _retryTimer?.cancel();

    try {
      final isEdit = widget.notaToEdit != null || _createdNoteId != null;
      final nota = Nota(
        id:            isEdit ? (widget.notaToEdit?.id ?? _createdNoteId) : null,
        titulo:        titulo.isEmpty ? 'Sin título' : titulo,
        contenido:     _ctrl.buildSerializedContent(),
        fechaCreacion: widget.notaToEdit?.fechaCreacion ?? DateTime.now(),
        estado:        widget.notaToEdit?.estado ?? EstadoNoteType.ACTIVA,
        color:         null,
        etiquetas:     _tags,
      );

      if (isEdit) {
        await ref.read(notesProvider.notifier).updateNota(nota);
      } else {
        final created = await ref.read(notesProvider.notifier).addNota(nota);
        _createdNoteId = created.id;
      }

      if (!_isDisposed && mounted) {
        setState(() => _syncState = _SyncState.synced);
        _errorShown = false;
      }
    } catch (_) {
      if (!_isDisposed && mounted) {
        setState(() => _syncState = _SyncState.pending);
        if (!_errorShown) {
          _errorShown = true;
          AppSnackBar.error(context, 'Sin conexión — reintentando automáticamente');
        }
        _retryTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) _doAutoSave();
        });
      }
    }
  }

  // ── Acciones ──────────────────────────────────────────────────

  void _toggleFocusedMode() {
    if (_focusedMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    setState(() => _focusedMode = !_focusedMode);
  }

  Future<void> _shareNote() async {
    final text = _ctrl.buildPlainText();
    if (text.isEmpty) {
      AppSnackBar.error(context, 'La nota está vacía');
      return;
    }
    final title = _ctrl.titleCtrl.text.trim();
    await Share.share(text, subject: title.isNotEmpty ? title : null);
  }

  void _showImageModal() {
    if (_ctrl.imageCount >= 5) {
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
              _modalOption(
                icon:  Icons.photo_library_outlined,
                label: 'Seleccionar de la galería',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
              _modalOption(
                icon:  Icons.camera_alt_outlined,
                label: 'Tomar foto con la cámara',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final img = await _picker.pickImage(
        source:       source,
        imageQuality: source == ImageSource.camera ? 90  : null,
        maxWidth:     source == ImageSource.camera ? 2160 : null,
        maxHeight:    source == ImageSource.camera ? 2160 : null,
      );
      if (img == null) return;
      await _ctrl.insertImage(img.path);
    } catch (e) {
      if (e is ImageLimitException) {
        if (mounted) AppSnackBar.error(context, 'Límite de 5 imágenes por nota');
      } else {
        if (mounted) AppSnackBar.error(context, 'No se pudo obtener la imagen');
      }
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = Theme.of(context).brightness == Brightness.dark
        ? cs.surfaceContainerLowest
        : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _focusedMode ? null : _buildAppBar(cs),
      body: ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) {
          return Stack(
            children: [
              Column(
                children: [
                  Expanded(child: _buildContent(cs)),
                  // Barra inferior: solo cuando teclado visible y no en modo enfocado
                  if (!_focusedMode && _keyboardVisible)
                    FormatToolbar(
                      editorCtrl:  _ctrl,
                      isChecklist: _ctrl.activeBlockIsChecklist,
                      isBold:      _ctrl.isCursorBold,
                      isHighlight: _ctrl.isCursorHighlight,
                      fontSizeMin: _fontSizeMin,
                      fontSizeMax: _fontSizeMax,
                      onImageTap:  _showImageModal,
                      tags:        _tags,
                      onTagRemoved: (tag) {
                        setState(() => _tags.remove(tag));
                        _doAutoSave();
                      },
                    ),
                ],
              ),
              // Botón "Salir del foco"
              if (_focusedMode)
                Positioned(
                  bottom: 24, right: 24,
                  child: GestureDetector(
                    onTap: _toggleFocusedMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.inverseSurface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen_exit_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('Salir del foco',
                              style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(ColorScheme cs) {
    return AppBar(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? cs.surfaceContainerLowest
          : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: cs.onSurface),
      actions: [
        // Indicador de sincronización
        if (_syncState == _SyncState.saving)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onSurface.withValues(alpha: 0.4)),
              ),
            ),
          )
        else if (_syncState == _SyncState.pending)
          IconButton(
            icon: const Icon(Icons.cloud_off_rounded, color: Colors.orange),
            tooltip: 'Sin sincronizar — toca para reintentar',
            onPressed: _doAutoSave,
          ),

        // Compartir
        IconButton(
          icon: Icon(Icons.share_outlined, color: cs.onSurface),
          tooltip: 'Compartir',
          onPressed: _shareNote,
        ),

        // Recordatorio (solo en edición)
        if (widget.notaToEdit?.id != null)
          IconButton(
            icon: Icon(Icons.notifications_none_outlined, color: cs.onSurface),
            tooltip: 'Recordatorio',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AddReminderScreen(notaPreseleccionada: widget.notaToEdit),
              ),
            ),
          ),

        // Modo enfocado
        IconButton(
          icon: Icon(Icons.fullscreen_rounded, color: cs.onSurface),
          tooltip: 'Modo enfocado',
          onPressed: _toggleFocusedMode,
        ),
      ],
    );
  }

  // ── Área de contenido ─────────────────────────────────────────

  Widget _buildContent(ColorScheme cs) {
    final blocks = _ctrl.blocks;

    return SelectionArea(
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: EdgeInsets.fromLTRB(
            22, _focusedMode ? 56 : 18, 22, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Título ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 14),
              child: TextField(
                controller: _ctrl.titleCtrl,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  height: 1.3,
                ),
                decoration: InputDecoration(
                  hintText: 'Título',
                  hintStyle: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 26,
                      fontWeight: FontWeight.w700),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),

            // ── Contador de palabras ──────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 28, left: 14),
              child: ValueListenableBuilder<String>(
                valueListenable: _ctrl.wordCountNotifier,
                builder: (_, value, _) => Text(
                  value,
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                ),
              ),
            ),

            // ── Bloques ───────────────────────────────────────────
            ...blocks.asMap().entries.map((e) {
              final idx   = e.key;
              final block = e.value;

              if (block.isImage) {
                return ImageBlock(
                  key:        ObjectKey(block),
                  editorCtrl: _ctrl,
                  block:      block,
                  index:      idx,
                );
              }

              if (idx == _ctrl.activeIndex) {
                return ActiveTextBlock(
                  editorCtrl: _ctrl,
                  block:      block,
                  index:      idx,
                );
              }

              return InactiveBlock(
                key:          ObjectKey(block),
                block:        block,
                fontSize:     _ctrl.fontSize,
                onActivate:   () => _ctrl.activateBlock(idx),
                onToggleDone: block.isChecklist
                    ? () => _ctrl.toggleChecklistDone(idx)
                    : null,
              );
            }),

            // ── Área tappable vacía al final ──────────────────────
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final last = blocks.last;
                if (!last.isImage && !last.isChecklist) {
                  _ctrl.activateBlock(blocks.length - 1);
                } else {
                  // Insertar bloque de texto al final y activarlo
                  // (el controller lo crea internamente al normalizar)
                  _ctrl.activateBlock(blocks.length - 1);
                }
              },
              child: const SizedBox(width: double.infinity, height: 200),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper modal imagen ───────────────────────────────────────

  Widget _modalOption({
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
              style: TextStyle(
                fontSize: 15,
                color: color != null ? c : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
