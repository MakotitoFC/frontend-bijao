// Refleja la tabla `pago_detalle`: cuánto de un pago se aplicó a cada línea
// del pedido (permite pagos parciales / divididos).
class PagoDetalle {
  final String pagoId;
  final String pedidoDetalleId;
  final double montoAplicado;

  const PagoDetalle({
    required this.pagoId,
    required this.pedidoDetalleId,
    required this.montoAplicado,
  });
}
