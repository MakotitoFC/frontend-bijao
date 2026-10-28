// Qué se imprime en la comanda de cocina. Por defecto sale todo; el
// administrador apaga categorías enteras y, dentro de ellas, marca los platos
// que sí (o no) deben salir. Por ejemplo: bebidas no van a cocina, salvo la
// limonada y el aguaje, que se preparan allí.
class ReglasCocina {
  // `categoria_id` → true/false. Sin dato: la categoría sí se imprime.
  final Map<String, bool> categorias;
  // `carta_id` → true/false. Es una excepción a la regla de su categoría; sin
  // dato, el plato sigue a su categoría.
  final Map<String, bool> platos;

  const ReglasCocina({this.categorias = const {}, this.platos = const {}});

  bool imprimeCategoria(String categoriaId) => categorias[categoriaId] ?? true;

  // ¿Sale este plato en la comanda? Primero su excepción; si no tiene, la regla
  // de su categoría.
  bool imprimePlato(String cartaId, String categoriaId) =>
      platos[cartaId] ?? imprimeCategoria(categoriaId);

  ReglasCocina copia() =>
      ReglasCocina(categorias: Map.of(categorias), platos: Map.of(platos));

  factory ReglasCocina.fromJson(Map<String, dynamic> json) {
    Map<String, bool> leer(Object? lista, String clave) => {
      if (lista is List)
        for (final j in lista.whereType<Map<String, dynamic>>())
          if (j[clave] != null && j['imprime'] is bool)
            j[clave].toString(): j['imprime'] as bool,
    };
    return ReglasCocina(
      categorias: leer(json['categorias'], 'categoria_id'),
      platos: leer(json['platos'], 'carta_id'),
    );
  }

  // Cuerpo para el servidor. Solo viajan las categorías apagadas y las
  // excepciones de platos; lo demás es el valor por defecto.
  Map<String, dynamic> toJson() => {
    'categorias': [
      for (final e in categorias.entries)
        {'categoria_id': e.key, 'imprime': e.value},
    ],
    'platos': [
      for (final e in platos.entries) {'carta_id': e.key, 'imprime': e.value},
    ],
  };

  @override
  bool operator ==(Object other) =>
      other is ReglasCocina &&
      _igual(categorias, other.categorias) &&
      _igual(platos, other.platos);

  @override
  int get hashCode => Object.hash(categorias.length, platos.length);

  static bool _igual(Map<String, bool> a, Map<String, bool> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}
