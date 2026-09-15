// Refleja la tabla `compra_detalle`.
class CompraDetalle {
  final String id;
  final String compraId;
  final String productoInventarioId;
  final double cantidad;
  final int unidadProductoId;
  final double precioUnitario;
  final double precioTotal;

  const CompraDetalle({
    required this.id,
    required this.compraId,
    required this.productoInventarioId,
    required this.cantidad,
    required this.unidadProductoId,
    required this.precioUnitario,
    required this.precioTotal,
  });
}
