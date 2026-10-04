import 'medio_pago.dart';

// Refleja la tabla `pago`. Un reembolso se registra como un pago con monto
// negativo (sale de caja o de la pasarela).
class Pago {
  final String id;
  final String pedidoId;
  final int mesaNumero;
  final MedioPago medioPago;
  final double montoAbonado;
  final double montoComision;
  final double montoCobrado;
  final double propina;
  final DateTime fechaPago;
  // Quién pagó (pago compartido) o motivo del movimiento (ej. "Reembolso").
  final String? pagador;

  const Pago({
    required this.id,
    required this.pedidoId,
    required this.mesaNumero,
    required this.medioPago,
    required this.montoAbonado,
    required this.montoComision,
    required this.montoCobrado,
    required this.propina,
    required this.fechaPago,
    this.pagador,
  });

  bool get esReembolso => montoAbonado < 0;
}
