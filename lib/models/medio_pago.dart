// Refleja la tabla `medio_pago`.
class MedioPago {
  final String id;
  final String medioPago;
  final bool aplicaComision;
  final double porcentajeComision;

  const MedioPago({
    required this.id,
    required this.medioPago,
    required this.aplicaComision,
    this.porcentajeComision = 0,
  });
}
