import '../utils/json_num.dart';

// Un producto de la carta que descuenta stock de un producto de inventario en
// cada venta (tabla `carta_insumo` del backend, modo "estándar").
class VinculoCarta {
  final String id;
  final String cartaId;
  final String cartaNombre;
  final String productoInventarioId;
  final String productoNombre;
  // Cuánto se descuenta del producto de inventario por cada unidad vendida.
  final double cantidad;
  // Los vínculos por presentación o variante no se editan desde el producto.
  final bool generalDelProducto;

  const VinculoCarta({
    required this.id,
    required this.cartaId,
    required this.cartaNombre,
    required this.productoInventarioId,
    required this.productoNombre,
    required this.cantidad,
    this.generalDelProducto = true,
  });

  factory VinculoCarta.fromJson(Map<String, dynamic> json) => VinculoCarta(
    id: json['id']?.toString() ?? '',
    cartaId: json['carta_id']?.toString() ?? '',
    cartaNombre: json['carta_nombre']?.toString() ?? '',
    productoInventarioId: json['producto_inventario_id']?.toString() ?? '',
    productoNombre: json['producto_nombre']?.toString() ?? '',
    cantidad: jsonDouble(json['cantidad_estandar']) ?? 1,
    generalDelProducto:
        json['carta_presentacion_id'] == null &&
        json['carta_variante_id'] == null &&
        (json['modo']?.toString() ?? 'estandar') == 'estandar',
  );
}
