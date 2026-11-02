// El motivo de un precio cambiado a mano (o de un cambio de plato) viaja dentro
// del comentario del producto, en su propia línea. La línea lleva una marca
// invisible al inicio para reconocerla sin escribir ninguna etiqueta: lo único
// que se ve es el motivo. Los pedidos antiguos usaban "Precio manual: ".
const marcaMotivoPrecio = '⁣';
const _marcaAntigua = 'Precio manual: ';

// La línea del comentario para un motivo.
String lineaDeMotivoPrecio(String motivo) => '$marcaMotivoPrecio$motivo';

String? _motivoDeLinea(String linea) {
  if (linea.startsWith(marcaMotivoPrecio)) {
    return linea.substring(marcaMotivoPrecio.length).trim();
  }
  if (linea.startsWith(_marcaAntigua)) {
    return linea.substring(_marcaAntigua.length).trim();
  }
  return null;
}

// Motivo del precio dentro de un comentario, si lo tiene.
String? motivoDePrecio(String? comentario) {
  final motivos = [
    for (final x in (comentario ?? '').split('\n'))
      if (_motivoDeLinea(x) case final m? when m.isNotEmpty) m,
  ];
  return motivos.isEmpty ? null : motivos.join(' ');
}

// El comentario sin la línea del motivo (la nota que escribió el mozo).
String notaSinMotivoDePrecio(String? comentario) => [
  for (final x in (comentario ?? '').split('\n'))
    if (_motivoDeLinea(x) == null) x,
].join('\n').trim();

// Comentario para mostrar: sin la marca ni la etiqueta antigua.
String comentarioVisible(String comentario) =>
    [for (final x in comentario.split('\n')) _motivoDeLinea(x) ?? x].join('\n');
