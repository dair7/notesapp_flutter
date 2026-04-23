import 'dart:io';

import 'package:flutter/material.dart';

import 'controller/note_editor_controller.dart';
import 'models/note_block.dart';

/// Renderiza un bloque de imagen con barra de acciones inline.
class ImageBlock extends StatefulWidget {
  final NoteEditorController editorCtrl;
  final NoteBlock block;
  final int index;

  const ImageBlock({
    super.key,
    required this.editorCtrl,
    required this.block,
    required this.index,
  });

  @override
  State<ImageBlock> createState() => _ImageBlockState();
}

class _ImageBlockState extends State<ImageBlock> {
  bool _showOverlay = false;
  bool _editComment = false;
  late final TextEditingController _commentCtrl;
  late final FocusNode _commentFocus;

  @override
  void initState() {
    super.initState();
    _commentCtrl  = TextEditingController(text: widget.block.imageComment);
    _commentFocus = FocusNode();
    _commentFocus.addListener(() {
      if (!_commentFocus.hasFocus && _editComment) setState(() => _editComment = false);
    });
  }

  @override
  void didUpdateWidget(ImageBlock old) {
    super.didUpdateWidget(old);
    if (widget.block.imageComment != _commentCtrl.text) _commentCtrl.text = widget.block.imageComment;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _dismissOverlay() => setState(() => _showOverlay = false);

  void _openComment() {
    setState(() { _showOverlay = false; _editComment = true; });
    WidgetsBinding.instance.addPostFrameCallback((_) => _commentFocus.requestFocus());
  }

  void _saveComment(String v) {
    widget.block.imageComment = v;
    widget.editorCtrl.updateImageComment(widget.index, v);
  }

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final block   = widget.block;
    final path    = block.imagePath ?? '';
    final halfW   = (MediaQuery.of(context).size.width - 44) / 2;
    final ancho   = block.imageHalf ? halfW : double.infinity;
    final heroTag = 'img_${block.id}';

    // ── Imagen + comentario guardado ───────────────────────────────────
    final imgContent = GestureDetector(
      onTap: () => setState(() => _showOverlay = !_showOverlay),
      child: Container(
        width: ancho,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _showOverlay ? const Color(0xFFE8B237) : cs.outlineVariant,
            width: _showOverlay ? 2.2 : 1,
          ),
          boxShadow: _showOverlay
              ? [BoxShadow(color: const Color(0xFFE8B237).withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 1)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onDoubleTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _ImageViewer(path: path, heroTag: heroTag))),
                child: Hero(
                  tag: heroTag,
                  child: Image.file(
                    File(path),
                    width: ancho,
                    fit: BoxFit.fitWidth,
                    errorBuilder: (_, _, _) => Container(
                      width: ancho, height: 180,
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant, size: 40),
                    ),
                  ),
                ),
              ),

              // Comentario guardado
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: block.imageComment.isNotEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          color:  cs.primary.withValues(alpha: 0.08),
                          border: Border(top: BorderSide(color: cs.primary.withValues(alpha: 0.2), width: 1)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes_rounded, size: 15, color: cs.primary.withValues(alpha: 0.7)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(block.imageComment,
                                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4))),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );

    // ── Layout: half o completo ────────────────────────────────────────
    Widget body;
    if (block.imageHalf) {
      final idxNext = widget.index + 1;
      body = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            imgContent,
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (idxNext < widget.editorCtrl.blocks.length &&
                      !widget.editorCtrl.blocks[idxNext].isImage) {
                    widget.editorCtrl.activateBlock(idxNext);
                  }
                },
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      );
    } else {
      body = imgContent;
    }

    // ── Barra de acciones como overlay en el Stack exterior ────────────
    // Está FUERA del widget de imagen para no estar limitada por su ancho.
    // Positioned.fill + Center la centra sobre toda el área del widget.
    final contentColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 16), child: body),
        if (_editComment)
          _CommentBar(
            ctrl:    _commentCtrl,
            focus:   _commentFocus,
            onSave:  _saveComment,
            onClose: () { _commentFocus.unfocus(); setState(() => _editComment = false); },
          ),
      ],
    );

    if (!_showOverlay) return contentColumn;

    return Stack(
      children: [
        contentColumn,
        Positioned.fill(
          child: GestureDetector(
            onTap: _dismissOverlay,
            behavior: HitTestBehavior.translucent,
            child: Center(
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: cs.surfaceContainerLowest.withValues(alpha: 0.18),
                    blurRadius: 12, offset: const Offset(0, 4),
                  )],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _icon(Icons.comment_outlined, _openComment, cs.onSurface),
                    _icon(Icons.draw_outlined,    null,         cs.onSurface.withValues(alpha: 0.3)),
                    _icon(
                      block.imageHalf ? Icons.fullscreen_rounded : Icons.photo_size_select_large_outlined,
                      () { _dismissOverlay(); widget.editorCtrl.toggleImageHalf(widget.index); },
                      cs.onSurface,
                    ),
                    _icon(Icons.delete_outline_rounded, () {
                      _dismissOverlay();
                      widget.editorCtrl.deleteImage(widget.index);
                    }, cs.error),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }



  Widget _icon(IconData icon, VoidCallback? onTap, Color color) =>
      GestureDetector(onTap: onTap, child: SizedBox(width: 62, height: 54, child: Icon(icon, color: color, size: 25)));
}

class _CommentBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final ValueChanged<String> onSave;
  final VoidCallback onClose;
  const _CommentBar({required this.ctrl, required this.focus, required this.onSave, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: cs.surface, border: Border(top: BorderSide(color: cs.outlineVariant, width: 1))),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
      child: Row(
        children: [
          Icon(Icons.notes_rounded, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl, focusNode: focus, onChanged: onSave,
              style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.4),
              decoration: InputDecoration(
                hintText: 'Escribe un comentario...',
                hintStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onClose,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: cs.primary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Listo', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final String path;
  final String heroTag;
  const _ImageViewer({required this.path, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 0.5, maxScale: 5.0,
                child: Image.file(File(path), fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64)),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(12), width: 38, height: 38,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
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
