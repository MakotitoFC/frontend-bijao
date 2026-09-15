// Refleja la tabla `modificador`.
class Modificador {
  final String id;
  final String cartaId;
  final String nombre;
  final String tipo; // 'agregar' | 'quitar'
  final double precioAjuste;

  const Modificador({
    required this.id,
    required this.cartaId,
    required this.nombre,
    required this.tipo,
    required this.precioAjuste,
  });
}
