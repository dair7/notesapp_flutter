import 'package:flutter/material.dart';

import 'controller/note_editor_controller.dart';

/// Barra de herramientas de formato. Usa [Listener.onPointerDown] para
/// re-enfocar el campo activo antes de que Flutter transfiera el foco,
/// evitando que el teclado se cierre al tocar cualquier botón.
class FormatToolbar extends StatelessWidget {
  final NoteEditorController editorCtrl;
  final bool isChecklist;
  final bool isBold;
  final bool isHighlight;
  final double fontSizeMin;
  final double fontSizeMax;
  final VoidCallback onImageTap;
  final List<String> tags;
  final ValueChanged<String> onTagRemoved;

  const FormatToolbar({
    super.key,
    required this.editorCtrl,
    required this.isChecklist,
    required this.isBold,
    required this.isHighlight,
    required this.onImageTap,
    this.fontSizeMin = 12.0,
    this.fontSizeMax = 32.0,
    this.tags        = const [],
    required this.onTagRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Listener(
      onPointerDown: (_) => editorCtrl.activeFocus.requestFocus(),
      child: Container(
        decoration: BoxDecoration(
          color:  cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tags.isNotEmpty) ...[
              _TagChips(tags: tags, onRemoved: onTagRemoved),
              const SizedBox(height: 6),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BoldBtn(active: isBold, onTap: editorCtrl.toggleBold),
                _HighlightBtn(active: isHighlight, onTap: editorCtrl.toggleHighlight),
                _divider(cs),
                _FontSizeBtn(sign: '+', onTap: () => editorCtrl.setFontSize((editorCtrl.fontSize + 2).clamp(fontSizeMin, fontSizeMax))),
                _FontSizeBtn(sign: '-', onTap: () => editorCtrl.setFontSize((editorCtrl.fontSize - 2).clamp(fontSizeMin, fontSizeMax))),
                _divider(cs),
                _ToolbarBtn(icon: Icons.check_box_outlined, active: isChecklist, onTap: editorCtrl.toggleChecklistAtCursor),
                _divider(cs),
                _ToolbarBtn(icon: Icons.image_outlined,    onTap: onImageTap),
                _ToolbarBtn(icon: Icons.gesture_rounded,   onTap: null),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(ColorScheme cs) =>
      Container(width: 1, height: 22, color: cs.outlineVariant);
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  const _ToolbarBtn({required this.icon, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36, height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? cs.primary.withValues(alpha: 0.13) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 22,
          color: active ? cs.primary : onTap == null ? cs.onSurface.withValues(alpha: 0.2) : cs.onSurfaceVariant),
      ),
    );
  }
}

class _BoldBtn extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _BoldBtn({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36, height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? cs.primary.withValues(alpha: 0.13) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('B', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
            color: active ? cs.primary : cs.onSurfaceVariant)),
      ),
    );
  }
}

class _HighlightBtn extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _HighlightBtn({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36, height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? cs.primary.withValues(alpha: 0.13) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(bottom: 7, child: Container(width: 18, height: 7,
              color: active ? Colors.yellow.withValues(alpha: 0.7) : cs.onSurface.withValues(alpha: 0.2))),
            Text('A', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                color: active ? cs.onSurface : cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _FontSizeBtn extends StatelessWidget {
  final String sign;
  final VoidCallback onTap;
  const _FontSizeBtn({required this.sign, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36, height: 36,
        child: Center(
          child: RichText(text: TextSpan(children: [
            TextSpan(text: 'A', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            WidgetSpan(
              baseline: TextBaseline.alphabetic, alignment: PlaceholderAlignment.top,
              child: Text(sign, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
            ),
          ])),
        ),
      ),
    );
  }
}

class _TagChips extends StatelessWidget {
  final List<String> tags;
  final ValueChanged<String> onRemoved;
  const _TagChips({required this.tags, required this.onRemoved});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6, runSpacing: 4,
      children: tags.map((tag) => Chip(
        label: Text(tag, style: TextStyle(fontSize: 12, color: cs.onSurface)),
        deleteIcon: const Icon(Icons.close_rounded, size: 14),
        onDeleted: () => onRemoved(tag),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: cs.onSurface.withValues(alpha: 0.06),
        side: BorderSide(color: cs.outlineVariant),
      )).toList(),
    );
  }
}
