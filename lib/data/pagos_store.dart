import 'dart:developer' as developer;

import '../models/medio_pago.dart';
import '../models/pago.dart';
import '../models/pago_detalle.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import 'configuracion_store.dart';
import 'mesas_por_liberar_store.dart';
import 'mesas_store.dart';
import 'pedidos_store.dart';
import '../services/pedido_service.dart';
import '../utils/json_num.dart';
import '../utils/uuid_helper.dart';

// Estado en memoria de pagos. Soporta pagos parciales/divididos: cada pago
// se reparte entre las líneas del pedido que aún tengan saldo pendiente
// (`pago_detalle`). El pedido solo pasa a 'pagado' (y libera la mesa) cuando
// la suma de sus pagos cubre el total.
// Los pagos se registran en el servidor (POST /api/pagos, ver PagoService);
// esta lista es lo que la app tiene en memoria de ellos.
final List<Pago> pagos = [];
final List<PagoDetalle> pagoDetalles = [];

double totalDePedido(String pedidoId) => (detallesPorPedido[pedidoId] ?? [])
    .fold(0.0, (sum, l) => sum + l.precioTotalLinea);

double montoPagadoDeLinea(String pedidoDetalleId) => pagoDetalles
    .where((d) => d.pedidoDetalleId == pedidoDetalleId)
    .fold(0.0, (sum, d) => sum + d.montoAplicado);

// Nombres de los medios de pago con los que se cobró un pedido (todos, sin
// repetir): "Yape Joel", "Efectivo"…
List<String> mediosDePagoDe(String pedidoId) => [
  ...{
    for (final p in pagos.where(
      (x) => x.pedidoId == pedidoId && !x.esReembolso,
    ))
      p.medioPago.medioPago,
  },
];

// Efectivo que entregó el cliente al pagar y vuelto que se le dio, por pedido.
// El servidor no lo guarda: sale en el ticket de este dispositivo.
final Map<String, ({double recibido, double vuelto})>
efectivoRecibidoPorPedido = {};

// Lo cobrado por cada medio de pago de un pedido (con el nombre del medio:
// "Yape Joel", "Efectivo"), sumando los pagos del mismo medio. Es lo que sale en
// el ticket.
List<({String medio, double monto})> pagosPorMedioDe(String pedidoId) {
  final porMedio = <String, double>{};
  for (final p in pagos.where(
    (x) => x.pedidoId == pedidoId && !x.esReembolso,
  )) {
    porMedio.update(
      p.medioPago.medioPago,
      (v) => v + p.montoCobrado,
      ifAbsent: () => p.montoCobrado,
    );
  }
  return [for (final e in porMedio.entries) (medio: e.key, monto: e.value)];
}

// Pedido ya cobrado por completo que todavía no sale (sigue pendiente de
// servir): se marca con un tag para que no se confunda con uno por cobrar.
bool pagadoSinServir(Pedido p) {
  if (p.estado != 'pendiente' && p.estado != 'pedido') return false;
  if (!pagos.any((x) => x.pedidoId == p.id && !x.esReembolso)) return false;
  return totalDePedido(p.id) > 0 && saldoPendienteDePedido(p.id) <= 0.01;
}

double saldoPendienteDePedido(String pedidoId) {
  final lineas = detallesPorPedido[pedidoId] ?? [];
  return lineas.fold(
    0.0,
    (sum, l) => sum + (l.precioTotalLinea - montoPagadoDeLinea(l.id)),
  );
}

// Líneas que solo existen en la app: el servidor no las conoce y no las cuenta
// en el saldo del pedido. La propina se manda aparte al cobrar (campo `propina`
// de POST /api/pagos); el táper todavía no se registra en el servidor.
bool esLineaSoloApp(PedidoLine l) => esLineaPropina(l) || esLineaTupper(l);

// ¿Esta línea entra en la cuenta que cobra el servidor? En los pedidos de
// demostración (sin servidor) todas entran.
bool lineaDeCuenta(String pedidoId, PedidoLine l) =>
    !UuidHelper.isValid(pedidoId) || !esLineaSoloApp(l);

// Lo que falta cobrar de la cuenta, sin la propina ni el táper de la app. Es lo
// único que el servidor acepta abonar: si se manda más, rechaza el cobro.
double saldoCuentaDePedido(String pedidoId) {
  final lineas = detallesPorPedido[pedidoId] ?? [];
  return lineas
      .where((l) => lineaDeCuenta(pedidoId, l))
      .fold(
        0.0,
        (sum, l) => sum + (l.precioTotalLinea - montoPagadoDeLinea(l.id)),
      );
}

