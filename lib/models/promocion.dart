import '../utils/json_num.dart';

// Refleja la tabla `promocion`. El precio de una promoción no es fijo: se arma
// con las opciones de sus componentes y, si hay `porcentajeDescuento`, se aplica
// a las opciones que no traen precio propio.
class Promocion {
  final String id;
  final String nombre;
  final String? descripcion;
  // Descuento (%) sobre el precio normal de las opciones sin precio propio.
  final double? porcentajeDescuento;
  // La promoción se mantiene cuando el cliente pide un cambio: si es false, el
  // producto cambiado se cobra a su precio normal.
  final bool seMantiene;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final bool estado;
  final String? sedeId;

  const Promocion({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.porcentajeDescuento,
    this.seMantiene = true,
    this.fechaInicio,
    this.fechaFin,
    this.estado = true,
    this.sedeId,
  });

  // Activa y dentro de su vigencia (si la tiene).
  bool get vigente {
    if (!estado) return false;
    final ahora = DateTime.now();
    if (fechaInicio != null && ahora.isBefore(fechaInicio!)) return false;
    if (fechaFin != null && ahora.isAfter(fechaFin!)) return false;
    return true;
  }

  String get etiqueta =>
      porcentajeDescuento != null && porcentajeDescuento! > 0
      ? '-${porcentajeDescuento!.toStringAsFixed(porcentajeDescuento! % 1 == 0 ? 0 : 1)}%'
      : 'Combo';

  factory Promocion.fromJson(Map<String, dynamic> json) => Promocion(
    id: json['id']?.toString() ?? '',
    nombre: json['nombre']?.toString() ?? '',
    descripcion: json['descripcion']?.toString(),
    porcentajeDescuento: jsonDouble(json['porcentaje_descuento']),
    seMantiene: json['se_mantiene'] == true,
    fechaInicio: DateTime.tryParse(json['fecha_inicio']?.toString() ?? ''),
    fechaFin: DateTime.tryParse(json['fecha_fin']?.toString() ?? ''),
    estado: json['estado'] != false,
    sedeId: json['sede_id']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
    'porcentaje_descuento': porcentajeDescuento,
    'se_mantiene': seMantiene,
    'fecha_inicio': fechaInicio?.toIso8601String(),
    'fecha_fin': fechaFin?.toIso8601String(),
    'estado': estado,
    'sede_id': sedeId,
  };

  Promocion copyWith({
    String? nombre,
    String? descripcion,
    double? porcentajeDescuento,
    bool quitarPorcentaje = false,
    bool? seMantiene,
    DateTime? fechaInicio,
    bool quitarFechaInicio = false,
    DateTime? fechaFin,
    bool quitarFechaFin = false,
    bool? estado,
  }) => Promocion(
    id: id,
    nombre: nombre ?? this.nombre,
    descripcion: descripcion ?? this.descripcion,
    porcentajeDescuento: quitarPorcentaje
        ? null
        : (porcentajeDescuento ?? this.porcentajeDescuento),
    seMantiene: seMantiene ?? this.seMantiene,
    fechaInicio: quitarFechaInicio ? null : (fechaInicio ?? this.fechaInicio),
    fechaFin: quitarFechaFin ? null : (fechaFin ?? this.fechaFin),
    estado: estado ?? this.estado,
    sedeId: sedeId,
  );
}
