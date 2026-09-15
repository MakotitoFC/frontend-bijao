// Refleja la tabla `carta` (platos/bebidas del menú).
// `precioCliente` es null cuando el ítem se vende por presentaciones
// (ver `carta_presentacion`, ej. bebidas por vaso/botella).
class CartaItem {
  final String id;
  final String nombrePlato;
  final String descripcion;
  final String categoriaId;
  final String? taperId;
  final double? precioCliente;
  final double? precioPersonal;
  final String estado; // 'activo' | 'inactivo'

  const CartaItem({
    required this.id,
    required this.nombrePlato,
    required this.descripcion,
    required this.categoriaId,
    this.taperId,
    this.precioCliente,
    this.precioPersonal,
    this.estado = 'activo',
  });
}
