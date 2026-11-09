// La nota general de un pedido vive en `pedidos.comentarios`, y el backend usa
// ese mismo texto para guardar el nombre del cliente en una línea que empieza
// con "Cliente:". Estas funciones separan las dos cosas para que, al editar la
// nota, no se pierda el nombre del cliente.

bool _esLineaDeCliente(String linea) => linea.trim().startsWith('Cliente:');

// La propina que anota el mozo o caja se guarda en una línea "Propina: 4.00" de
// los comentarios: así viaja al servidor y otro equipo (el de caja) la ve al
// cobrar.
bool _esLineaDePropina(String linea) => linea.trim().startsWith('Propina:');

bool _esLineaReservada(String linea) =>
    _esLineaDeCliente(linea) || _esLineaDePropina(linea);

// La nota que escribió el usuario (sin las líneas "Cliente: ..." ni "Propina: ...").
// null si no hay.
String? notaGeneralDe(String? comentarios) {
  if (comentarios == null) return null;
  final lineas = [
    for (final l in comentarios.split('\n'))
      if (!_esLineaReservada(l)) l.trimRight(),
  ];
  final texto = lineas.join('\n').trim();
  return texto.isEmpty ? null : texto;
}

// Texto que se guarda en `comentarios`: las líneas "Cliente: ..." y "Propina: ..."
// que ya tenía el pedido (si las tenía) y la nota nueva. null si no queda nada.
String? comentariosConNota(String? comentariosActuales, String? nota) {
  final reservadas = [
    for (final l in (comentariosActuales ?? '').split('\n'))
      if (_esLineaReservada(l)) l.trim(),
  ];
  final limpia = nota?.trim() ?? '';
  final partes = [...reservadas, if (limpia.isNotEmpty) limpia];
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

// La propina guardada en los comentarios ("Propina: 4.00"). null si no hay.
double? propinaEnComentarios(String? comentarios) {
  for (final l in (comentarios ?? '').split('\n')) {
    if (_esLineaDePropina(l)) {
      final v = double.tryParse(
        l.trim().substring('Propina:'.length).trim().replaceAll(',', '.'),
      );
      return (v != null && v > 0) ? v : null;
    }
  }
  return null;
}

// Los comentarios con la propina puesta (o quitada si [monto] es 0), sin tocar el
// resto del texto. null si no queda nada.
String? comentariosConPropina(String? comentarios, double monto) {
  final lineas = [
    for (final l in (comentarios ?? '').split('\n'))
      if (!_esLineaDePropina(l) && l.trim().isNotEmpty) l.trimRight(),
    if (monto > 0.004) 'Propina: ${monto.toStringAsFixed(2)}',
  ];
  return lineas.isEmpty ? null : lineas.join('\n');
}

// Los comentarios sin la línea de la propina (para mostrarlos como texto).
String? sinLineaDePropina(String? comentarios) {
  final lineas = [
    for (final l in (comentarios ?? '').split('\n'))
      if (!_esLineaDePropina(l)) l,
  ];
  final texto = lineas.join('\n').trim();
  return texto.isEmpty ? null : texto;
}
