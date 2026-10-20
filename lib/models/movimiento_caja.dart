import '../utils/json_num.dart';

// Un ingreso o una salida de dinero de la caja que no es la venta de un pedido
// (por ejemplo, comprar hielo o retirar efectivo). Tabla `movimiento`.
enum TipoMovimiento {
  ingreso('I', 'Ingreso'),
  egreso('E', 'Salida');

  final String codigo;
  final String etiqueta;
  const TipoMovimiento(this.codigo, this.etiqueta);

  static TipoMovimiento deCodigo(String? c) =>
      c == 'E' ? TipoMovimiento.egreso : TipoMovimiento.ingreso;
}

// Categoría de un movimiento (`categoria_movimiento`): dice si es ingreso o
// salida y para qué fue ("Compra de insumos", "Retiro de efectivo"...).
class CategoriaMovimiento {
  final String id;
  final String nombre;
  final TipoMovimiento tipo;
  final bool activo;

  const CategoriaMovimiento({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.activo = true,
  });

  factory CategoriaMovimiento.fromJson(Map<String, dynamic> json) =>
      CategoriaMovimiento(
        id: json['id']?.toString() ?? '',
        nombre: json['categoria']?.toString() ?? '',
        tipo: TipoMovimiento.deCodigo(json['tipo']?.toString()),
        activo: json['estado'] as bool? ?? true,
      );
}

class MovimientoCaja {
  final String id;
  final TipoMovimiento tipo;
  final String categoriaId;
  final String categoriaNombre;
  // Siempre positivo: si es ingreso o salida lo dice [tipo].
  final double monto;
  final String medioPagoId;
  final String medioPagoNombre;
  final DateTime fecha;
  final String? nota;
  // Quién lo registró (el backend todavía no lo entrega).
  final String? registradoPor;
  // Un movimiento anulado no se borra: se queda en la lista, tachado, y no
  // cuenta en los totales.
  final bool anulado;
  final String? motivoAnulacion;
  final bool editado;

  const MovimientoCaja({
    required this.id,
    required this.tipo,
    required this.categoriaId,
    required this.categoriaNombre,
    required this.monto,
    required this.medioPagoId,
    required this.medioPagoNombre,
    required this.fecha,
    this.nota,
    this.registradoPor,
    this.anulado = false,
    this.motivoAnulacion,
    this.editado = false,
  });

  // Lo que suma (ingreso) o resta (salida) a la caja; 0 si está anulado.
  double get efecto =>
      anulado ? 0 : (tipo == TipoMovimiento.ingreso ? monto : -monto);

  // Lee lo que responde `/api/movimientos`. [notaLocal] es la nota escrita en
  // este equipo, para cuando el servidor no la devuelve.
  factory MovimientoCaja.fromJson(
    Map<String, dynamic> json, {
    String? notaLocal,
  }) {
    final nota = json['nota']?.toString();
    final motivo = json['motivo_anulacion']?.toString();
    return MovimientoCaja(
      id: json['id']?.toString() ?? '',
      tipo: TipoMovimiento.deCodigo(json['tipo']?.toString()),
      categoriaId: json['categoria_movimiento_id']?.toString() ?? '',
      categoriaNombre: json['categoria_nombre']?.toString() ?? '',
      monto: (jsonDouble(json['precio']) ?? 0).abs(),
      medioPagoId: json['medio_pago_id']?.toString() ?? '',
      medioPagoNombre: json['medio_pago_nombre']?.toString() ?? '',
      fecha:
          DateTime.tryParse(json['fecha_movimiento']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      nota: (nota != null && nota.isNotEmpty) ? nota : notaLocal,
      registradoPor: json['usuario_nombre']?.toString(),
      anulado: json['estado']?.toString() == 'anulado',
      motivoAnulacion: (motivo != null && motivo.isNotEmpty) ? motivo : null,
      editado: json['editado'] == true || json['update_at'] != null,
    );
  }

  MovimientoCaja copyWith({
    TipoMovimiento? tipo,
    String? categoriaId,
    String? categoriaNombre,
    double? monto,
    String? medioPagoId,
    String? medioPagoNombre,
    String? nota,
    bool? anulado,
    String? motivoAnulacion,
    bool? editado,
  }) => MovimientoCaja(
    id: id,
    tipo: tipo ?? this.tipo,
    categoriaId: categoriaId ?? this.categoriaId,
    categoriaNombre: categoriaNombre ?? this.categoriaNombre,
    monto: monto ?? this.monto,
    medioPagoId: medioPagoId ?? this.medioPagoId,
    medioPagoNombre: medioPagoNombre ?? this.medioPagoNombre,
    fecha: fecha,
    nota: nota ?? this.nota,
    registradoPor: registradoPor,
    anulado: anulado ?? this.anulado,
    motivoAnulacion: motivoAnulacion ?? this.motivoAnulacion,
    editado: editado ?? this.editado,
  );
}
