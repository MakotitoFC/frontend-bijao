/// Refleja la tabla `producto_inventario` según BD.txt.
class ProductoInventario {
  final String id;
  final String nombre;
  final String? descripcion;
  final String tipoProductoId;
  final String? tipoProductoNombre;
  final String seguimiento; // 'granel' | 'unidad' | 'individual'
  final String unidadProductoId;
  final String? unidadProductoNombre;
  final double stockActual;
  final double stockMinimo;
  final double costoPromedio;
  final double? costoReposicion;
  final double? precioCliente;
  final String? notas;
  final bool estado; // true = activo/disponible, false = inactivo/agotado
  final String? sedeId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductoInventario({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.tipoProductoId,
    this.tipoProductoNombre,
    this.seguimiento = 'granel',
    required this.unidadProductoId,
    this.unidadProductoNombre,
    required this.stockActual,
    this.stockMinimo = 0,
    this.costoPromedio = 0,
    this.costoReposicion,
    this.precioCliente,
    this.notas,
    this.estado = true,
    this.sedeId,
    this.createdAt,
    this.updatedAt,
  });

  bool get stockBajo => stockMinimo > 0 && stockActual <= stockMinimo;

  factory ProductoInventario.fromJson(Map<String, dynamic> json) =>
      ProductoInventario(
        id: json['id']?.toString() ?? '',
        nombre: json['nombre']?.toString() ?? '',
        descripcion: json['descripcion']?.toString(),
        tipoProductoId: json['tipo_producto_id']?.toString() ?? '',
        tipoProductoNombre: json['tipo_producto_nombre']?.toString(),
        seguimiento: json['seguimiento']?.toString() ?? 'granel',
        unidadProductoId: json['unidad_producto_id']?.toString() ?? '',
        unidadProductoNombre: json['unidad_producto_nombre']?.toString(),
        stockActual: (json['stock_actual'] as num?)?.toDouble() ?? 0.0,
        stockMinimo: (json['stock_minimo'] as num?)?.toDouble() ?? 0.0,
        costoPromedio: (json['costo_promedio'] as num?)?.toDouble() ?? 0.0,
        costoReposicion: (json['costo_reposicion'] as num?)?.toDouble(),
        precioCliente: (json['precio_cliente'] as num?)?.toDouble(),
        notas: json['notas']?.toString(),
        estado: json['estado'] != false,
        sedeId: json['sede_id']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'tipo_producto_id': tipoProductoId,
        'seguimiento': seguimiento,
        'unidad_producto_id': unidadProductoId,
        'stock_actual': stockActual,
        'stock_minimo': stockMinimo,
        'costo_promedio': costoPromedio,
        'costo_reposicion': costoReposicion,
        'notas': notas,
        'estado': estado,
        'sede_id': sedeId,
      };

  ProductoInventario copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    String? tipoProductoId,
    String? tipoProductoNombre,
    String? seguimiento,
    String? unidadProductoId,
    String? unidadProductoNombre,
    double? stockActual,
    double? stockMinimo,
    double? costoPromedio,
    double? costoReposicion,
    double? precioCliente,
    String? notas,
    bool? estado,
    String? sedeId,
  }) =>
      ProductoInventario(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        tipoProductoId: tipoProductoId ?? this.tipoProductoId,
        tipoProductoNombre: tipoProductoNombre ?? this.tipoProductoNombre,
        seguimiento: seguimiento ?? this.seguimiento,
        unidadProductoId: unidadProductoId ?? this.unidadProductoId,
        unidadProductoNombre: unidadProductoNombre ?? this.unidadProductoNombre,
        stockActual: stockActual ?? this.stockActual,
        stockMinimo: stockMinimo ?? this.stockMinimo,
        costoPromedio: costoPromedio ?? this.costoPromedio,
        costoReposicion: costoReposicion ?? this.costoReposicion,
        precioCliente: precioCliente ?? this.precioCliente,
        notas: notas ?? this.notas,
        estado: estado ?? this.estado,
        sedeId: sedeId ?? this.sedeId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
