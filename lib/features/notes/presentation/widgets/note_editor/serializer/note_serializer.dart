import '../models/note_block.dart';

/// Serializa y deserializa la lista de [NoteBlock] hacia/desde el formato
/// de texto plano que se almacena en la base de datos.
///
/// ─── Formato en disco ────────────────────────────────────────────────
///
/// Primera línea (obligatoria):
///   [fmt:b=0,r=0,fs=16]
///
/// Resto del contenido, una línea por bloque:
///   - Texto normal (puede contener marcadores inline `**negrita**` y `==resaltado==`)
///   - Checklist sin completar:  `[ ] texto con **formato**`
///   - Checklist completado:     `[x] texto`
///   - Imagen completa:          `[img:full:/ruta/absoluta]`
///   - Imagen mitad + comentario:`[img:half:/ruta|comentario con ⏎ para saltos]`
///
/// Líneas de texto regulares consecutivas se fusionan en un único [NoteBlock]
/// (cada una separada por `\n` dentro del `rawText`), replicando el
/// comportamiento del editor original donde el Enter es nativo del TextField.
///
/// ─── Formato legado ──────────────────────────────────────────────────
///
/// Las notas antiguas pueden contener `\n---imgs---\n` seguido de rutas
/// de imagen planas. El parser migra esas rutas a bloques `[img:full:…]`
/// al final. Esta migración es solo en `parse()` — `serialize()` siempre
/// emite el formato moderno.
///
class NoteSerializer {
  NoteSerializer._(); // Clase de utilidad: solo métodos estáticos

  // ── Constantes de formato ─────────────────────────────────────────

  static const _imgSep     = '\n---imgs---\n';
  static const _fmtPrefix  = '[fmt:';
  static const _imgPrefix  = '[img:';
  static const _checkUndone = '[ ] ';
  static const _checkDone   = '[x] ';

  // ── API pública ───────────────────────────────────────────────────

  /// Extrae el tamaño de fuente del encabezado `[fmt:…]`.
  /// Devuelve [defaultSize] si no hay encabezado o no contiene `fs=`.
  static double extractFontSize(String raw, {double defaultSize = 16.0}) {
    if (!raw.startsWith(_fmtPrefix)) return defaultSize;
    final end = raw.indexOf(']');
    if (end < 0) return defaultSize;
    for (final part in raw.substring(_fmtPrefix.length, end).split(',')) {
      final kv = part.split('=');
      if (kv.length == 2 && kv[0] == 'fs') {
        return double.tryParse(kv[1]) ?? defaultSize;
      }
    }
    return defaultSize;
  }

  /// Parsea [raw] (contenido completo de la nota, con encabezado `[fmt:]`)
  /// y devuelve la lista de [NoteBlock] correspondiente.
  ///
  /// Nunca devuelve lista vacía: si no hay contenido útil, retorna un bloque
  /// de texto vacío para que el editor tenga siempre algo donde editar.
  static List<NoteBlock> parse(String raw) {
    if (raw.isEmpty) return [NoteBlock.emptyText()];

    // Extraer la parte de contenido (sin encabezado, sin sección legada)
    final content   = _extractContent(raw);
    final legacyImgs = _extractLegacyImages(raw);

    if (content.isEmpty && legacyImgs.isEmpty) return [NoteBlock.emptyText()];

    final lines  = content.split('\n');
    final blocks = <NoteBlock>[];
    final buffer = <String>[]; // Líneas de texto plano acumuladas

    // Fusiona el buffer en un único NoteBlock.text con rangos de formato
    void flushBuffer() {
      if (buffer.isEmpty) return;
      final joined = buffer.join('\n');
      final parsed = _parseInlineFormat(joined);
      blocks.add(NoteBlock.text(
        parsed.plainText,
        boldRanges:      parsed.boldRanges,
        highlightRanges: parsed.highlightRanges,
      ));
      buffer.clear();
    }

    for (final line in lines) {
      if (line.startsWith(_imgPrefix)) {
        // ── Bloque de imagen ────────────────────────────────────────
        flushBuffer();
        final block = _parseImageLine(line);
        if (block != null) blocks.add(block);

      } else if (line.startsWith(_checkUndone)) {
        // ── Checklist sin completar ─────────────────────────────────
        flushBuffer();
        final parsed = _parseInlineFormat(line.substring(_checkUndone.length));
        blocks.add(NoteBlock.checklist(parsed.plainText, isDone: false));

      } else if (line.startsWith(_checkDone)) {
        // ── Checklist completado ────────────────────────────────────
        flushBuffer();
        final parsed = _parseInlineFormat(line.substring(_checkDone.length));
        blocks.add(NoteBlock.checklist(parsed.plainText, isDone: true));

      } else if (line == '---imgs---') {
        // ── Separador legado — ignorar ───────────────────────────────
        flushBuffer();

      } else {
        // ── Texto normal: acumular en buffer ─────────────────────────
        buffer.add(line);
      }
    }
    flushBuffer();

    // Migración de imágenes legadas al final
    for (final path in legacyImgs) {
      blocks.add(NoteBlock.image(imagePath: path));
    }

    return blocks.isEmpty ? [NoteBlock.emptyText()] : blocks;
  }

  /// Serializa [blocks] a una cadena lista para guardar en BD.
  ///
  /// El encabezado siempre incluye `fs=<fontSize>`.
  static String serialize(List<NoteBlock> blocks, double fontSize) {
    final meta    = '[fmt:b=0,r=0,fs=${fontSize.toInt()}]';
    final content = _buildContent(blocks);
    return '$meta\n$content';
  }

