import '../models/categoria_comida.dart';

// Categorías de la carta (tabla `categorias`), ordenadas por `orden`. Se
// cargan desde el backend.
final List<CategoriaComida> categorias = [];

int siguienteOrdenCategoria() {
  final ordenes = categorias.map((c) => c.orden);
  return ordenes.isEmpty ? 1 : ordenes.reduce((a, b) => a > b ? a : b) + 1;
}

CategoriaComida agregarCategoria(String nombre, {int? orden}) {
  final cat = CategoriaComida(
    id: 'cat${DateTime.now().microsecondsSinceEpoch}',
    categoria: nombre,
    orden: orden ?? siguienteOrdenCategoria(),
    creadoEn: DateTime.now(),
  );
  categorias
    ..add(cat)
    ..sort((a, b) => a.orden.compareTo(b.orden));
  return cat;
}

void renombrarCategoria(String id, String nuevoNombre) {
  final index = categorias.indexWhere((c) => c.id == id);
  if (index == -1) return;
  final actual = categorias[index];
  categorias[index] = CategoriaComida(
    id: actual.id,
    categoria: nuevoNombre,
    orden: actual.orden,
    creadoEn: actual.creadoEn,
  );
}