// Propina que falta cobrar: la del pedido menos la que ya viajó con algún pago.
double propinaPendienteDePedido(String pedidoId) {
  final cobrada = pagos
      .where((p) => p.pedidoId == pedidoId && !p.esReembolso)
      .fold(0.0, (s, p) => s + p.propina);
  final falta = propinaDePedido(pedidoId) - cobrada;
  return falta > 0.001 ? falta : 0;
}

// Táper que falta cobrar (se da por cobrado cuando se salda la cuenta).
double taperPendienteDePedido(String pedidoId) =>
    (detallesPorPedido[pedidoId] ?? [])
        .where(esLineaTupper)
        .fold(
          0.0,
          (s, l) => s + (l.precioTotalLinea - montoPagadoDeLinea(l.id)),
        );

// Propina y táper que el cliente paga además de la cuenta (sin recargo).
double extrasDeAppPendientes(String pedidoId) =>
    propinaPendienteDePedido(pedidoId) + taperPendienteDePedido(pedidoId);

// Deja la propina y el táper de la app como cobrados según los pagos del
// pedido: la propina, con lo que viajó en cada pago; el táper, cuando la cuenta
// quedó saldada. Se puede llamar las veces que haga falta.
void liquidarExtrasDeApp(String pedidoId) {
  if (!UuidHelper.isValid(pedidoId)) return;
  final lineas = detallesPorPedido[pedidoId] ?? [];
  final propinas = lineas.where(esLineaPropina).toList();
  final tapers = lineas.where(esLineaTupper).toList();
  final ids = {
    for (final l in [...propinas, ...tapers]) l.id,
  };
  pagoDetalles.removeWhere((d) => ids.contains(d.pedidoDetalleId));

  // Del pago más antiguo al más nuevo (la lista va del más nuevo al más antiguo).
  final delPedido = pagos
      .where((p) => p.pedidoId == pedidoId && !p.esReembolso)
      .toList()
      .reversed
      .toList();
  for (final pago in delPedido) {
    var restante = pago.propina;
    for (final l in propinas) {
      if (restante <= 0.001) break;
      final falta = l.precioTotalLinea - montoPagadoDeLinea(l.id);
      if (falta <= 0.001) continue;
      final aplicado = restante < falta ? restante : falta;
      pagoDetalles.add(
        PagoDetalle(
          pagoId: pago.id,
          pedidoDetalleId: l.id,
          montoAplicado: aplicado,
        ),
      );
      restante -= aplicado;
    }
  }
  if (delPedido.isNotEmpty && saldoCuentaDePedido(pedidoId) <= 0.01) {
    for (final l in tapers) {
      final falta = l.precioTotalLinea - montoPagadoDeLinea(l.id);
      if (falta <= 0.001) continue;
      pagoDetalles.add(
        PagoDetalle(
          pagoId: delPedido.last.id,
          pedidoDetalleId: l.id,
          montoAplicado: falta,
        ),
      );
    }
  }
}

// Recargo total que ya se cobró en los pagos de un pedido (sin reembolsos).
double recargoCobradoDePedido(String pedidoId) => pagos
    .where((p) => p.pedidoId == pedidoId && !p.esReembolso)
    .fold(0.0, (suma, p) => suma + p.montoComision);

// Registra un pago (posiblemente parcial) por [montoAbonado] y lo reparte
// entre las líneas del pedido con saldo pendiente, en orden, hasta agotarlo.
Pago registrarPago({
  required Pedido pedido,
  required MedioPago medioPago,
  required double montoAbonado,
  required double propina,
  String? pagador,
}) {
  // El recargo (p. ej. de la tarjeta) lo paga el cliente además de la cuenta:
  // `montoAbonado` es lo que se descuenta del saldo y `montoCobrado` lo que
  // realmente se le cobra (cuenta + recargo).
  final montoComision = medioPago.recargoSobre(montoAbonado);
  final pago = Pago(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    pedidoId: pedido.id,
    mesaNumero: pedido.mesaNumero,
    medioPago: medioPago,
    montoAbonado: montoAbonado,
    montoComision: montoComision,
    montoCobrado: montoAbonado + montoComision,
    propina: propina,
    fechaPago: DateTime.now(),
    pagador: pagador,
  );
  pagos.insert(0, pago);

  var restante = montoAbonado;
  for (final linea in detallesPorPedido[pedido.id] ?? []) {
    if (restante <= 0) break;
    final saldoLinea = linea.precioTotalLinea - montoPagadoDeLinea(linea.id);
    if (saldoLinea <= 0) continue;
    final aplicado = restante < saldoLinea ? restante : saldoLinea;
    pagoDetalles.add(
      PagoDetalle(
        pagoId: pago.id,
        pedidoDetalleId: linea.id,
        montoAplicado: aplicado,
      ),
    );
    restante -= aplicado;
  }

  cerrarSiSaldado(pedido);

  return pago;
}

