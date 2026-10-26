import '../utils/json_num.dart';

// Grupos de medios de pago: de ellos salen las tarjetas de Caja y el efectivo
// esperado (así varios números de Yape suman juntos).
const gruposMedioPago = ['efectivo', 'tarjeta', 'digital'];

String etiquetaGrupoMedioPago(String grupo) => switch (grupo) {
  'efectivo' => 'En efectivo',
  'digital' => 'Digital (Yape, Plin…)',
  _ => 'Tarjeta / otros',
};

// Los medios activos agrupados (efectivo, tarjeta, digital) y en ese orden, para
// elegir primero el tipo y luego el medio (por ejemplo, cuál Yape).
Map<String, List<MedioPago>> agruparMediosPago(Iterable<MedioPago> medios) => {
  for (final g in gruposMedioPago)
    if (medios.any((m) => m.grupo == g))
      g: [
        for (final m in medios)
          if (m.grupo == g) m,
      ],
};

// Grupo que se supone por el nombre cuando el servidor no lo manda.
String grupoPorNombre(String nombre) {
  final n = nombre.trim().toLowerCase();
  if (n.contains('efectivo')) return 'efectivo';
  if (n.contains('yape') || n.contains('plin')) return 'digital';
  return 'tarjeta';
}

// Método de pago (tabla `medio_pago`). `activo` controla si se ofrece al
// cobrar; `aplicaComision`/`porcentajeComision` es el recargo que se suma al
// total del cliente por usar ese método (por ejemplo, la tarjeta). `grupo` es
// `efectivo`, `tarjeta` o `digital`: lo elige el administrador al crear el
// método y el servidor suma las tarjetas de Caja por él.
class MedioPago {
  final String id;
  final String medioPago;
  final String? descripcion;
  final bool aplicaComision;
  final double porcentajeComision;
  final bool activo;
  final String? _grupo;

  const MedioPago({
    required this.id,
    required this.medioPago,
    required this.aplicaComision,
    this.descripcion,
    this.porcentajeComision = 0,
    this.activo = true,
    String? grupo,
    // ignore: prefer_initializing_formals
  }) : _grupo = grupo;

  // El grupo del servidor o, si no lo manda, el que se supone por el nombre.
  String get grupo => _grupo ?? grupoPorNombre(medioPago);

  factory MedioPago.fromJson(Map<String, dynamic> json) => MedioPago(
    id: json['id']?.toString() ?? '',
    medioPago: json['medio_pago']?.toString() ?? '',
    descripcion: json['descripcion']?.toString(),
    aplicaComision: json['aplica_comision'] == true,
    porcentajeComision: jsonDouble(json['porcentaje_comision']) ?? 0,
    activo: json['estado'] as bool? ?? true,
    grupo: json['grupo']?.toString(),
  );

  // Recargo que se suma cuando el cliente paga [monto] con este método (0 si no
  // lleva), redondeado a centavos. No cambia lo que se abona a la cuenta: es un
  // cobro adicional sobre ese monto.
  double recargoSobre(double monto) {
    if (!aplicaComision || monto <= 0) return 0;
    return (monto * porcentajeComision).roundToDouble() / 100;
  }

  MedioPago copyWith({
    String? medioPago,
    String? descripcion,
    bool? aplicaComision,
    double? porcentajeComision,
    bool? activo,
    String? grupo,
  }) => MedioPago(
    id: id,
    medioPago: medioPago ?? this.medioPago,
    descripcion: descripcion ?? this.descripcion,
    aplicaComision: aplicaComision ?? this.aplicaComision,
    porcentajeComision: porcentajeComision ?? this.porcentajeComision,
    activo: activo ?? this.activo,
    grupo: grupo ?? _grupo,
  );
}
