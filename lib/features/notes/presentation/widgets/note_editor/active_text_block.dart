import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller/note_editor_controller.dart';
import 'models/note_block.dart';

/// Renderiza el bloque actualmente en edición como un [TextField].
///
/// La [activeFieldKey] (GlobalKey) garantiza que Flutter preserve la
/// conexión IME aunque el bloque cambie de posición en la lista tras
/// una fusión (backspace en posición 0).
class ActiveTextBlock extends StatelessWidget {
  final NoteEditorController editorCtrl;
  final NoteBlock block;
  final int index;

  const ActiveTextBlock({
    super.key,
    required this.editorCtrl,
    required this.block,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: block.isChecklist ? 15 : 13),
      child: Row(
        crossAxisAlignment: block.isChecklist
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),

          // ── Checkbox (solo para checklist) ────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width:  block.isChecklist ? 30.0 : 6.05,
            height: 30,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: block.isChecklist
                ? GestureDetector(
                    behavior: HitTestBehavior.deferToChild,
                    onTap: () => editorCtrl.toggleChecklistDone(editorCtrl.activeIndex),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: block.isDone ? cs.primary : Colors.transparent,
                          border: Border.all(
                            color: block.isDone
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.35),
                            width: 1.6,
                          ),
                        ),
                        child: block.isDone
                            ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                            : null,
                      ),
                    ),
                  )
                : null,
          ),

          // ── TextField activo ──────────────────────────────────────
          Expanded(
            child: TextField(
              key: editorCtrl.activeFieldKey,
              controller: editorCtrl.activeCtrl,
              focusNode: editorCtrl.activeFocus
                ..onKeyEvent = (_, event) => _handleKeyEvent(event),
              onChanged: editorCtrl.onActiveTextChanged,
              style: TextStyle(
                fontSize: editorCtrl.fontSize,
                fontWeight: FontWeight.normal,
                decoration: block.isDone
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                decorationColor: cs.onSurfaceVariant,
                color: block.isDone
                    ? cs.onSurface.withValues(alpha: 0.38)
                    : cs.onSurface,
                height: 2.2,
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              enableInteractiveSelection: true,
              decoration: InputDecoration(
                hintText: index == 0 ? 'Empieza a escribir...' : null,
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

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace)   return KeyEventResult.ignored;
    final sel = editorCtrl.activeCtrl.selection;
    if (!sel.isCollapsed || sel.baseOffset != 0)            return KeyEventResult.ignored;
    editorCtrl.handleBackspaceAtStart();
    return KeyEventResult.handled;
  }
}
