class TipoProducto {
  final String id;
  final String tipoProducto;
  final bool esIngrediente;
  final bool estado;
  final String? sedeId;

  const TipoProducto({
    required this.id,
    required this.tipoProducto,
    this.esIngrediente = false,
    this.estado = true,
    this.sedeId,
  });

  factory TipoProducto.fromJson(Map<String, dynamic> json) => TipoProducto(
        id: json['id']?.toString() ?? '',
        tipoProducto: json['tipo_producto']?.toString() ?? '',
        esIngrediente: json['es_ingrediente'] == true,
        estado: json['estado'] != false,
        sedeId: json['sede_id']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo_producto': tipoProducto,
        'es_ingrediente': esIngrediente,
        'estado': estado,
        'sede_id': sedeId,
      };
}
