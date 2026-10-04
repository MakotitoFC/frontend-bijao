import '../models/carta_insumo.dart';
import '../models/inventario_movimiento.dart';
import '../models/pedido_detalle_insumo.dart';
import '../models/pedido_line.dart';
import 'catalogos_store.dart';
import 'inventario_store.dart';

// Recetas por plato (tabla `carta_insumo`): qué insumos descuenta cada venta.
// Se cargan desde el backend.
final List<CartaInsumo> recetasCarta = [];

// Consumo de insumos ya registrado por línea de pedido (`pedidos_detalle_insumo`).
final List<PedidoDetalleInsumo> pedidoDetalleInsumos = [];

List<CartaInsumo> recetaDeCarta(String cartaId) =>
    recetasCarta.where((r) => r.cartaId == cartaId).toList();

List<CartaInsumo> insumosPendientesDe(PedidoLine linea) =>
    recetaDeCarta(linea.cartaId)
        .where((r) => r.esVariable)
        .where(
          (r) => !pedidoDetalleInsumos.any(
            (pdi) =>
                pdi.pedidoDetalleId == linea.id &&
                pdi.productoInventarioId == r.productoInventarioId,
          ),
        )
        .toList();

void registrarConsumoInsumo(
  PedidoLine linea,
  CartaInsumo receta, {
  required double cantidad,
}) => registrarConsumoDirecto(
  linea,
  receta.productoInventarioId,
  cantidad: cantidad,
);

// Consumo directo de un insumo del inventario para una línea del pedido.
void registrarConsumoDirecto(
  PedidoLine linea,
  String productoInventarioId, {
  required double cantidad,
}) {
  final producto = productosInventario
      .where((p) => p.id == productoInventarioId)
      .firstOrNull;
  final costo = (producto?.costoReposicion ?? 0) * cantidad;

  pedidoDetalleInsumos.add(
    PedidoDetalleInsumo(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      pedidoDetalleId: linea.id,
      productoInventarioId: productoInventarioId,
      cantidadUsada: cantidad,
      costo: costo,
      fecha: DateTime.now(),
    ),
  );

  registrarMovimientoInventario(
    InventarioMovimiento(
      productoInventarioId: productoInventarioId,
      tipoMovimiento: movSalidaVenta,
      cantidad: cantidad,
      notas: 'Venta: ${linea.nombrePlato}',
      fecha: DateTime.now(),
    ),
  );
}

// Descuenta automáticamente las recetas de cantidad fija de una línea recién
// confirmada. Las variables quedan pendientes (ver insumosPendientesDe).
void registrarConsumoAutomaticoDeLinea(PedidoLine linea) {
  for (final receta in recetaDeCarta(linea.cartaId)) {
    if (!receta.esVariable && receta.cantidadEstandar != null) {
      registrarConsumoInsumo(
        linea,
        receta,
        cantidad: receta.cantidadEstandar! * linea.cantidad,
      );
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
