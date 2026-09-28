// Refleja la tabla `producto_inventario`.
class ProductoInventario {
  final String id;
  final String nombre;
  final String? descripcion;
  final int tipoProductoId;
  final int tipoSeguimientoId;
  final int unidadProductoId;
  final double stockActual;
  // Debajo de este umbral el producto se resalta como "stock bajo" en
  // Inventario (0 = sin umbral definido).
  final double stockMinimo;
  final double? costoReposicion;
  // Precio al cliente cuando el producto de inventario se vende también
  // directo (ej. pescado del día, cobrado según su peso real) y no solo como
  // insumo de una receta.
  final double? precioCliente;
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
    this.stockMinimo = 0,
    this.costoReposicion,
    this.precioCliente,
    this.notas,
    this.estado = 'activo',
  });

  bool get stockBajo => stockMinimo > 0 && stockActual <= stockMinimo;

  ProductoInventario copyWith({double? stockActual}) => ProductoInventario(
    id: id,
    nombre: nombre,
    descripcion: descripcion,
    tipoProductoId: tipoProductoId,
    tipoSeguimientoId: tipoSeguimientoId,
    unidadProductoId: unidadProductoId,
    stockActual: stockActual ?? this.stockActual,
    stockMinimo: stockMinimo,
    costoReposicion: costoReposicion,
    precioCliente: precioCliente,
    notas: notas,
    estado: estado,
  );
}
