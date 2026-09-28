import '../models/cierre_caja.dart';
import 'pagos_store.dart';
import 'pedidos_store.dart';

// Cierres de caja en memoria (`cierres_caja`). La caja actual abarca los
// pagos hechos desde el último cierre.
// TODO: reemplazar por `cierres_caja` real al conectar el backend.
final List<CierreCaja> cierresCaja = [];

final DateTime _apertura = DateTime.now();

// La caja actual empieza en el último cierre; si aún no hubo ninguno, en el
// primer cobro registrado (o en la apertura si todavía no hay cobros).
DateTime get inicioCajaActual {
  if (cierresCaja.isNotEmpty) return cierresCaja.first.fechaCierre;
  if (pagos.isEmpty) return _apertura;
  return pagos.map((p) => p.fechaPago).reduce((a, b) => a.isBefore(b) ? a : b);
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
    final monto = pago.montoAbonado;
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
    diferenciaEfectivo: declaradoEfectivo - (montoInicial + t.efectivo),
    diferenciaTarjeta: declaradoTarjeta - t.tarjeta,
    diferenciaDigital: declaradoDigital - (t.yape + t.plin),
    notas: notas,
  );
  cierresCaja.insert(0, cierre);
  return cierre;
}
