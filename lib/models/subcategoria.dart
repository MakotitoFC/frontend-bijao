// Refleja la tabla `subcategoria`: divide una categoría de la carta (ej. en la
// categoría "Platos": Segundo, Entrada, Snack). Los componentes de una
// promoción dependen de una subcategoría.
class Subcategoria {
  final String id;
  final String subcategoria;
  final bool estado;
  final String categoriaComidaId;

  const Subcategoria({
    required this.id,
    required this.subcategoria,
    required this.categoriaComidaId,
    this.estado = true,
  });

  factory Subcategoria.fromJson(Map<String, dynamic> json) => Subcategoria(
    id: json['id']?.toString() ?? '',
    subcategoria: json['subcategoria']?.toString() ?? '',
    categoriaComidaId: json['categoria_comida_id']?.toString() ?? '',
    estado: json['estado'] != false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'subcategoria': subcategoria,
    'estado': estado,
    'categoria_comida_id': categoriaComidaId,
  };

  Subcategoria copyWith({String? subcategoria, bool? estado}) => Subcategoria(
    id: id,
    subcategoria: subcategoria ?? this.subcategoria,
    categoriaComidaId: categoriaComidaId,
    estado: estado ?? this.estado,
  );
}
