import '../utils/json_num.dart';

// Refleja la tabla `cierres_caja` (esquema real en Supabase).
class CierreCaja {
  final String id;
  final String? usuarioId; // usuario_id
  final DateTime fechaInicio; // fecha_inicio
  final DateTime fechaCierre; // fecha_cierre
  final double montoInicial; // monto_inicial
  final double totalEfectivo; // total_efectivo
  final double totalTarjeta; // total_tarjeta
  final double totalYape; // total_yape
  final double totalPlin; // total_plin
  final double totalDelivery; // total_delivery
  final double totalGeneral; // total_general
  final int numPedidos; // num_pedidos
  final double declaradoEfectivo; // declarado_efectivo
  final double declaradoTarjeta; // declarado_tarjeta
  final double declaradoDigital; // declarado_digital
  final double diferenciaEfectivo; // diferencia_efectivo
  final double diferenciaTarjeta; // diferencia_tarjeta
  final double diferenciaDigital; // diferencia_digital
  final String? notas; // notas
  // Ingresos y salidas extra (movimientos de caja) del periodo.
  final double totalIngresos;
  final double totalEgresos;
  // Nombre del cajero cuando el cierre viene del servidor.
  final String? usuarioNombre;

  const CierreCaja({
    required this.id,
    this.usuarioId,
    required this.fechaInicio,
    required this.fechaCierre,
    required this.montoInicial,
    required this.totalEfectivo,
    required this.totalTarjeta,
    required this.totalYape,
    required this.totalPlin,
    required this.totalDelivery,
    required this.totalGeneral,
    required this.numPedidos,
    required this.declaradoEfectivo,
    required this.declaradoTarjeta,
    required this.declaradoDigital,
    required this.diferenciaEfectivo,
    required this.diferenciaTarjeta,
    required this.diferenciaDigital,
    this.notas,
    this.totalIngresos = 0,
    this.totalEgresos = 0,
    this.usuarioNombre,
  });

  // Cierre como lo devuelve el servidor (`/caja/cierre` y `/caja/cierres`).
  factory CierreCaja.fromJson(Map<String, dynamic> j) {
    double n(String k) => jsonDouble(j[k]) ?? 0;
    return CierreCaja(
      id: j['id']?.toString() ?? '',
      usuarioId: j['usuario_id']?.toString(),
      usuarioNombre: j['usuario_nombre']?.toString(),
      fechaInicio:
          DateTime.tryParse(j['fecha_inicio']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      fechaCierre:
          DateTime.tryParse(j['fecha_cierre']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      montoInicial: n('monto_inicial'),
      totalEfectivo: n('total_efectivo'),
      totalTarjeta: n('total_tarjeta'),
      totalYape: n('total_yape'),
      totalPlin: n('total_plin'),
      totalDelivery: n('total_delivery'),
      totalGeneral: n('total_general'),
      numPedidos: (j['num_pedidos'] as num?)?.toInt() ?? 0,
      declaradoEfectivo: n('declarado_efectivo'),
      declaradoTarjeta: n('declarado_tarjeta'),
      declaradoDigital: n('declarado_digital'),
      diferenciaEfectivo: n('diferencia_efectivo'),
      diferenciaTarjeta: n('diferencia_tarjeta'),
      diferenciaDigital: n('diferencia_digital'),
      notas: j['notas']?.toString(),
      totalIngresos: n('total_ingresos'),
      totalEgresos: n('total_salidas'),
    );
  }

  // monto_declarado: lo que el cajero declara en total.
  double get montoDeclarado =>
      declaradoEfectivo + declaradoTarjeta + declaradoDigital;
}
