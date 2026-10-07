class TipoSeguimiento {
  final String id;
  final String tipoSeguimiento;
  final bool estado;
  final String? sedeId;

  const TipoSeguimiento({
    required this.id,
    required this.tipoSeguimiento,
    this.estado = true,
    this.sedeId,
  });

  factory TipoSeguimiento.fromJson(Map<String, dynamic> json) => TipoSeguimiento(
        id: json['id']?.toString() ?? '',
        tipoSeguimiento: json['tipo_seguimiento']?.toString() ?? '',
        estado: json['estado'] != false,
        sedeId: json['sede_id']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo_seguimiento': tipoSeguimiento,
        'estado': estado,
        'sede_id': sedeId,
      };
}
