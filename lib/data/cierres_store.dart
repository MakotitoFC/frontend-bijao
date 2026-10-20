import '../models/cierre_caja.dart';
import 'movimientos_caja_store.dart';
import 'pagos_store.dart';
import 'pedidos_store.dart';

// Cierres de caja en memoria (`cierres_caja`). La caja actual abarca los
// pagos hechos desde el último cierre.
// TODO: reemplazar por `cierres_caja` real al conectar el backend.
final List<CierreCaja> cierresCaja = [];

// La caja actual empieza en el último cierre; si aún no hubo ninguno, a las
// 00:00 de hoy (igual que el servidor), para que entren los ingresos y salidas
// de la mañana aunque todavía no haya cobros.
DateTime get inicioCajaActual {
  if (cierresCaja.isNotEmpty) return cierresCaja.first.fechaCierre;
  final h = DateTime.now();
  return DateTime(h.year, h.month, h.day);
}

class TotalesCaja {
  final double efectivo;
  final double tarjeta;
  final double yape;
  final double plin;
  final double delivery;
  final double general;
  final int pedidos;

  const TotalesCaja({
    required this.efectivo,
    required this.tarjeta,
    required this.yape,
    required this.plin,
    required this.delivery,
    required this.general,
    required this.pedidos,
  });
}

// Suma los pagos registrados desde el último cierre, por método de pago.
TotalesCaja totalesCajaActual() {
  final desde = inicioCajaActual;
  var efectivo = 0.0, tarjeta = 0.0, yape = 0.0, plin = 0.0, delivery = 0.0;
  final pedidosIds = <String>{};
  for (final pago in pagos.where((p) => !p.fechaPago.isBefore(desde))) {
    pedidosIds.add(pago.pedidoId);
    // Lo que de verdad entró por ese método: la cuenta más el recargo.
    final monto = pago.montoCobrado;
    switch (pago.medioPago.medioPago.toLowerCase()) {
      case 'efectivo':
        efectivo += monto;
      case 'tarjeta':
        tarjeta += monto;
      case 'yape':
        yape += monto;
      case 'plin':
        plin += monto;
    }
    final esDelivery = pedidos.any(
      (p) => p.id == pago.pedidoId && p.tipoPedido == 'delivery',
    );
    if (esDelivery) delivery += monto;
  }
  return TotalesCaja(
    efectivo: efectivo,
    tarjeta: tarjeta,
    yape: yape,
    plin: plin,
    delivery: delivery,
    general: efectivo + tarjeta + yape + plin,
    pedidos: pedidosIds.length,
  );
}

CierreCaja registrarCierreCaja({
  required String? usuarioId,
  required double montoInicial,
  required double declaradoEfectivo,
  required double declaradoTarjeta,
  required double declaradoDigital,
  String? notas,
}) {
  final t = totalesCajaActual();
  // Lo que debería haber: ventas más ingresos menos salidas, por grupo.
  final esperado = netoPorGrupo(inicioCajaActual);
  final extra = totalesMovimientos(inicioCajaActual);
  final cierre = CierreCaja(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    usuarioId: usuarioId,
    fechaInicio: inicioCajaActual,
    fechaCierre: DateTime.now(),
    montoInicial: montoInicial,
    totalEfectivo: t.efectivo,
    totalTarjeta: t.tarjeta,
    totalYape: t.yape,
    totalPlin: t.plin,
    totalDelivery: t.delivery,
    totalGeneral: t.general,
    numPedidos: t.pedidos,
    declaradoEfectivo: declaradoEfectivo,
    declaradoTarjeta: declaradoTarjeta,
    declaradoDigital: declaradoDigital,
    // Lo que debería haber en la caja vs. lo que se declaró.
    totalIngresos: extra.ingresos,
    totalEgresos: extra.egresos,
    diferenciaEfectivo: declaradoEfectivo - (montoInicial + esperado.efectivo),
    diferenciaTarjeta: declaradoTarjeta - esperado.tarjeta,
    diferenciaDigital: declaradoDigital - esperado.digital,
    notas: notas,
  );
  cierresCaja.insert(0, cierre);
  return cierre;
}
