class Categoria {
  final int id;
  final String nombre;
  final String? colorHex;
  final DateTime? fechaCreacion;

  Categoria({
    required this.id,
    required this.nombre,
    this.colorHex,
    this.fechaCreacion,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['id'],
      nombre: json['nombre'],
      colorHex: json['colorHex'],
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'colorHex': colorHex,
    };
  }

  Categoria copyWith({
    int? id,
    String? nombre,
    String? colorHex,
    DateTime? fechaCreacion,
  }) {
    return Categoria(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      colorHex: colorHex ?? this.colorHex,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }
}
