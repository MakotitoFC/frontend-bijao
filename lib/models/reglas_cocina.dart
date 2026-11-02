// Qué se imprime en la comanda de cocina. Por defecto sale todo; el
// administrador apaga subcategorías enteras y, dentro de ellas, marca los platos
// que sí (o no) deben salir. Por ejemplo: bebidas no van a cocina, salvo la
// limonada y el aguaje, que se preparan allí. También se puede ajustar si los
// tápers salen o no en comanda de cocina.
class ReglasCocina {
  // `subcategoria_id` → true/false. Sin dato: la subcategoría sí se imprime.
  final Map<String, bool> subcategorias;
  // `categoria_id` → true/false (retrocompatibilidad).
  final Map<String, bool> categorias;
  // `carta_id` → true/false. Es una excepción a la regla de su subcategoría;
  // sin dato, el plato sigue a su subcategoría.
  final Map<String, bool> platos;
  // Interruptor general de tápers en cocina.
  final bool imprimeTapers;

  const ReglasCocina({
    this.subcategorias = const {},
    this.categorias = const {},
    this.platos = const {},
    this.imprimeTapers = true,
  });

  bool imprimeSubcategoria(String subcategoriaId) =>
      subcategorias[subcategoriaId] ?? true;

  bool imprimeCategoria(String categoriaId) =>
      categorias[categoriaId] ?? true;

  // ¿Sale este plato en la comanda?
  // 1. Excepción propia del plato.
  // 2. Si no tiene excepción, regla de su subcategoría.
  // 3. Si no tiene subcategoría o regla, regla de su categoría.
  bool imprimePlato(
    String cartaId, {
    String? subcategoriaId,
    String? categoriaId,
  }) {
    if (platos.containsKey(cartaId)) {
      return platos[cartaId]!;
    }
    if (subcategoriaId != null && subcategorias.containsKey(subcategoriaId)) {
      return subcategorias[subcategoriaId]!;
    }
    if (categoriaId != null && categorias.containsKey(categoriaId)) {
      return categorias[categoriaId]!;
    }
    return true;
  }

  ReglasCocina copia({
    Map<String, bool>? subcategorias,
    Map<String, bool>? categorias,
    Map<String, bool>? platos,
    bool? imprimeTapers,
  }) => ReglasCocina(
    subcategorias: subcategorias ?? Map.of(this.subcategorias),
    categorias: categorias ?? Map.of(this.categorias),
    platos: platos ?? Map.of(this.platos),
    imprimeTapers: imprimeTapers ?? this.imprimeTapers,
  );

  factory ReglasCocina.fromJson(Map<String, dynamic> json) {
    Map<String, bool> leer(Object? lista, String clave) => {
      if (lista is List)
        for (final j in lista.whereType<Map<String, dynamic>>())
          if (j[clave] != null && j['imprime'] is bool)
            j[clave].toString(): j['imprime'] as bool,
    };
    return ReglasCocina(
      subcategorias: leer(json['subcategorias'], 'subcategoria_id'),
      categorias: leer(json['categorias'], 'categoria_id'),
      platos: leer(json['platos'], 'carta_id'),
      imprimeTapers: json['imprime_tapers'] is bool
          ? json['imprime_tapers'] as bool
          : true,
    );
  }

  Map<String, dynamic> toJson() => {
    'subcategorias': [
      for (final e in subcategorias.entries)
        {'subcategoria_id': e.key, 'imprime': e.value},
    ],
    'categorias': [
      for (final e in categorias.entries)
        {'categoria_id': e.key, 'imprime': e.value},
    ],
    'platos': [
      for (final e in platos.entries) {'carta_id': e.key, 'imprime': e.value},
    ],
    'imprime_tapers': imprimeTapers,
  };

  @override
  bool operator ==(Object other) =>
      other is ReglasCocina &&
      _igual(subcategorias, other.subcategorias) &&
      _igual(categorias, other.categorias) &&
      _igual(platos, other.platos) &&
      imprimeTapers == other.imprimeTapers;

  @override
  int get hashCode => Object.hash(
    subcategorias.length,
    categorias.length,
    platos.length,
    imprimeTapers,
  );

  static bool _igual(Map<String, bool> a, Map<String, bool> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}
