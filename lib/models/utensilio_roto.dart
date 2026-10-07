// Refleja la tabla `utensilio_roto` según BD.txt.
class UtensilioRoto {
  final String id;
  final String productoInventarioId;
  final String? productoNombre;
  final String empleadoId;
  final String? empleadoNombre;
  final int cantidad;
  final double costoTotal;
  final String? usuarioId;
  final String? usuarioNombre;
  final DateTime fecha;
  final String? notas;
  final bool isPagado;
  final bool isRepuesto;
  final bool done;
  final double totalPagado;
  final DateTime? createdAt;

  const UtensilioRoto({
    required this.id,
    required this.productoInventarioId,
    this.productoNombre,
    required this.empleadoId,
    this.empleadoNombre,
    required this.cantidad,
    required this.costoTotal,
    this.usuarioId,
    this.usuarioNombre,
    required this.fecha,
    this.notas,
    this.isPagado = false,
    this.isRepuesto = false,
    this.done = false,
    this.totalPagado = 0.0,
    this.createdAt,
  });

  bool get isRespuesto => isRepuesto; // alias para compatibilidad

  factory UtensilioRoto.fromJson(Map<String, dynamic> json) => UtensilioRoto(
        id: json['id']?.toString() ?? '',
        productoInventarioId: json['producto_inventario_id']?.toString() ?? '',
        productoNombre: json['producto_nombre']?.toString(),
        empleadoId: json['empleado_id']?.toString() ?? '',
        empleadoNombre: json['empleado_nombre']?.toString(),
        cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
        costoTotal: (json['costo_total'] as num?)?.toDouble() ?? 0.0,
        usuarioId: json['usuario_id']?.toString(),
        usuarioNombre: json['usuario_nombre']?.toString(),
        fecha: json['fecha'] != null
            ? DateTime.tryParse(json['fecha'].toString()) ?? DateTime.now()
            : DateTime.now(),
        notas: json['notas']?.toString(),
        isPagado: json['is_pagado'] == true,
        isRepuesto: json['is_repuesto'] == true || json['is_respuesto'] == true,
        done: json['done'] == true,
        totalPagado: (json['total_pagado'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'producto_inventario_id': productoInventarioId,
        'empleado_id': empleadoId,
        'cantidad': cantidad,
        'costo_total': costoTotal,
        'usuario_id': usuarioId,
        'notas': notas,
        'is_pagado': isPagado,
        'is_repuesto': isRepuesto,
        'done': done,
      };

  UtensilioRoto copyWith({
    String? id,
    String? productoInventarioId,
    String? productoNombre,
    String? empleadoId,
    String? empleadoNombre,
    int? cantidad,
    double? costoTotal,
    String? usuarioId,
    String? usuarioNombre,
    DateTime? fecha,
    String? notas,
    bool? isPagado,
    bool? isRepuesto,
    bool? isRespuesto,
    bool? done,
    double? totalPagado,
  }) =>
      UtensilioRoto(
        id: id ?? this.id,
        productoInventarioId:
            productoInventarioId ?? this.productoInventarioId,
        productoNombre: productoNombre ?? this.productoNombre,
        empleadoId: empleadoId ?? this.empleadoId,
        empleadoNombre: empleadoNombre ?? this.empleadoNombre,
        cantidad: cantidad ?? this.cantidad,
        costoTotal: costoTotal ?? this.costoTotal,
        usuarioId: usuarioId ?? this.usuarioId,
        usuarioNombre: usuarioNombre ?? this.usuarioNombre,
        fecha: fecha ?? this.fecha,
        notas: notas ?? this.notas,
        isPagado: isPagado ?? this.isPagado,
        isRepuesto: isRepuesto ?? isRespuesto ?? this.isRepuesto,
        done: done ?? this.done,
        totalPagado: totalPagado ?? this.totalPagado,
        createdAt: createdAt,
      );
}
