// Devolución/reclamo de un plato ya pedido (refleja una futura tabla
// `pedidos_detalle_incidencia`, no existe todavía en la BD).
class Incidencia {
  final String id;
  final String pedidoId;
  final String pedidoLineaId; // PedidoLine.id
  final String motivo;
  // 'rehacer' | 'descuento' | 'no_cobrar' | 'casa'
  final String accion;
  final String? nota;
  final DateTime fecha;

  const Incidencia({
    required this.id,
    required this.pedidoId,
    required this.pedidoLineaId,
    required this.motivo,
    required this.accion,
    this.nota,
    required this.fecha,
  });

  String get etiquetaAccion => switch (accion) {
    'rehacer' => 'Rehacer el plato',
    'descuento' => 'Descuento',
    'no_cobrar' => 'No cobrar nada',
    'casa' => 'A cuenta de la casa',
    _ => accion,
  };
}
