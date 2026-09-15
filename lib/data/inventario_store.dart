import '../models/inventario_movimiento.dart';
import '../models/producto_inventario.dart';
import 'mock_productos_inventario.dart';

// Estado en memoria de inventario, compartido entre Inventario y Compras
// (una compra debe reflejarse en el stock real). Sin backend aún, esto vive
// solo mientras la app está abierta.
// TODO: reemplazar por lecturas/escrituras reales a `producto_inventario` /
// `inventario_movimiento` al conectar el servidor local.
final List<ProductoInventario> productosInventario = List.of(
  productosInventarioIniciales,
);
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
