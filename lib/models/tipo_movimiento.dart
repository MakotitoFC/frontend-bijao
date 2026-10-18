// Refleja la tabla `tipo_movimiento`: el `signo` dice si suma (+1) o resta (-1)
// del stock. Los ids son UUID fijos del backend.
class TipoMovimiento {
  final String id;
  final String codigo;
  final String tipoMovimiento;
  final int signo; // 1 = entrada, -1 = salida o merma
  final bool estado;

  const TipoMovimiento({
    required this.id,
    this.codigo = '',
    required this.tipoMovimiento,
    required this.signo,
    this.estado = true,
  });

  bool get esEntrada => signo > 0;

  // Dos tipos son el mismo si tienen el mismo id (el catálogo se vuelve a leer
  // del backend y las instancias cambian).
  @override
  bool operator ==(Object other) => other is TipoMovimiento && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory TipoMovimiento.fromJson(Map<String, dynamic> json) => TipoMovimiento(
    id: json['id']?.toString() ?? '',
    codigo: json['codigo']?.toString() ?? '',
    tipoMovimiento: json['tipo_movimiento']?.toString() ?? '',
    signo: (json['signo'] as num?)?.toInt() ?? 1,
    estado: json['estado'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'codigo': codigo,
    'tipo_movimiento': tipoMovimiento,
    'signo': signo,
    'estado': estado,
  };
}
