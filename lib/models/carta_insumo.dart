// Refleja la tabla `carta_insumo`: la "receta" de un plato — qué producto
// de inventario consume y cuánto por unidad vendida.
// `cantidadEstandar` es null cuando `esVariable` es true (la cantidad real
// se registra al momento de la venta, no sigue una receta fija).
class CartaInsumo {
  final String id;
  final String cartaId;
  final String productoInventarioId;
  final double? cantidadEstandar;
  final bool esVariable;

  const CartaInsumo({
    required this.id,
    required this.cartaId,
    required this.productoInventarioId,
    this.cantidadEstandar,
    required this.esVariable,
  });
}
