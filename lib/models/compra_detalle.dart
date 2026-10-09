import '../utils/json_num.dart';

// Refleja la tabla `compra_detalle`: historial de lo comprado. El factor puede
// cambiar de una compra a otra, por eso se guarda en cada línea.
class CompraDetalle {
  final String id;
  final String compraId;
  final String productoInventarioId;
  // Cantidad en la unidad en que se compró (ej. 10 galones).
  final double cantidad;
  final String unidadProductoId;
  // Cuántas unidades base trae 1 unidad de compra (ej. 1 galón = 5 litros).
  final double factorABase;
  // cantidad × factorABase, en la unidad base del producto (10 × 5 = 50 litros).
  // La calcula el backend; en el formulario solo se muestra como vista previa.
  final double cantidadBase;
  final double precioUnitario; // por unidad de compra
  final double precioTotal;
  final double costoUnitarioBase; // precioTotal / cantidadBase
  final String? notas;

  const CompraDetalle({
    required this.id,
    required this.compraId,
    required this.productoInventarioId,
    required this.cantidad,
    required this.unidadProductoId,
    this.factorABase = 1,
    required this.cantidadBase,
    required this.precioUnitario,
    required this.precioTotal,
    required this.costoUnitarioBase,
    this.notas,
  });

  factory CompraDetalle.fromJson(Map<String, dynamic> json) => CompraDetalle(
    id: json['id']?.toString() ?? '',
    compraId: json['compra_id']?.toString() ?? '',
    productoInventarioId: json['producto_inventario_id']?.toString() ?? '',
    cantidad: jsonDouble(json['cantidad']) ?? 0,
    unidadProductoId: json['unidad_producto_id']?.toString() ?? '',
    factorABase: jsonDouble(json['factor_a_base']) ?? 1,
    cantidadBase: jsonDouble(json['cantidad_base']) ?? 0,
    precioUnitario: jsonDouble(json['precio_unitario']) ?? 0,
    precioTotal: jsonDouble(json['precio_total']) ?? 0,
    costoUnitarioBase: jsonDouble(json['costo_unitario_base']) ?? 0,
    notas: json['notas']?.toString(),
  );

  // Lo que se envía al registrar: `cantidad_base` y `costo_unitario_base` los
  // calcula el backend.
  Map<String, dynamic> toJson() => {
    'producto_inventario_id': productoInventarioId,
    'cantidad': cantidad,
    'unidad_producto_id': unidadProductoId,
    'factor_a_base': factorABase,
    'precio_unitario': precioUnitario,
    'precio_total': precioTotal,
    'notas': notas,
  };
}
