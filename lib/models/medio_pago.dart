// Método de pago (`pagos.metodo`: efectivo, tarjeta, yape, plin). `activo`
// controla si se ofrece al cobrar; `aplicaComision`/`porcentajeComision` es el
// cobro adicional por usar ese método.
class MedioPago {
  final String id;
  final String medioPago;
  final bool aplicaComision;
  final double porcentajeComision;
  final bool activo;

  const MedioPago({
    required this.id,
    required this.medioPago,
    required this.aplicaComision,
    this.porcentajeComision = 0,
    this.activo = true,
  });

  MedioPago copyWith({
    bool? aplicaComision,
    double? porcentajeComision,
    bool? activo,
  }) => MedioPago(
    id: id,
    medioPago: medioPago,
    aplicaComision: aplicaComision ?? this.aplicaComision,
    porcentajeComision: porcentajeComision ?? this.porcentajeComision,
    activo: activo ?? this.activo,
  );
}
