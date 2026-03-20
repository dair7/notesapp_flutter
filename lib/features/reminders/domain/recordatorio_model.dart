class Recordatorio {
  final int? id;
  final DateTime fecha;
  final bool completado;
  final int? notaId;
  final String? notaTitulo;

  Recordatorio({
    this.id,
    required this.fecha,
    this.completado = false,
    this.notaId,
    this.notaTitulo,
  });

  // De Spring Boot (JSON) -> a Flutter (Objeto)
  factory Recordatorio.fromJson(Map<String, dynamic> json) {
    return Recordatorio(
      id: json['id'],
      fecha: DateTime.parse(json['fecha']),
      completado: json['completado'] ?? false,
      notaId: json['notaId'],
      notaTitulo: json['notaTitulo'],
    );
  }

  // De Flutter (Objeto) -> a Spring Boot (JSON)
  Map<String, dynamic> toJson() {
    return {
      'fecha': fecha.toIso8601String(),
    };
  }
}