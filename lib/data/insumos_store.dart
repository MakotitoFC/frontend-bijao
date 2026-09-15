import '../models/carta_insumo.dart';
import '../models/inventario_movimiento.dart';
import '../models/pedido_detalle_insumo.dart';
import '../models/pedido_line.dart';
import 'inventario_store.dart';
import 'mock_carta_insumos.dart';
import 'mock_tipos_movimiento.dart';

// Trazabilidad de insumos por plato vendido (simula `carta_insumo` +
// `pedidos_detalle_insumo`). Al confirmar un pedido, las recetas de
// cantidad fija descuentan stock automáticamente; las variables (ej.
// bebidas por presentación) quedan pendientes de registrar manualmente
// (ver CocinaScreen).
// TODO: reemplazar por datos reales al conectar el backend.
final List<PedidoDetalleInsumo> pedidoDetalleInsumos = [];

List<CartaInsumo> recetaDeCarta(String cartaId) =>
    mockCartaInsumos.where((r) => r.cartaId == cartaId).toList();

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
}) {
  final producto = productosInventario
      .where((p) => p.id == receta.productoInventarioId)
      .firstOrNull;
  final costo = (producto?.costoReposicion ?? 0) * cantidad;

  pedidoDetalleInsumos.add(
    PedidoDetalleInsumo(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      pedidoDetalleId: linea.id,
      productoInventarioId: receta.productoInventarioId,
      cantidadUsada: cantidad,
      costo: costo,
      fecha: DateTime.now(),
    ),
  );

  registrarMovimientoInventario(
    InventarioMovimiento(
      productoInventarioId: receta.productoInventarioId,
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
