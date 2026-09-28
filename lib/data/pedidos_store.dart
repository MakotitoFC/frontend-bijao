import '../models/pedido.dart';
import '../models/pedido_line.dart';

// Estado en memoria de pedidos confirmados, compartido entre Mesas/Pedidos
// (mesero) y Cocina.
// TODO: reemplazar por `pedidos`/`pedidos_detalle` reales al conectar el
// servidor local.
final List<Pedido> pedidos = [];
final Map<String, List<PedidoLine>> detallesPorPedido = {};

// pedidos.numero_pedido: código correlativo simple, útil para identificar
// pedidos de llevar/delivery en cocina cuando no hay número de mesa.
int _correlativoPedido = 0;

String siguienteNumeroPedido() {
  _correlativoPedido += 1;
  return _correlativoPedido.toString().padLeft(4, '0');
}

void registrarPedido(Pedido pedido, List<PedidoLine> detalles) {
  pedidos.insert(0, pedido);
  detallesPorPedido[pedido.id] = detalles;
}

void actualizarEstadoPedido(String id, String nuevoEstado) {
  final index = pedidos.indexWhere((p) => p.id == id);
  if (index != -1)
    pedidos[index] = pedidos[index].copyWith(estado: nuevoEstado);
}

// Marca una línea (producto) del pedido con una incidencia (devolución).
void marcarLineaComoIncidencia(String pedidoId, String lineaId) {
  final lineas = detallesPorPedido[pedidoId];
  if (lineas == null) return;
  final i = lineas.indexWhere((l) => l.id == lineaId);
  if (i != -1) lineas[i] = lineas[i].copyWith(estado: 'incidencia');
}

// Pedidos cuya comanda ya se mandó a imprimir (pedido_items.impreso).
final Set<String> pedidosImpresos = {};

void marcarPedidoImpreso(String id) => pedidosImpresos.add(id);

// Productos (líneas) ya preparados según el checklist de cocina.
final Set<String> lineasPreparadas = {};

void alternarLineaPreparada(String lineaId) {
  if (!lineasPreparadas.remove(lineaId)) lineasPreparadas.add(lineaId);
}

// Checklist de entrega por plato: lo controla el mesero desde Pedidos (no
// cocina), para saber qué platos del pedido ya se llevaron a la mesa/cliente
// y cuáles faltan.
final Set<String> lineasEntregadas = {};

void alternarLineaEntregada(String lineaId) {
  if (!lineasEntregadas.remove(lineaId)) lineasEntregadas.add(lineaId);
}

// Línea especial que representa el cobro adicional por delivery
// (`pedidos.cargo_servicio`): no es un producto y cocina no la ve.
const cartaIdCargoDelivery = 'cargo-delivery';

// Línea especial que representa un descuento o servicio adicional agregado
// manualmente al pedido (etiquetas "Descuento"/"+"): no es un producto y
// cocina no la ve.
const cartaIdAjuste = 'ajuste-manual';