// Si el pedido ya no tiene saldo por cobrar, pasa a 'pagado'. La mesa NO se libera
// aquí: sigue ocupada hasta que el mozo (o el administrador) la libere cuando los
// clientes se retiran; mientras tanto el backend la informa como "por liberar".
//
// [marcarEnServidor] en false cuando el pago ya se registró en el servidor: él
// pasa el pedido a 'pagado' solo (al cubrirse el total), así que no hace falta
// pedirlo otra vez; solo se vuelve a leer la lista de mesas por liberar.
void cerrarSiSaldado(Pedido pedido, {bool marcarEnServidor = true}) {
  if (saldoCuentaDePedido(pedido.id) > 0.01) return;
  actualizarEstadoPedido(pedido.id, 'pagado');
  for (final numero in pedido.todasLasMesas) {
    if (numero == 0) continue;
    separarMesas(numero);
  }
  if (!marcarEnServidor) {
    if (UuidHelper.isValid(pedido.id)) {
      recargarMesasPorLiberar().catchError((Object e) {
        developer.log('[pagos] No se pudo leer las mesas por liberar: $e');
      });
    }
    return;
  }
  if (UuidHelper.isValid(pedido.id)) {
    PedidoService.instance
        .cambiarEstadoPedido(pedido.id, 'pagado')
        // Con el estado ya guardado, el backend informa la mesa por liberar.
        .then((_) => recargarMesasPorLiberar())
        .catchError((Object e) async {
          // No se pudo marcar como pagado en el servidor (por ejemplo, falta de
          // permiso): se vuelve a leer el estado real para no mostrar como
          // cobrado un pedido que en el servidor sigue abierto.
          developer.log('[pagos] No se pudo marcar como pagado: $e');
          try {
            await PedidoService.instance.cargarPedidos();
          } catch (_) {}
        });
  }
}

// Nombre legible de un detalle del pago del servidor (solo se usa el id y el
// monto; el nombre del plato no se guarda).
List<PagoDetalle> _detallesDeJson(String pagoId, Object? crudos) => [
  for (final d in (crudos is List ? crudos : const []))
    if (d is Map<String, dynamic>)
      PagoDetalle(
        pagoId: pagoId,
        pedidoDetalleId: d['pedido_detalle_id']?.toString() ?? '',
        montoAplicado: jsonDouble(d['monto_aplicado']) ?? 0,
      ),
];

