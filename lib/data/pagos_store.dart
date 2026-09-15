import '../models/medio_pago.dart';
import '../models/pago.dart';
import '../models/pago_detalle.dart';
import '../models/pedido.dart';
import 'mesas_store.dart';
import 'pedidos_store.dart';

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

  if (saldoPendienteDePedido(pedido.id) <= 0.01) {
    actualizarEstadoPedido(pedido.id, 'pagado');
    for (final numero in pedido.todasLasMesas) {
      actualizarEstadoMesa(numero, 'libre');
      separarMesas(numero);
    }
  }

  return pago;
}
