// La nota general de un pedido vive en `pedidos.comentarios`, y el backend usa
// ese mismo texto para guardar el nombre del cliente en una línea que empieza
// con "Cliente:". Estas funciones separan las dos cosas para que, al editar la
// nota, no se pierda el nombre del cliente.

bool _esLineaDeCliente(String linea) => linea.trim().startsWith('Cliente:');

// La nota que escribió el usuario (sin la línea "Cliente: ..."). null si no hay.
String? notaGeneralDe(String? comentarios) {
  if (comentarios == null) return null;
  final lineas = [
    for (final l in comentarios.split('\n'))
      if (!_esLineaDeCliente(l)) l.trimRight(),
  ];
  final texto = lineas.join('\n').trim();
  return texto.isEmpty ? null : texto;
}

// Texto que se guarda en `comentarios`: la línea "Cliente: ..." que ya tenía el
// pedido (si la tenía) y la nota nueva. null si no queda nada.
String? comentariosConNota(String? comentariosActuales, String? nota) {
  final cliente = [
    for (final l in (comentariosActuales ?? '').split('\n'))
      if (_esLineaDeCliente(l)) l.trim(),
  ];
  final limpia = nota?.trim() ?? '';
  final partes = [...cliente, if (limpia.isNotEmpty) limpia];
  return partes.isEmpty ? null : partes.join('\n');
}

// El nombre que el backend guarda en la línea "Cliente: ..." de los comentarios
// (en un pedido de empleado es el nombre del empleado). null si no hay.
String? nombreEnComentarios(String? comentarios) {
  for (final l in (comentarios ?? '').split('\n')) {
    if (_esLineaDeCliente(l)) {
      final n = l.trim().substring('Cliente:'.length).trim();
      return n.isEmpty ? null : n;
    }
  }
  return null;
}
