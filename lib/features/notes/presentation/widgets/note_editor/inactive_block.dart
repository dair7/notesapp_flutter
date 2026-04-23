import 'package:flutter/material.dart';

import 'models/note_block.dart';

/// Renderiza un bloque inactivo (texto o checklist) como [SelectableText].
/// Al tocar, llama [onActivate] para activarlo sin cerrar el teclado.
class InactiveBlock extends StatelessWidget {
  final NoteBlock block;
  final double fontSize;
  final VoidCallback onActivate;
  final VoidCallback? onToggleDone;

  const InactiveBlock({
    super.key,
    required this.block,
    required this.fontSize,
    required this.onActivate,
    this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onActivate,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(bottom: block.isChecklist ? 15 : 13),
        child: Row(
          crossAxisAlignment: block.isChecklist
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 8),

            // ── Checkbox ──────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width:  block.isChecklist ? 30.0 : 6.05,
              height: 30,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: block.isChecklist
                  ? GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onTap: onToggleDone,
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

            // ── SelectableText con formato ────────────────────────────
            Expanded(
              child: SelectableText.rich(
                _buildTextSpan(cs),
                style: TextStyle(
                  fontSize:        fontSize,
                  height:          2.2,
                  decoration:      block.isDone ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: cs.onSurfaceVariant,
                  color: block.isDone
                      ? cs.onSurface.withValues(alpha: 0.38)
                      : cs.onSurface,
                ),
                onTap: onActivate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _buildTextSpan(ColorScheme cs) {
    final text      = block.rawText;
    final bold      = block.boldRanges;
    final highlight = block.highlightRanges;

    final baseStyle = TextStyle(
      fontSize: fontSize,
      height:   2.2,
      color: block.isDone ? cs.onSurface.withValues(alpha: 0.38) : cs.onSurface,
    );

    if (bold.isEmpty && highlight.isEmpty) return TextSpan(text: text, style: baseStyle);

    final Set<int> cutSet = {0, text.length};
    for (final r in bold)      { cutSet.add(r.start.clamp(0, text.length)); cutSet.add(r.end.clamp(0, text.length)); }
    for (final r in highlight) { cutSet.add(r.start.clamp(0, text.length)); cutSet.add(r.end.clamp(0, text.length)); }
    final points = cutSet.toList()..sort();

    bool posIn(List<FormatRange> list, int pos) => list.any((r) => r.start <= pos && pos < r.end);

    final spans = <TextSpan>[];
    for (int i = 0; i < points.length - 1; i++) {
      final s = points[i], e = points[i + 1];
      if (s >= e) continue;
      spans.add(TextSpan(
        text: text.substring(s, e),
        style: baseStyle.copyWith(
          fontWeight:      posIn(bold, s)      ? FontWeight.bold : FontWeight.normal,
          backgroundColor: posIn(highlight, s) ? const Color(0xFFFFEB3B).withValues(alpha: 0.7) : null,
          decoration:      block.isDone        ? TextDecoration.lineThrough : null,
        ),
      ));
    }
    return TextSpan(style: baseStyle, children: spans);
  }
}
