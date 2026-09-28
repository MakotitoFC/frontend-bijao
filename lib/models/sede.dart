// Refleja la tabla `sede` de la BD (Supabase). No tiene columna "nombre",
// por eso la UI usa `direccion` como etiqueta visible para identificar la sede.
class Sede {
  final String id;
  final String ruc;
  final String direccion;
  final String? celular;
  final bool activo; // restaurantes.activo

  const Sede({
    required this.id,
    required this.ruc,
    required this.direccion,
    this.celular,
    this.activo = true,
  });

  Sede copyWith({String? direccion, String? celular, bool? activo}) => Sede(
    id: id,
    ruc: ruc,
    direccion: direccion ?? this.direccion,
    celular: celular ?? this.celular,
    activo: activo ?? this.activo,
  );
}
