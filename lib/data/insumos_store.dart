import '../models/carta_insumo.dart';
import '../models/inventario_movimiento.dart';
import '../models/pedido_detalle_insumo.dart';
import '../models/promocion_componente.dart';
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
// Línea de producto equivalente a un componente de una promoción, para reutilizar
// las recetas de ese plato.
PedidoLine _lineaDeComponente(PedidoLine linea, ComponenteElegido e) =>
    PedidoLine(
      id: linea.id,
      cartaId: e.cartaId,
      nombrePlato: e.nombre,
      cantidad: linea.cantidad * e.cantidad,
      modificadores: const [],
      presentacion: null,
      promocion: null,
      comentario: null,
      precioUnitario: 0,
      descuentoAplicado: 0,
      precioTotalLinea: 0,
    );

// Si a pedido del cliente se cambian productos de una promoción: devuelve al
// stock lo de los componentes que dejaron de estar y descuenta los nuevos.
void reajustarConsumoDePromocion(PedidoLine anterior, PedidoLine nueva) {
  for (final e in anterior.componentes) {
    final sigue = nueva.componentes.any(
      (n) => n.componenteId == e.componenteId && n.opcionId == e.opcionId,
    );
    if (sigue) continue;
    final virtual = _lineaDeComponente(anterior, e);
    for (final receta in recetaDeCarta(virtual.cartaId)) {
      if (receta.esVariable || receta.cantidadEstandar == null) continue;
      final cantidad = receta.cantidadEstandar! * virtual.cantidad;
      pedidoDetalleInsumos.removeWhere(
        (pdi) =>
            pdi.pedidoDetalleId == anterior.id &&
            pdi.productoInventarioId == receta.productoInventarioId,
      );
      registrarMovimientoInventario(
        InventarioMovimiento(
          productoInventarioId: receta.productoInventarioId,
          tipoMovimiento: movEntradaManual,
          cantidad: cantidad,
          notas: 'Cambio de producto en promoción: ${e.nombre}',
          fecha: DateTime.now(),
        ),
      );
    }
  }
  for (final e in nueva.componentes) {
    final existia = anterior.componentes.any(
      (a) => a.componenteId == e.componenteId && a.opcionId == e.opcionId,
    );
    if (existia) continue;
    registrarConsumoAutomaticoDeLinea(_lineaDeComponente(nueva, e));
  }
}

void registrarConsumoAutomaticoDeLinea(PedidoLine linea) {
  if (linea.promocion != null) {
    for (final e in linea.componentes) {
      registrarConsumoAutomaticoDeLinea(_lineaDeComponente(linea, e));
    }
    return;
  }
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