  // ── Helpers privados: extracción ──────────────────────────────────

  static String _extractContent(String raw) {
    String body = raw;
    if (body.startsWith(_fmtPrefix)) {
      final nl = body.indexOf('\n');
      if (nl < 0) return '';
      body = body.substring(nl + 1);
    }
    final sepIdx = body.indexOf(_imgSep);
    if (sepIdx >= 0) body = body.substring(0, sepIdx);
    return body;
  }

  static List<String> _extractLegacyImages(String raw) {
    final sepIdx = raw.indexOf(_imgSep);
    if (sepIdx < 0) return [];
    return raw
        .substring(sepIdx + _imgSep.length)
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
  }

  // ── Helpers privados: parseo ──────────────────────────────────────

  static NoteBlock? _parseImageLine(String line) {
    final inner = line.substring(_imgPrefix.length,
        line.endsWith(']') ? line.length - 1 : line.length);
    final colonIdx = inner.indexOf(':');
    if (colonIdx < 0) return null;
    final size  = inner.substring(0, colonIdx);
    final rest  = inner.substring(colonIdx + 1);
    final pipeIdx = rest.indexOf('|');
    final path  = pipeIdx >= 0 ? rest.substring(0, pipeIdx) : rest;
    final comment = pipeIdx >= 0
        ? rest.substring(pipeIdx + 1).replaceAll('⏎', '\n')
        : '';
    return NoteBlock.image(
      imagePath:    path,
      imageHalf:    size == 'half',
      imageComment: comment,
    );
  }

  static _ParsedText _parseInlineFormat(String text) {
    if (!text.contains('**') && !text.contains('==')) {
      return _ParsedText(plainText: text);
    }
    final buf             = StringBuffer();
    final boldRanges      = <FormatRange>[];
    final highlightRanges = <FormatRange>[];
    int i = 0, realPos = 0;
    bool inBold = false, inHigh = false;
    int boldStart = 0, highStart = 0;

    while (i < text.length) {
      if (i + 1 < text.length && text[i] == '*' && text[i + 1] == '*') {
        i += 2;
        if (!inBold) { boldStart = realPos; inBold = true; }
        else { if (realPos > boldStart) boldRanges.add(FormatRange(boldStart, realPos)); inBold = false; }
      } else if (i + 1 < text.length && text[i] == '=' && text[i + 1] == '=') {
        i += 2;
        if (!inHigh) { highStart = realPos; inHigh = true; }
        else { if (realPos > highStart) highlightRanges.add(FormatRange(highStart, realPos)); inHigh = false; }
      } else {
        buf.write(text[i++]);
        realPos++;
      }
    }
    return _ParsedText(plainText: buf.toString(), boldRanges: boldRanges, highlightRanges: highlightRanges);
  }

  // ── Helpers privados: serialización ──────────────────────────────

  static String _buildContent(List<NoteBlock> blocks) =>
      blocks.map(_serializeBlock).join('\n');

  static String _serializeBlock(NoteBlock block) {
    if (block.isImage) {
      final comment = block.imageComment.replaceAll('\n', '⏎');
      final extra   = comment.isNotEmpty ? '|$comment' : '';
      return '[img:${block.imageHalf ? 'half' : 'full'}:${block.imagePath}$extra]';
    }
    final formattedText = _buildInlineFormat(block.rawText, block.boldRanges, block.highlightRanges);
    if (block.isChecklist) return '${block.isDone ? '[x]' : '[ ]'} $formattedText';
    return formattedText;
  }

  static String _buildInlineFormat(String plainText, List<FormatRange> boldRanges, List<FormatRange> highlightRanges) {
    if (boldRanges.isEmpty && highlightRanges.isEmpty) return plainText;
    final Set<int> cuts = {0, plainText.length};
    for (final r in boldRanges)      { cuts.add(r.start.clamp(0, plainText.length)); cuts.add(r.end.clamp(0, plainText.length)); }
    for (final r in highlightRanges) { cuts.add(r.start.clamp(0, plainText.length)); cuts.add(r.end.clamp(0, plainText.length)); }
    final points = cuts.toList()..sort();
    final buf = StringBuffer();
    bool boldOpen = false, highOpen = false;
    bool posInList(List<FormatRange> list, int pos) => list.any((r) => r.start <= pos && pos < r.end);
    for (int i = 0; i < points.length - 1; i++) {
      final s = points[i], e = points[i + 1];
      if (s >= e) continue;
      final isBold = posInList(boldRanges, s);
      final isHigh = posInList(highlightRanges, s);
      if (highOpen && !isHigh) { buf.write('=='); highOpen = false; }
      if (boldOpen && !isBold) { buf.write('**'); boldOpen = false; }
      if (isBold && !boldOpen) { buf.write('**'); boldOpen = true; }
      if (isHigh && !highOpen) { buf.write('=='); highOpen = true; }
      buf.write(plainText.substring(s, e));
    }
    if (boldOpen) buf.write('**');
    if (highOpen) buf.write('==');
    return buf.toString();
  }
}

class _ParsedText {
  final String plainText;
  final List<FormatRange> boldRanges;
  final List<FormatRange> highlightRanges;
  const _ParsedText({required this.plainText, this.boldRanges = const [], this.highlightRanges = const []});
}
