import '../models/compra.dart';
import '../models/compra_detalle.dart';

// Compras (`compra`) y sus detalles (`compra_detalle`). Las guardadas vienen del
// backend (`CatalogService.cargarCompras`). Una compra nueva es un borrador en
// memoria: se le agregan los detalles y se envía completa con
// `CatalogService.guardarCompra`, que también repone el stock.
final List<Compra> compras = [];
final Map<String, List<CompraDetalle>> detallesPorCompra = {};

double _totalDe(List<CompraDetalle> detalles) =>
    detalles.fold(0.0, (suma, d) => suma + d.precioTotal);

// Crea el borrador de una compra (sin detalles todavía).
void registrarCompra(Compra compra) {
  compras.insert(0, compra.copyWith(guardada: false));
  detallesPorCompra[compra.id] = [];
}

// Agrega un detalle a un borrador y actualiza el total de la compra.
void agregarDetalleACompra(String compraId, CompraDetalle detalle) {
  final detalles = detallesPorCompra.putIfAbsent(compraId, () => []);
  detalles.add(detalle);
  _actualizarTotal(compraId);
}

void quitarDetalleDeCompra(String compraId, String detalleId) {
  detallesPorCompra[compraId]?.removeWhere((d) => d.id == detalleId);
  _actualizarTotal(compraId);
}

void descartarCompra(String compraId) {
  compras.removeWhere((c) => c.id == compraId);
  detallesPorCompra.remove(compraId);
}

// Reemplaza una compra (y sus detalles) por lo que devolvió el backend.
void reemplazarCompra(Compra compra, List<CompraDetalle> detalles) {
  final index = compras.indexWhere((c) => c.id == compra.id);
  final nueva = compra.copyWith(total: _totalDe(detalles), guardada: true);
  if (index == -1) {
    compras.insert(0, nueva);
  } else {
    compras[index] = nueva;
  }
  detallesPorCompra[compra.id] = detalles;
}

void _actualizarTotal(String compraId) {
  final index = compras.indexWhere((c) => c.id == compraId);
  if (index == -1) return;
  compras[index] = compras[index].copyWith(
    total: _totalDe(detallesPorCompra[compraId] ?? const []),
  );
}
