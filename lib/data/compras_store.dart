import '../models/compra.dart';
import '../models/compra_detalle.dart';
import '../models/inventario_movimiento.dart';
import 'mock_tipos_movimiento.dart';
import 'inventario_store.dart';

// Estado en memoria de compras. Registrar una compra también repone el
// stock de cada producto comprado (ver inventario_store.dart).
// TODO: reemplazar por `compra`/`compra_detalle` reales al conectar el backend.
final List<Compra> compras = [];
final Map<String, List<CompraDetalle>> detallesPorCompra = {};

void registrarCompra(Compra compra, List<CompraDetalle> detalles) {
  compras.insert(0, compra);
  detallesPorCompra[compra.id] = detalles;

  for (final detalle in detalles) {
    registrarMovimientoInventario(
      InventarioMovimiento(
        productoInventarioId: detalle.productoInventarioId,
        tipoMovimiento: movEntradaCompra,
        cantidad: detalle.cantidad,
        notas: 'Compra a ${compra.proveedor}',
        fecha: compra.fechaCompra,
      ),
    );
  }
}
