// Refleja la tabla `producto_inventario`.
class ProductoInventario {
  final String id;
  final String nombre;
  final String? descripcion;
  final int tipoProductoId;
  final int tipoSeguimientoId;
  final int unidadProductoId;
  final double stockActual;
  final double? costoReposicion;
  final String? notas;
  final String estado; // 'activo' | 'inactivo'

  const ProductoInventario({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.tipoProductoId,
    required this.tipoSeguimientoId,
    required this.unidadProductoId,
    required this.stockActual,
    this.costoReposicion,
    this.notas,
    this.estado = 'activo',
  });

  ProductoInventario copyWith({double? stockActual}) => ProductoInventario(
    id: id,
    nombre: nombre,
    descripcion: descripcion,
    tipoProductoId: tipoProductoId,
    tipoSeguimientoId: tipoSeguimientoId,
    unidadProductoId: unidadProductoId,
    stockActual: stockActual ?? this.stockActual,
    costoReposicion: costoReposicion,
    notas: notas,
    estado: estado,
  );
}
