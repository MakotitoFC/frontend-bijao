// Refleja la tabla `categorias` (esquema real en Supabase): nombre, orden y
// created_at. `restaurante_id` lo asigna el backend.
class CategoriaComida {
  final String id;
  final String categoria; // categorias.nombre
  final int orden; // categorias.orden (menor va primero)
  final DateTime? creadoEn; // categorias.created_at

  const CategoriaComida({
    required this.id,
    required this.categoria,
    this.orden = 0,
    this.creadoEn,
  });
}
