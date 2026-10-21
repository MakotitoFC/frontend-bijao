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
