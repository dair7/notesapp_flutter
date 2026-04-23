// ignore_for_file: constant_identifier_names
enum RoleType {
  USER,
  ADMIN,
  SUPER_ADMIN;

  static RoleType fromString(String role) {
    return RoleType.values.firstWhere(
      (e) => e.name == role.toUpperCase(),
      orElse: () => RoleType.USER,
    );
  }
}