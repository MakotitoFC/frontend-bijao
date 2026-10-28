// Refleja la tabla `sede` de la BD: todas sus columnas, menos el id y las
// fechas de creación y actualización. No tiene columna "nombre", por eso la UI
// usa `direccion` como etiqueta visible para identificar la sede.
class Sede {
  final String id;
  final String ruc;
  final String razonSocial;
  final String direccion;
  final String? celular;
  // Letra de la serie de los comprobantes de la sede (1 carácter).
  final String codigoSerie;
  final double igvPorcentaje;
  final String resolucionSunat;
  final String consultaSunatUrl;
  final String logoUrl;

  const Sede({
    required this.id,
    required this.ruc,
    this.razonSocial = '',
    required this.direccion,
    this.celular,
    this.codigoSerie = 'A',
    this.igvPorcentaje = 18,
    this.resolucionSunat = '',
    this.consultaSunatUrl = '',
    this.logoUrl = '',
  });

  Sede copyWith({
    String? ruc,
    String? razonSocial,
    String? direccion,
    String? celular,
    String? codigoSerie,
    double? igvPorcentaje,
    String? resolucionSunat,
    String? consultaSunatUrl,
    String? logoUrl,
  }) => Sede(
    id: id,
    ruc: ruc ?? this.ruc,
    razonSocial: razonSocial ?? this.razonSocial,
    direccion: direccion ?? this.direccion,
    celular: celular ?? this.celular,
    codigoSerie: codigoSerie ?? this.codigoSerie,
    igvPorcentaje: igvPorcentaje ?? this.igvPorcentaje,
    resolucionSunat: resolucionSunat ?? this.resolucionSunat,
    consultaSunatUrl: consultaSunatUrl ?? this.consultaSunatUrl,
    logoUrl: logoUrl ?? this.logoUrl,
  );
}
