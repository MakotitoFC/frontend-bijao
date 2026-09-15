// Refleja la tabla `utensilio_roto`.
class UtensilioRoto {
  final String id;
  final String productoInventarioId;
  final String empleadoId;
  final int cantidad;
  final double costoTotal;
  final DateTime fecha;
  final String? notas;
  final bool isPagado;
  final bool isRespuesto;

  const UtensilioRoto({
    required this.id,
    required this.productoInventarioId,
    required this.empleadoId,
    required this.cantidad,
    required this.costoTotal,
    required this.fecha,
    this.notas,
    this.isPagado = false,
    this.isRespuesto = false,
  });

  UtensilioRoto copyWith({bool? isPagado, bool? isRespuesto}) => UtensilioRoto(
    id: id,
    productoInventarioId: productoInventarioId,
    empleadoId: empleadoId,
    cantidad: cantidad,
    costoTotal: costoTotal,
    fecha: fecha,
    notas: notas,
    isPagado: isPagado ?? this.isPagado,
    isRespuesto: isRespuesto ?? this.isRespuesto,
  );
}
