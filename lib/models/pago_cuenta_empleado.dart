// Refleja la tabla `pago_cuenta_empleado` según BD.txt.
class PagoCuentaEmpleado {
  final String id;
  final String empleadoId;
  final String? empleadoNombre;
  final double monto;
  final String medioPagoId;
  final String? medioPagoNombre;
  final String? pedidosId;
  final String utensilioRotoId;
  final String usuarioId;
  final String? usuarioNombre;
  final DateTime? fechaPago;
  final String? nota;
  final DateTime createdAt;

  const PagoCuentaEmpleado({
    required this.id,
    required this.empleadoId,
    this.empleadoNombre,
    required this.monto,
    required this.medioPagoId,
    this.medioPagoNombre,
    this.pedidosId,
    required this.utensilioRotoId,
    required this.usuarioId,
    this.usuarioNombre,
    this.fechaPago,
    this.nota,
    required this.createdAt,
  });

  factory PagoCuentaEmpleado.fromJson(Map<String, dynamic> json) =>
      PagoCuentaEmpleado(
        id: json['id']?.toString() ?? '',
        empleadoId: json['empleado_id']?.toString() ?? '',
        empleadoNombre: json['empleado_nombre']?.toString(),
        monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
        medioPagoId: json['medio_pago_id']?.toString() ?? '',
        medioPagoNombre: json['medio_pago_nombre']?.toString(),
        pedidosId: json['pedidos_id']?.toString(),
        utensilioRotoId: json['utensilio_roto_id']?.toString() ?? '',
        usuarioId: json['usuario_id']?.toString() ?? '',
        usuarioNombre: json['usuario_nombre']?.toString(),
        fechaPago: json['fecha_pago'] != null
            ? DateTime.tryParse(json['fecha_pago'].toString())
            : null,
        nota: json['nota']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'empleado_id': empleadoId,
        'monto': monto,
        'medio_pago_id': medioPagoId,
        'pedidos_id': pedidosId,
        'utensilio_roto_id': utensilioRotoId,
        'usuario_id': usuarioId,
        'fecha_pago': fechaPago?.toIso8601String(),
        'nota': nota,
      };
}
