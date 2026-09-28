import '../models/categoria_comida.dart';

// Categorías de la carta (tabla `categorias`), ordenadas por `orden`. Se
// cargan desde el backend.
final List<CategoriaComida> mockCategorias = [];

int siguienteOrdenCategoria() => mockCategorias.isEmpty
    ? 1
    : mockCategorias.map((c) => c.orden).reduce((a, b) => a > b ? a : b) + 1;

CategoriaComida agregarCategoria(String nombre, {int? orden}) {
  final cat = CategoriaComida(
    id: 'cat${DateTime.now().microsecondsSinceEpoch}',
    categoria: nombre,
    orden: orden ?? siguienteOrdenCategoria(),
    creadoEn: DateTime.now(),
  );
  mockCategorias
    ..add(cat)
    ..sort((a, b) => a.orden.compareTo(b.orden));
  return cat;
}

void renombrarCategoria(String id, String nuevoNombre) {
  final index = mockCategorias.indexWhere((c) => c.id == id);
  if (index == -1) return;
  final actual = mockCategorias[index];
  mockCategorias[index] = CategoriaComida(
    id: actual.id,
    categoria: nuevoNombre,
    orden: actual.orden,
    creadoEn: actual.creadoEn,
  );
}
