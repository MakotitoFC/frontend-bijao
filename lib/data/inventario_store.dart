import '../models/inventario_movimiento.dart';
import '../models/producto_inventario.dart';

// Stock del inventario (tabla `producto_inventario`) y sus movimientos
// (`inventario_movimiento`). Se cargan desde el backend.
final List<ProductoInventario> productosInventario = [];
final Map<String, List<InventarioMovimiento>> movimientosInventario = {};

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
