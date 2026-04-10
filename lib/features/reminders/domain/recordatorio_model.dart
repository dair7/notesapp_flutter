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
      fecha: DateTime.parse(json['fecha']),
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
