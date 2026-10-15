import '../utils/json_num.dart';

// Método de pago (tabla `medio_pago`). `activo` controla si se ofrece al
// cobrar; `aplicaComision`/`porcentajeComision` es el cobro adicional por usar
// ese método.
class MedioPago {
  final String id;
  final String medioPago;
  final String? descripcion;
  final bool aplicaComision;
  final double porcentajeComision;
  final bool activo;

  const MedioPago({
    required this.id,
    required this.medioPago,
    required this.aplicaComision,
    this.descripcion,
    this.porcentajeComision = 0,
    this.activo = true,
  });

  factory MedioPago.fromJson(Map<String, dynamic> json) => MedioPago(
    id: json['id']?.toString() ?? '',
    medioPago: json['medio_pago']?.toString() ?? '',
    descripcion: json['descripcion']?.toString(),
    aplicaComision: json['aplica_comision'] == true,
    porcentajeComision: jsonDouble(json['porcentaje_comision']) ?? 0,
    activo: json['estado'] as bool? ?? true,
  );

  MedioPago copyWith({
    String? medioPago,
    String? descripcion,
    bool? aplicaComision,
    double? porcentajeComision,
    bool? activo,
  }) => MedioPago(
    id: id,
    medioPago: medioPago ?? this.medioPago,
    descripcion: descripcion ?? this.descripcion,
    aplicaComision: aplicaComision ?? this.aplicaComision,
    porcentajeComision: porcentajeComision ?? this.porcentajeComision,
    activo: activo ?? this.activo,
  );
}
