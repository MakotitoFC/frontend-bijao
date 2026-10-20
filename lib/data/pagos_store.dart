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

double saldoPendienteDePedido(String pedidoId) {
  final lineas = detallesPorPedido[pedidoId] ?? [];
  return lineas.fold(
    0.0,
    (sum, l) => sum + (l.precioTotalLinea - montoPagadoDeLinea(l.id)),
  );
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
  if (saldoPendienteDePedido(pedido.id) > 0.01) return;
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
  return Pago(
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
    pagador: pagador,
  );
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
