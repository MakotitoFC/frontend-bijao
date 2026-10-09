// Refleja la tabla `compra` (fecha, notas; el usuario y la sede los completa el
// backend desde la sesión). El total no es una columna: es la suma de sus
// detalles y se calcula en la app.
class Compra {
  final String id;
  final DateTime fechaCompra;
  final double total;
  final String? notas;
  // false mientras es un borrador: aún no se guardó en el backend. El backend
  // recibe la compra junto con todos sus detalles en un solo envío.
  final bool guardada;

  const Compra({
    required this.id,
    required this.fechaCompra,
    required this.total,
    this.notas,
    this.guardada = true,
  });

  // `fecha_compra` es una fecha (sin hora): se toman solo año, mes y día para
  // que no se corra de día por la zona horaria.
  factory Compra.fromJson(Map<String, dynamic> json) {
    final fecha = DateTime.tryParse(json['fecha_compra']?.toString() ?? '');
    return Compra(
      id: json['id']?.toString() ?? '',
      fechaCompra: fecha == null
          ? DateTime.now()
          : DateTime(fecha.year, fecha.month, fecha.day),
      total: 0,
      notas: json['notas']?.toString(),
    );
  }

  Compra copyWith({double? total, bool? guardada}) => Compra(
    id: id,
    fechaCompra: fechaCompra,
    total: total ?? this.total,
    notas: notas,
    guardada: guardada ?? this.guardada,
  );

  // El backend lee `fecha_compra` como fecha-hora (RFC 3339).
  Map<String, dynamic> toJson() => {
    'id': id,
    'fecha_compra':
        '${fechaCompra.year.toString().padLeft(4, '0')}-'
        '${fechaCompra.month.toString().padLeft(2, '0')}-'
        '${fechaCompra.day.toString().padLeft(2, '0')}T00:00:00Z',
    if (notas != null) 'notas': notas,
  };
}
