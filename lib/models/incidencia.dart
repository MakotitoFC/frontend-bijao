// Datos que captura "Reportar problema": categoría, detalle del motivo,
// evidencia opcional y resolución (con los datos extra que pide cada una).
typedef ReporteProblema = ({
  String categoria,
  String detalle,
  String? evidencia,
  // 'reembolso' | 'cambio' | 'nota_credito' | 'vale' | 'rechazado'
  String resolucion,
  // Cambio de producto: producto que se entrega en su lugar.
  String? reemplazoNombre,
  double? reemplazoPrecio,
  String? reemplazoCartaId,
  // Reembolso (o cambio con devolución): método por el que se devuelve.
  String? medioReembolsoId,
});

// Devolución/reclamo de un plato ya pedido (refleja una futura tabla
// `pedidos_detalle_incidencia`, no existe todavía en la BD).
class Incidencia {
  final String id;
  final String pedidoId;
  final String pedidoLineaId; // PedidoLine.id
  final String categoria;
  final String detalle;
  final String? evidencia;
  final String resolucion;
  final DateTime fecha;

  const Incidencia({
    required this.id,
    required this.pedidoId,
    required this.pedidoLineaId,
    required this.categoria,
    required this.detalle,
    this.evidencia,
    required this.resolucion,
    required this.fecha,
  });

  String get etiquetaResolucion => etiquetaDeResolucion(resolucion);
}

String etiquetaDeResolucion(String resolucion) => switch (resolucion) {
  'reembolso' => 'Reembolso',
  'cambio' => 'Cambio de producto',
  'nota_credito' => 'Nota de crédito',
  'vale' => 'Vale de consumo',
  'rechazado' => 'Rechazado',
  _ => resolucion,
};
