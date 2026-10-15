import '../utils/json_num.dart';

class Taper {
  final String id;
  final String nombre;
  final double precio;
  final bool estado;
  final String? sedeId;
  // El stock del táper se lleva en inventario: el backend lo enlaza a un
  // `producto_inventario` y devuelve su stock actual y mínimo.
  final String? productoInventarioId;
  final double stock;
  final double stockMinimo;

  const Taper({
    required this.id,
    required this.nombre,
    required this.precio,
    this.estado = true,
    this.sedeId,
    this.productoInventarioId,
    this.stock = 0,
    this.stockMinimo = 0,
  });

  bool get stockBajo => stock <= stockMinimo;

  factory Taper.fromJson(Map<String, dynamic> json) {
    return Taper(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? '',
      precio: jsonDouble(json['precio']) ?? 0.0,
      estado: json['estado'] as bool? ?? true,
      sedeId: json['sede_id'] as String?,
      productoInventarioId: json['producto_inventario_id'] as String?,
      stock: jsonDouble(json['stock']) ?? 0,
      stockMinimo: jsonDouble(json['stock_minimo']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'precio': precio,
    'estado': estado,
    if (sedeId != null) 'sede_id': sedeId,
  };
}
