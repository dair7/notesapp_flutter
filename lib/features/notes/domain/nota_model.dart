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

  Nota({
    this.id,
    required this.titulo,
    this.contenido = '',
    this.fechaCreacion,
    this.estado = EstadoNoteType.ACTIVA,
    this.usuarioId,
    this.usuarioNombre,
    this.esAnclada = false,
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
    );
  }

  // De Flutter (Objeto) -> a Spring Boot (JSON)
  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'contenido': contenido,
    };
  }
}