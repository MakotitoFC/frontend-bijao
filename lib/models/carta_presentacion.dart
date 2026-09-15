import 'unidad_bebida.dart';

// Refleja la tabla `carta_presentacion` (ej. bebidas por vaso/botella/jarra).
class CartaPresentacion {
  final String id;
  final String cartaId;
  final UnidadBebida unidad;
  final int volumenMl;
  final double precioCliente;

  const CartaPresentacion({
    required this.id,
    required this.cartaId,
    required this.unidad,
    required this.volumenMl,
    required this.precioCliente,
  });
}
