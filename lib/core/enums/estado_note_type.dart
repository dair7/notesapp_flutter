// ignore_for_file: constant_identifier_names
enum EstadoNoteType {
  ACTIVA,
  ARCHIVADA,
  ELIMINADA;

  // Ayuda a convertir el String que llega de Spring Boot al Enum de Dart
  static EstadoNoteType fromString(String status) {
    return EstadoNoteType.values.firstWhere(
      (e) => e.name == status.toUpperCase(),
      orElse: () => EstadoNoteType.ACTIVA,
    );
  }
}
