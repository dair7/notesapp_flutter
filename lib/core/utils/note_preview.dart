/// Limpia el contenido de una nota para mostrarlo como preview en cards.
///
/// Remueve:
/// - Encabezado de formato `[fmt:b=0,r=0,fs=16]` de la primera línea
/// - Marcadores de checklist `[ ] ` y `[x] ` (los completados llevan ✓)
/// - Bloques de imagen `[img:full:/ruta]` o `[img:half:/ruta|comentario]`
/// - Marcadores inline de negrita `**...**` y resaltado `==...==`
String previewContenidoNota(String contenido) {
  String texto = contenido;

  // Quitar línea de metadatos [fmt:...]
  if (texto.startsWith('[fmt:')) {
    final nl = texto.indexOf('\n');
    texto = nl >= 0 ? texto.substring(nl + 1) : '';
  }

  // Procesar línea por línea: eliminar marcadores de checklist e imágenes
  final lineas = texto.split('\n').map((l) {
    if (l.startsWith('[img:')) return ''; // omitir bloque de imagen
    if (l.startsWith('[ ] ')) return l.substring(4);
    if (l.startsWith('[x] ')) return '✓ ${l.substring(4)}';
    if (l == '---imgs---')    return ''; // separador legado
    return l;
  }).where((l) => l.isNotEmpty).join(' ');

  // Quitar marcadores inline de formato (negrita y resaltado)
  return lineas.replaceAll('**', '').replaceAll('==', '').trim();
}
