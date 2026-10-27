class Turno {
  final String id;
  final String sedeId;
  final String nombre;
  final String horaInicio;
  final String horaFin;
  final int orden;
  final bool estado;

  const Turno({
    required this.id,
    required this.sedeId,
    required this.nombre,
    required this.horaInicio,
    required this.horaFin,
    required this.orden,
    required this.estado,
  });

  factory Turno.fromJson(Map<String, dynamic> json) => Turno(
        id: json['id']?.toString() ?? '',
        sedeId: json['sede_id']?.toString() ?? '',
        nombre: json['nombre']?.toString() ?? '',
        horaInicio: json['hora_inicio']?.toString() ?? '00:00',
        horaFin: json['hora_fin']?.toString() ?? '23:59',
        orden: (json['orden'] as num?)?.toInt() ?? 1,
        estado: json['estado'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sede_id': sedeId,
        'nombre': nombre,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'orden': orden,
        'estado': estado,
      };
}
