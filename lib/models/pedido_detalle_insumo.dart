// Refleja la tabla `pedidos_detalle_insumo`: el consumo real de insumo
// registrado para una línea de pedido vendida (trazabilidad de receta).
class PedidoDetalleInsumo {
  final String id;
  final String pedidoDetalleId;
  final String productoInventarioId;
  final double cantidadUsada;
  final double costo;
  final DateTime fecha;

  const PedidoDetalleInsumo({
    required this.id,
    required this.pedidoDetalleId,
    required this.productoInventarioId,
    required this.cantidadUsada,
    required this.costo,
    required this.fecha,
  });
}
