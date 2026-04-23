// ignore_for_file: constant_identifier_names
enum Prioridad { ALTA, MEDIA, BAJA }

class Recordatorio {
  final int? id;
  final DateTime fecha;
  final bool completado;
  final int? notaId;
  final String? notaTitulo;
  final Prioridad prioridad;

  Recordatorio({
    this.id,
    required this.fecha,
    this.completado = false,
    this.notaId,
    this.notaTitulo,
    this.prioridad = Prioridad.MEDIA,
  });

  factory Recordatorio.fromJson(Map<String, dynamic> json) {
    return Recordatorio(
      id: json['id'],
      // El servidor devuelve LocalDateTime en UTC (sin sufijo Z); se añade para parsear correctamente
      fecha: DateTime.parse('${json['fecha']}Z').toLocal(),
      completado: json['completado'] ?? false,
      notaId: json['notaId'],
      notaTitulo: json['notaTitulo'],
      prioridad: _parsePrioridad(json['prioridad']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fecha': fecha.toIso8601String(),
      'prioridad': prioridad.name,
    };
  }

  static Prioridad _parsePrioridad(String? valor) {
    switch (valor) {
      case 'ALTA': return Prioridad.ALTA;
      case 'BAJA': return Prioridad.BAJA;
      default:     return Prioridad.MEDIA;
    }
  }
}
