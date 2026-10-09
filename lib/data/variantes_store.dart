import '../models/carta_variante.dart';

// Tamaños con precio propio por plato (tabla `carta_variante`).
// Se cargan con `CatalogService.cargarVariantes` y se guardan junto con el
// plato (`crearPlato` / `actualizarPlato`).
final List<CartaVariante> variantes = [];

// Variantes de un plato; con [soloActivas] se omiten las desactivadas.
List<CartaVariante> variantesDeCarta(
  String cartaId, {
  bool soloActivas = false,
}) => variantes
    .where((v) => v.cartaId == cartaId && (!soloActivas || v.estado))
    .toList();

// Reemplaza todas las variantes de un plato por [nuevas] (al guardar el
// formulario del producto).
void reemplazarVariantesDeCarta(String cartaId, List<CartaVariante> nuevas) {
  variantes
    ..removeWhere((v) => v.cartaId == cartaId)
    ..addAll(nuevas);
}

void eliminarVariantesDeCarta(String cartaId) =>
    variantes.removeWhere((v) => v.cartaId == cartaId);

// Precio público más bajo entre las variantes activas (null si no hay).
double? precioMinimoDeVariantes(String cartaId) {
  final precios = variantesDeCarta(
    cartaId,
    soloActivas: true,
  ).map((v) => v.precioCliente);
  if (precios.isEmpty) return null;
  return precios.reduce((a, b) => a < b ? a : b);
}
