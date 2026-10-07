import '../models/medio_pago.dart';
import '../models/pago.dart';
import '../models/pago_detalle.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import 'mesas_store.dart';
import 'pedidos_store.dart';
import '../services/pedido_service.dart';
import '../utils/uuid_helper.dart';

// Estado en memoria de pagos. Soporta pagos parciales/divididos: cada pago
// se reparte entre las líneas del pedido que aún tengan saldo pendiente
// (`pago_detalle`). El pedido solo pasa a 'pagado' (y libera la mesa) cuando
// la suma de sus pagos cubre el total.
// TODO: reemplazar por `pago`/`pago_detalle` reales al conectar el backend.
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

// Registra un pago (posiblemente parcial) por [montoAbonado] y lo reparte
// entre las líneas del pedido con saldo pendiente, en orden, hasta agotarlo.
Pago registrarPago({
  required Pedido pedido,
  required MedioPago medioPago,
  required double montoAbonado,
  required double propina,
  String? pagador,
}) {
  final montoComision = medioPago.aplicaComision
      ? montoAbonado * (medioPago.porcentajeComision / 100)
      : 0.0;
  final pago = Pago(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    pedidoId: pedido.id,
    mesaNumero: pedido.mesaNumero,
    medioPago: medioPago,
    montoAbonado: montoAbonado,
    montoComision: montoComision,
    montoCobrado: montoAbonado - montoComision,
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

// Si el pedido ya no tiene saldo por cobrar, pasa a 'pagado' y libera sus mesas.
void cerrarSiSaldado(Pedido pedido) {
  if (saldoPendienteDePedido(pedido.id) > 0.01) return;
  actualizarEstadoPedido(pedido.id, 'pagado');
  for (final numero in pedido.todasLasMesas) {
    if (numero == 0) continue;
    actualizarEstadoMesa(numero, 'disponible');
    separarMesas(numero);
  }
  if (UuidHelper.isValid(pedido.id)) {
    PedidoService.instance.cambiarEstadoPedido(pedido.id, 'pagado').catchError((_) {});
  }
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
