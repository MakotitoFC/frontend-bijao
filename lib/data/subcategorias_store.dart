import '../models/subcategoria.dart';

// Subcategorías de la carta (tabla `subcategoria`). Se cargan y guardan con
// `CatalogService` (/api/subcategorias).
final List<Subcategoria> subcategorias = [];

// Subcategorías de una categoría; con [soloActivas] se omiten las inactivas.
List<Subcategoria> subcategoriasDe(
  String categoriaId, {
  bool soloActivas = false,
}) => subcategorias
    .where(
      (s) => s.categoriaComidaId == categoriaId && (!soloActivas || s.estado),
    )
    .toList();

Subcategoria? subcategoriaPorId(String? id) {
  if (id == null) return null;
  for (final s in subcategorias) {
    if (s.id == id) return s;
  }
  return null;
}

String nombreDeSubcategoria(String? id) =>
    subcategoriaPorId(id)?.subcategoria ?? '';

bool existeSubcategoria(String categoriaId, String nombre, {String? salvo}) =>
    subcategorias.any(
      (s) =>
          s.categoriaComidaId == categoriaId &&
          s.id != salvo &&
          s.subcategoria.toLowerCase() == nombre.trim().toLowerCase(),
    );
