import 'dart:math';

/// Tipo de bloque de contenido en el editor de notas
enum NoteBlockType { text, checklist, image }

/// Rango de formato (negrita o resaltado) sobre el texto plano del bloque.
/// Clase pura Dart — sin dependencias de Flutter.
class FormatRange {
  final int start;
  final int end;

  const FormatRange(this.start, this.end);

  /// Devuelve un nuevo rango desplazado por [offset] posiciones.
  FormatRange shift(int offset) => FormatRange(start + offset, end + offset);

  @override
  bool operator ==(Object other) =>
      other is FormatRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'FormatRange($start, $end)';
}

/// Modelo de un bloque de contenido del editor de notas.
///
/// Es completamente puro: no depende de Flutter UI.
/// Los [RichTextController] y [FocusNode] viven en [NoteEditorController],
/// nunca aquí. Este modelo almacena exclusivamente los datos persistibles.
///
/// Los campos [boldRanges] e [highlightRanges] se sincronizan desde el
/// controlador activo cada vez que el bloque pierde el foco de edición
/// (_flushActiveBlock en el controller). Mientras el bloque es el activo,
/// la fuente de verdad de los rangos está en el [RichTextController].
class NoteBlock {
  /// Identificador único inmutable.
  /// Se usa como [ObjectKey] en Flutter para preservar la identidad
  /// del widget en el árbol y como clave en Maps del controller.
  final String id;

  /// Tipo de bloque.
  final NoteBlockType type;

  /// Texto plano sin marcadores de formato.
  /// Solo relevante para [NoteBlockType.text] y [NoteBlockType.checklist].
  /// Actualizado por el controller al hacer flush del bloque activo.
  String rawText;

  /// Rangos de negrita almacenados cuando el bloque no está activo.
  /// Fuente de verdad para renderizar [SelectableText] en modo lectura.
  List<FormatRange> boldRanges;

  /// Rangos de resaltado almacenados cuando el bloque no está activo.
  List<FormatRange> highlightRanges;

  /// Solo para [NoteBlockType.checklist]: si el ítem está marcado como hecho.
  bool isDone;

  /// Solo para [NoteBlockType.image]: ruta absoluta en el filesystem local.
  String? imagePath;

  /// Solo para [NoteBlockType.image]:
  /// false = ancho completo, true = mitad izquierda.
  bool imageHalf;

  /// Solo para [NoteBlockType.image]: texto del comentario asociado a la imagen.
  String imageComment;

  NoteBlock._({
    required this.id,
    required this.type,
    this.rawText = '',
    List<FormatRange>? boldRanges,
    List<FormatRange>? highlightRanges,
    this.isDone = false,
    this.imagePath,
    this.imageHalf = false,
    this.imageComment = '',
  })  : boldRanges = boldRanges ?? [],
        highlightRanges = highlightRanges ?? [];

  // ── Constructores de fábrica ──────────────────────────────────

  /// Bloque de texto vacío. Punto de partida para una nota nueva.
  factory NoteBlock.emptyText() => NoteBlock._(
        id: _generateId(),
        type: NoteBlockType.text,
      );

  /// Bloque de texto con contenido (usado por el serializador al parsear).
  factory NoteBlock.text(
    String rawText, {
    List<FormatRange>? boldRanges,
    List<FormatRange>? highlightRanges,
  }) =>
      NoteBlock._(
        id: _generateId(),
        type: NoteBlockType.text,
        rawText: rawText,
        boldRanges: boldRanges,
        highlightRanges: highlightRanges,
      );

  /// Bloque de ítem checklist.
  factory NoteBlock.checklist(String rawText, {bool isDone = false}) =>
      NoteBlock._(
        id: _generateId(),
        type: NoteBlockType.checklist,
        rawText: rawText,
        isDone: isDone,
      );

  /// Bloque de imagen inline.
  factory NoteBlock.image({
    required String imagePath,
    bool imageHalf = false,
    String imageComment = '',
  }) =>
      NoteBlock._(
        id: _generateId(),
        type: NoteBlockType.image,
        imagePath: imagePath,
        imageHalf: imageHalf,
        imageComment: imageComment,
      );

  // ── Queries de conveniencia ───────────────────────────────────

  bool get isText      => type == NoteBlockType.text;
  bool get isChecklist => type == NoteBlockType.checklist;
  bool get isImage     => type == NoteBlockType.image;

  /// true si el bloque no tiene contenido textual ni ruta de imagen.
  bool get isEmpty => !isImage && rawText.isEmpty;

  // ── Generador de IDs locales únicos ──────────────────────────

  static final Random _rng = Random();

  /// Genera un ID único combinando microsegundos y un número aleatorio.
  /// No requiere el paquete uuid — suficientemente único para IDs locales.
  static String _generateId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(999999)}';
}
