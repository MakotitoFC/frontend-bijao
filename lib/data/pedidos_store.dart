import '../models/pedido.dart';
import '../models/pedido_line.dart';

// Estado en memoria de pedidos confirmados, compartido entre Mesas/Pedidos
// (mesero) y Cocina.
// TODO: reemplazar por `pedidos`/`pedidos_detalle` reales al conectar el
// servidor local.
final List<Pedido> pedidos = [];
final Map<String, List<PedidoLine>> detallesPorPedido = {};

// pedidos.numero_pedido: código correlativo simple, útil para identificar
// pedidos de delivery en cocina cuando no hay número de mesa.
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

// Edición de un pedido ya registrado (`pedidos_detalle`).
void actualizarDatosPedido(
  String id, {
  required String? clienteNombre,
  required String? clienteCelular,
  required String? direccionDelivery,
  required String? notas,
}) {
  final i = pedidos.indexWhere((p) => p.id == id);
  if (i == -1) return;
  pedidos[i] = pedidos[i].conDatos(
    clienteNombre: clienteNombre,
    clienteCelular: clienteCelular,
    direccionDelivery: direccionDelivery,
    notas: notas,
  );
}

// Agrega un producto a un pedido ya registrado; si ya estaba listo o entregado
// vuelve a pendiente para que cocina lo prepare.
void agregarLineaAPedido(String pedidoId, PedidoLine linea) {
  detallesPorPedido[pedidoId]?.add(linea);
  final i = pedidos.indexWhere((p) => p.id == pedidoId);
  if (i != -1 &&
      (pedidos[i].estado == 'listo' || pedidos[i].estado == 'entregado')) {
    actualizarEstadoPedido(pedidoId, 'pendiente');
  }
}

void quitarLineaDePedido(String pedidoId, String lineaId) {
  detallesPorPedido[pedidoId]?.removeWhere((l) => l.id == lineaId);
  lineasEntregadas.remove(lineaId);
}

void cambiarCantidadLineaDePedido(String pedidoId, String lineaId, int delta) {
  final lineas = detallesPorPedido[pedidoId];
  if (lineas == null) return;
  final i = lineas.indexWhere((l) => l.id == lineaId);
  if (i == -1) return;
  final nueva = lineas[i].cantidad + delta;
  if (nueva < 1) return;
  lineas[i] = lineas[i].conCantidad(nueva);
}

void actualizarNotaLinea(String pedidoId, String lineaId, String? nota) {
  final lineas = detallesPorPedido[pedidoId];
  if (lineas == null) return;
  final i = lineas.indexWhere((l) => l.id == lineaId);
  if (i != -1) lineas[i] = lineas[i].conComentario(nota);
}

// Descuento: se guarda como una línea negativa (`cartaIdAjuste`).
PedidoLine? agregarAjusteAPedido(String pedidoId, String nombre, double monto) {
  final lineas = detallesPorPedido[pedidoId];
  if (lineas == null || monto <= 0) return null;
  final linea = PedidoLine(
    id: '${DateTime.now().microsecondsSinceEpoch}-ajuste',
    cartaId: cartaIdAjuste,
    nombrePlato: nombre,
    cantidad: 1,
    modificadores: const [],
    presentacion: null,
    promocion: null,
    comentario: null,
    precioUnitario: -monto,
    descuentoAplicado: 0,
    precioTotalLinea: -monto,
  );
  lineas.add(linea);
  return linea;
}

// Prefijos de las líneas de ajuste que genera una resolución de devolución.
const ajusteReembolso = 'Reembolso: ';
const ajusteCambio = 'Cambio de producto: ';
const ajusteNotaCredito = 'Nota de crédito: ';
const prefijosAjusteDevolucion = [
  ajusteReembolso,
  ajusteCambio,
  ajusteNotaCredito,
];

bool esAjusteDeDevolucion(PedidoLine l) =>
    l.cartaId == cartaIdAjuste &&
    prefijosAjusteDevolucion.any(l.nombrePlato.startsWith);

