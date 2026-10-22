// Refleja la tabla `unidad_bebida`.
class UnidadBebida {
  final String id;
  final String unidadPresentacion;
  final bool estado;

  const UnidadBebida({
    required this.id,
    required this.unidadPresentacion,
    this.estado = true,
  });

  factory UnidadBebida.fromJson(Map<String, dynamic> json) => UnidadBebida(
    id: json['id']?.toString() ?? '',
    unidadPresentacion: json['unidad_presentacion']?.toString() ?? '',
    estado: json['estado'] != false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'unidad_presentacion': unidadPresentacion,
    'estado': estado,
  };
}

// Envases para elegir: solo los activos y sin repetir el mismo nombre (la base
// puede traer, por ejemplo, dos "Jarra").
List<UnidadBebida> unidadesParaElegir(Iterable<UnidadBebida> todas) {
  final vistos = <String>{};
  return [
    for (final u in todas)
      if (u.estado && vistos.add(u.unidadPresentacion.trim().toLowerCase())) u,
  ];
}

// El id, entre [opciones], de la unidad que tiene el mismo nombre que [id]
// (por si el elegido era una de las repetidas). Null si no hay equivalente.
String? idDeOpcion(
  List<UnidadBebida> opciones,
  Iterable<UnidadBebida> todas,
  String? id,
) {
  final actual = todas.where((u) => u.id == id).firstOrNull;
  if (actual == null) return null;
  final nombre = actual.unidadPresentacion.trim().toLowerCase();
  return opciones
      .where((o) => o.unidadPresentacion.trim().toLowerCase() == nombre)
      .firstOrNull
      ?.id;
}
