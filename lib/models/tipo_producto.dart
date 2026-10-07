class TipoProducto {
  final String id;
  final String tipoProducto;
  final bool estado;
  final String? sedeId;

  const TipoProducto({
    required this.id,
    required this.tipoProducto,
    this.estado = true,
    this.sedeId,
  });

  factory TipoProducto.fromJson(Map<String, dynamic> json) => TipoProducto(
        id: json['id']?.toString() ?? '',
        tipoProducto: json['tipo_producto']?.toString() ?? '',
        estado: json['estado'] != false,
        sedeId: json['sede_id']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo_producto': tipoProducto,
        'estado': estado,
        'sede_id': sedeId,
      };
}
