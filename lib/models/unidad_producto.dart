class UnidadProducto {
  final String id;
  final String unidad;
  final bool estado;
  final String? sedeId;

  const UnidadProducto({
    required this.id,
    required this.unidad,
    this.estado = true,
    this.sedeId,
  });

  factory UnidadProducto.fromJson(Map<String, dynamic> json) => UnidadProducto(
        id: json['id']?.toString() ?? '',
        unidad: json['unidad']?.toString() ?? '',
        estado: json['estado'] != false,
        sedeId: json['sede_id']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'unidad': unidad,
        'estado': estado,
        'sede_id': sedeId,
      };
}
