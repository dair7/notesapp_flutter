import '../../../core/enums/estado_note_type.dart';

class Nota {
  final int? id;
  final String titulo;
  final String contenido;
  final DateTime? fechaCreacion;
  final EstadoNoteType estado;
  final int? usuarioId;
  final String? usuarioNombre;
  final bool esAnclada;
  // Color de fondo en formato hex (ej: "#FFE5B4"), null = sin color
  final String? color;
  // Etiquetas de la nota
  final List<String> etiquetas;

  Nota({
    this.id,
    required this.titulo,
    this.contenido = '',
    this.fechaCreacion,
    this.estado = EstadoNoteType.ACTIVA,
    this.usuarioId,
    this.usuarioNombre,
    this.esAnclada = false,
    this.color,
    this.etiquetas = const [],
  });

  // De Spring Boot (JSON) -> a Flutter (Objeto)
  factory Nota.fromJson(Map<String, dynamic> json) {
    return Nota(
      id: json['id'],
      titulo: json['titulo'],
      contenido: json['contenido'] ?? '',
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : null,
      estado: EstadoNoteType.fromString(json['estado'] ?? 'ACTIVA'),
      usuarioId: json['usuarioId'],
      usuarioNombre: json['usuarioNombre'],
      esAnclada: json['esAnclada'] ?? false,
      color: json['color'],
      // Las etiquetas se almacenan como string separado por comas en el backend
      etiquetas: _parsearEtiquetas(json['etiquetas']),
    );
  }

  // De Flutter (Objeto) -> a Spring Boot (JSON)
  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'contenido': contenido,
      'color': color,
      // Serializar la lista como string separado por comas
      'etiquetas': etiquetas.isEmpty ? null : etiquetas.join(','),
    };
  }

  // Convierte el string "tag1,tag2" del backend a List<String>
  static List<String> _parsearEtiquetas(dynamic valor) {
    if (valor == null || valor.toString().isEmpty) return [];
    return valor.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}
