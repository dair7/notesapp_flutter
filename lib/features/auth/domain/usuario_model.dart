import '../../../core/enums/role_type.dart';

class Usuario {
  final int? id;
  final String nombre;
  final String email;
  final String? password; // Solo se usa para enviar al backend al registrarse
  final RoleType role;
  final String estadoUsuario; // ACTIVO | INACTIVO
  final DateTime? createdAt;

  Usuario({
    this.id,
    required this.nombre,
    required this.email,
    this.password,
    this.role = RoleType.USER,
    this.estadoUsuario = 'ACTIVO',
    this.createdAt,
  });

  bool get isActivo => estadoUsuario == 'ACTIVO';

  // De Spring Boot (JSON) -> a Flutter (Objeto)
  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'],
      nombre: json['nombre'],
      email: json['email'],
      role: RoleType.fromString(json['role'] ?? 'USER'),
      estadoUsuario: json['estadoUsuario'] ?? 'ACTIVO',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  // De Flutter (Objeto) -> a Spring Boot (JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      if (password != null) 'password': password,
      'role': role.name,
      'estadoUsuario': estadoUsuario,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}