// Pedidos cuya comanda ya se mandó a imprimir (pedido_items.impreso).
final Set<String> pedidosImpresos = {};

void marcarPedidoImpreso(String id) => pedidosImpresos.add(id);

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

// ¿Es un producto (y no un cargo de delivery ni un ajuste)?
bool esLineaDeProducto(PedidoLine l) =>
    l.cartaId != cartaIdCargoDelivery && l.cartaId != cartaIdAjuste;

// Propina para el mesero: una línea de ajuste con monto positivo.
const ajustePropina = 'Propina: ';

bool esLineaPropina(PedidoLine l) =>
    l.cartaId == cartaIdAjuste && l.nombrePlato.startsWith(ajustePropina);

double propinaDePedido(String pedidoId) => (detallesPorPedido[pedidoId] ?? [])
    .where(esLineaPropina)
    .fold(0.0, (s, l) => s + l.precioTotalLinea);

// Tupper para llevar: una línea de ajuste por tamaño (grande/mediano).
const ajusteTupper = 'Tupper: ';
const _tamanoTupperGrande = 'Grande';
const _tamanoTupperMediano = 'Mediano';

bool esLineaTupper(PedidoLine l) =>
    l.cartaId == cartaIdAjuste && l.nombrePlato.startsWith(ajusteTupper);

double tupperDePedido(String pedidoId) => (detallesPorPedido[pedidoId] ?? [])
    .where(esLineaTupper)
    .fold(0.0, (s, l) => s + l.precioTotalLinea);

({int grande, int mediano}) tupperCantidades(String pedidoId) {
  var grande = 0;
  var mediano = 0;
  for (final l in (detallesPorPedido[pedidoId] ?? []).where(esLineaTupper)) {
    if (l.nombrePlato == '$ajusteTupper$_tamanoTupperGrande') {
      grande += l.cantidad;
    } else {
      mediano += l.cantidad;
    }
  }
  return (grande: grande, mediano: mediano);
}

// Fija los tuppers del pedido (reemplaza los anteriores); cantidad 0 los quita.
void establecerTupperPedido(
  String pedidoId, {
  required int grande,
  required double precioGrande,
  required int mediano,
  required double precioMediano,
}) {
  final lineas = detallesPorPedido[pedidoId];
  if (lineas == null) return;
  lineas.removeWhere(esLineaTupper);
  void agregar(String tamano, int cantidad, double precio) {
    if (cantidad <= 0) return;
    lineas.add(
      PedidoLine(
        id: '${DateTime.now().microsecondsSinceEpoch}-tupper-$tamano',
        cartaId: cartaIdAjuste,
        nombrePlato: '$ajusteTupper$tamano',
        cantidad: cantidad,
        modificadores: const [],
        presentacion: null,
        promocion: null,
        comentario: null,
        precioUnitario: precio,
        descuentoAplicado: 0,
        precioTotalLinea: precio * cantidad,
      ),
    );
  }

  agregar(_tamanoTupperGrande, grande, precioGrande);
  agregar(_tamanoTupperMediano, mediano, precioMediano);
}

// Fija la propina del pedido (reemplaza la anterior); un monto 0 la quita.
void establecerPropinaPedido(String pedidoId, double monto) {
  final lineas = detallesPorPedido[pedidoId];
  if (lineas == null) return;
  lineas.removeWhere(esLineaPropina);
  if (monto <= 0) return;
  lineas.add(
    PedidoLine(
      id: '${DateTime.now().microsecondsSinceEpoch}-propina',
      cartaId: cartaIdAjuste,
      nombrePlato: '${ajustePropina}mesero',
      cantidad: 1,
      modificadores: const [],
      presentacion: null,
      promocion: null,
      comentario: null,
      precioUnitario: monto,
      descuentoAplicado: 0,
      precioTotalLinea: monto,
    ),
  );
}