// Pago como lo devuelve el servidor (PagoExtendidoResponse). [medio] es el
// método elegido; si no se conoce, se arma con lo que trae el pago.
Pago pagoDeServidor(
  Map<String, dynamic> json,
  Pedido? pedido, {
  MedioPago? medio,
  String? pagador,
}) {
  final porcentaje = jsonDouble(json['porcentaje_comision']) ?? 0;
  final p = Pago(
    id: json['id']?.toString() ?? '',
    pedidoId: json['pedido_id']?.toString() ?? pedido?.id ?? '',
    mesaNumero:
        (json['mesa_numero'] as num?)?.toInt() ?? pedido?.mesaNumero ?? 0,
    medioPago:
        medio ??
        MedioPago(
          id: json['medio_pago_id']?.toString() ?? '',
          medioPago: json['medio_pago_nombre']?.toString() ?? 'Pago',
          aplicaComision: porcentaje > 0,
          porcentajeComision: porcentaje,
        ),
    montoAbonado: jsonDouble(json['monto_abonado']) ?? 0,
    montoComision: jsonDouble(json['monto_comision']) ?? 0,
    montoCobrado: jsonDouble(json['monto_cobrado']) ?? 0,
    propina: jsonDouble(json['propina']) ?? 0,
    fechaPago:
        DateTime.tryParse(json['fecha_pago']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
    // Quién pagó: lo que dice el servidor (`pagador`) o, si no, lo recibido.
    pagador: json['pagador']?.toString() ?? pagador,
    montoRecibido: jsonDouble(json['monto_recibido']),
    vuelto: jsonDouble(json['vuelto']),
  );
  final rec = jsonDouble(json['monto_recibido']) ?? 0;
  final vue = jsonDouble(json['vuelto']) ?? 0;
  if (vue > 0.001 && rec > 0.001) {
    final pid = p.pedidoId;
    if (pid.isNotEmpty) {
      efectivoRecibidoPorPedido[pid] = (recibido: rec, vuelto: vue);
    }
  }
  return p;
}

// Deja en memoria un pago que el servidor ya registró (con el reparto entre las
// líneas que él hizo) y cierra el pedido si ya no tiene saldo.
Pago aplicarPagoDelServidor({
  required Pedido pedido,
  required MedioPago medio,
  required Map<String, dynamic> json,
  String? pagador,
}) {
  final pago = pagoDeServidor(json, pedido, medio: medio, pagador: pagador);
  if (!pagos.any((p) => p.id == pago.id)) {
    pagos.insert(0, pago);
    pagoDetalles.addAll(_detallesDeJson(pago.id, json['detalles']));
  }
  liquidarExtrasDeApp(pedido.id);
  cerrarSiSaldado(pedido, marcarEnServidor: false);
  return pago;
}

// Suma a la memoria los pagos que trae el servidor (por ejemplo, todos los del
// día) y que la app aún no tenía. No toca los que ya estaban.
void agregarPagosDelServidor(List<Map<String, dynamic>> deServidor) {
  for (final j in deServidor) {
    final id = j['id']?.toString() ?? '';
    if (id.isEmpty || pagos.any((p) => p.id == id)) continue;
    final pedidoId = j['pedido_id']?.toString();
    final pedido = pedidos.where((p) => p.id == pedidoId).firstOrNull;
    final medioId = j['medio_pago_id']?.toString();
    final conocido = mediosPago.where((m) => m.id == medioId);
    pagos.add(
      pagoDeServidor(
        j,
        pedido,
        medio: conocido.isEmpty ? null : conocido.first,
      ),
    );
    pagoDetalles.addAll(_detallesDeJson(id, j['detalles']));
  }
  pagos.sort((a, b) => b.fechaPago.compareTo(a.fechaPago));
  for (final id in {
    for (final j in deServidor) j['pedido_id']?.toString() ?? '',
  }) {
    if (id.isNotEmpty) liquidarExtrasDeApp(id);
  }
}

// Reemplaza lo que se tiene en memoria de los pagos de un pedido por lo que dice
// el servidor (GET /api/pedidos/:id/pagos).
void reemplazarPagosDePedido(
  Pedido pedido,
  List<Map<String, dynamic>> deServidor,
) {
  final viejos = pagos
      .where((p) => p.pedidoId == pedido.id)
      .map((p) => p.id)
      .toSet();
  pagos.removeWhere((p) => p.pedidoId == pedido.id);
  pagoDetalles.removeWhere((d) => viejos.contains(d.pagoId));
  for (final j in deServidor) {
    final medioId = j['medio_pago_id']?.toString();
    final conocido = mediosPago.where((m) => m.id == medioId);
    final pago = pagoDeServidor(
      j,
      pedido,
      medio: conocido.isEmpty ? null : conocido.first,
    );
    pagos.add(pago);
    pagoDetalles.addAll(_detallesDeJson(pago.id, j['detalles']));
  }
  // Más reciente primero, como en `registrarPago`.
  pagos.sort((a, b) => b.fechaPago.compareTo(a.fechaPago));
  liquidarExtrasDeApp(pedido.id);
}

// Devuelve dinero al cliente: un pago de monto negativo (afecta caja o
// pasarela) aplicado a la línea de ajuste que reduce la venta.
Pago registrarReembolso({
  required Pedido pedido,
  required PedidoLine lineaAjuste,
  required MedioPago medioPago,
  required double monto,
}) {
  final pago = Pago(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    pedidoId: pedido.id,
    mesaNumero: pedido.mesaNumero,
    medioPago: medioPago,
    montoAbonado: -monto,
    montoComision: 0,
    montoCobrado: -monto,
    propina: 0,
    fechaPago: DateTime.now(),
    pagador: 'Reembolso',
  );
  pagos.insert(0, pago);
  pagoDetalles.add(
    PagoDetalle(
      pagoId: pago.id,
      pedidoDetalleId: lineaAjuste.id,
      montoAplicado: -monto,
    ),
  );
  return pago;
}

// Medio del último cobro del pedido (para sugerirlo al devolver dinero).
String? medioDeUltimoPago(String pedidoId) {
  for (final p in pagos) {
    if (p.pedidoId == pedidoId && !p.esReembolso) return p.medioPago.id;
  }
  return null;
}
