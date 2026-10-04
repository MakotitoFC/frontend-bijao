// Nota de crédito (`nota_credito`): documento que reduce la venta. Si el
// cliente ya había pagado, el excedente queda como saldo a favor.
class NotaCredito {
  final String id;
  final String numero; // NC-0001
  final String pedidoId;
  final String pedidoNumero;
  final String concepto;
  final double monto; // monto que reduce la venta
  final double saldoAFavor; // parte ya pagada que queda a favor del cliente
  final String? clienteNombre;
  final DateTime fecha;

  const NotaCredito({
    required this.id,
    required this.numero,
    required this.pedidoId,
    required this.pedidoNumero,
    required this.concepto,
    required this.monto,
    required this.saldoAFavor,
    this.clienteNombre,
    required this.fecha,
  });
}

// Vale de consumo (`vale_consumo`): cupón canjeable por productos, con
// vigencia. No devuelve dinero.
class ValeConsumo {
  final String id;
  final String codigo; // VC-0001
  final String pedidoId;
  final String pedidoNumero;
  final String concepto;
  final double monto;
  final String? clienteNombre;
  final DateTime emision;
  final DateTime vigencia;
  final bool canjeado;

  const ValeConsumo({
    required this.id,
    required this.codigo,
    required this.pedidoId,
    required this.pedidoNumero,
    required this.concepto,
    required this.monto,
    this.clienteNombre,
    required this.emision,
    required this.vigencia,
    this.canjeado = false,
  });

  bool get vencido => DateTime.now().isAfter(vigencia);
}
