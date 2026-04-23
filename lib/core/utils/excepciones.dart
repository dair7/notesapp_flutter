/// Excepción lanzada cuando falla la conexión a internet.
/// El [ApiClient] ya muestra el toast global antes de lanzarla,
/// por lo que las pantallas no deben mostrar otro mensaje.
class SinConexionException implements Exception {
  const SinConexionException();
}
