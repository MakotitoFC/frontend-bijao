import '../models/pedido.dart';
import '../models/pedido_line.dart';

// Estado en memoria de pedidos confirmados, compartido entre Mesas/Pedidos
// (mesero) y Cocina.
// TODO: reemplazar por `pedidos`/`pedidos_detalle` reales al conectar el
// servidor local.
final List<Pedido> pedidos = [];
final Map<String, List<PedidoLine>> detallesPorPedido = {};

void registrarPedido(Pedido pedido, List<PedidoLine> detalles) {
  pedidos.insert(0, pedido);
  detallesPorPedido[pedido.id] = detalles;
}

void actualizarEstadoPedido(String id, String nuevoEstado) {
  final index = pedidos.indexWhere((p) => p.id == id);
  if (index != -1)
    pedidos[index] = pedidos[index].copyWith(estado: nuevoEstado);
}
