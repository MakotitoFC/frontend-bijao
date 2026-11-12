import 'package:flutter/foundation.dart';

import '../models/inventario_movimiento.dart';
import '../models/producto_inventario.dart';
import '../models/vinculo_carta.dart';

// Stock del inventario (tabla `producto_inventario`) y sus movimientos
// (`inventario_movimiento`). Se cargan desde el backend.
final List<ProductoInventario> productosInventario = [];
final Map<String, List<InventarioMovimiento>> movimientosInventario = {};

// Productos de la carta que descuentan stock de un producto de inventario al
// venderse (`carta_insumo`). Se cargan desde el backend.
final List<VinculoCarta> vinculosCarta = [];

// Productos activos con el stock por agotarse (hay un mínimo y el stock actual
// llegó a él o bajó). Los agotados van primero. Alimenta la campana de
// notificaciones; se recalcula cada vez que cambia la lista de productos.
final ValueNotifier<List<ProductoInventario>> stockBajoNotifier =
    ValueNotifier<List<ProductoInventario>>([]);

void recalcularStockBajo() {
  final lista =
      [
        for (final p in productosInventario)
          if (p.estado && p.stockBajo) p,
      ]..sort((a, b) {
        final porAgotado = (a.stockActual <= 0 ? 0 : 1).compareTo(
          b.stockActual <= 0 ? 0 : 1,
        );
        return porAgotado != 0 ? porAgotado : a.nombre.compareTo(b.nombre);
      });
  final antes = stockBajoNotifier.value;
  final igual =
      antes.length == lista.length &&
      [for (var i = 0; i < lista.length; i++) i].every(
        (i) =>
            antes[i].id == lista[i].id &&
            antes[i].stockActual == lista[i].stockActual,
      );
  if (!igual) stockBajoNotifier.value = lista;
}

// Los vínculos generales (a nivel de producto de la carta) de un producto.
List<VinculoCarta> vinculosDeProducto(String productoId) => [
  for (final v in vinculosCarta)
    if (v.productoInventarioId == productoId && v.generalDelProducto) v,
];

void registrarMovimientoInventario(InventarioMovimiento movimiento) {
  final index = productosInventario.indexWhere(
    (p) => p.id == movimiento.productoInventarioId,
  );
  if (index == -1) return;

  final producto = productosInventario[index];
  final nuevoStock = movimiento.tipoMovimiento.esEntrada
      ? producto.stockActual + movimiento.cantidad
      : producto.stockActual - movimiento.cantidad;
  productosInventario[index] = producto.copyWith(stockActual: nuevoStock);
  movimientosInventario
      .putIfAbsent(movimiento.productoInventarioId, () => [])
      .insert(0, movimiento);
}

void agregarProductoInventario(ProductoInventario producto) {
  productosInventario.add(producto);
}

void actualizarProductoInventario(ProductoInventario producto) {
  final index = productosInventario.indexWhere((p) => p.id == producto.id);
  if (index != -1) productosInventario[index] = producto;
}

void eliminarProductoInventario(String id) {
  productosInventario.removeWhere((p) => p.id == id);
}
