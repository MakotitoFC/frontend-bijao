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
  });

  // monto_declarado: lo que el cajero declara en total.
  double get montoDeclarado =>
      declaradoEfectivo + declaradoTarjeta + declaradoDigital;
}
