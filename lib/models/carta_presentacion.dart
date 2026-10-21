import '../utils/json_num.dart';
import 'unidad_bebida.dart';

// Refleja la tabla `carta_presentacion` (ej. bebidas por vaso/botella/jarra).
class CartaPresentacion {
  final String id;
  final String cartaId;
  final UnidadBebida unidad;
  final int volumenMl;
  final double precioCliente;
  final double? precioPersonal;
  final bool estado;

  const CartaPresentacion({
    required this.id,
    required this.cartaId,
    required this.unidad,
    required this.volumenMl,
    required this.precioCliente,
    this.precioPersonal,
    this.estado = true,
  });

  factory CartaPresentacion.fromJson(
    Map<String, dynamic> json, {
    List<UnidadBebida>? catalogoUnidades,
  }) {
    final unidadId = json['unidad_bebida_id']?.toString() ?? '';
    var unidadNombre = json['unidad_presentacion']?.toString() ?? '';
    if (unidadNombre.isEmpty && catalogoUnidades != null) {
      for (final u in catalogoUnidades) {
        if (u.id == unidadId) {
          unidadNombre = u.unidadPresentacion;
          break;
        }
      }
    }
    return CartaPresentacion(
      id: json['id']?.toString() ?? '',
      cartaId: json['carta_id']?.toString() ?? '',
      unidad: UnidadBebida(
        id: unidadId,
        unidadPresentacion: unidadNombre.isNotEmpty ? unidadNombre : 'Presentación',
      ),
      volumenMl: (json['volumen_ml'] as num?)?.toInt() ?? 0,
      precioCliente: jsonDouble(json['precio_cliente']) ?? 0,
      precioPersonal: jsonDouble(json['precio_personal']),
      estado: json['estado'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'carta_id': cartaId,
    'unidad_bebida_id': unidad.id,
    'unidad_presentacion': unidad.unidadPresentacion,
    'volumen_ml': volumenMl,
    'precio_cliente': precioCliente,
    'precio_personal': precioPersonal,
    'estado': estado,
  };

  CartaPresentacion copyWith({
    String? id,
    String? cartaId,
    UnidadBebida? unidad,
    int? volumenMl,
    double? precioCliente,
    double? precioPersonal,
    bool? estado,
  }) => CartaPresentacion(
    id: id ?? this.id,
    cartaId: cartaId ?? this.cartaId,
    unidad: unidad ?? this.unidad,
    volumenMl: volumenMl ?? this.volumenMl,
    precioCliente: precioCliente ?? this.precioCliente,
    precioPersonal: precioPersonal ?? this.precioPersonal,
    estado: estado ?? this.estado,
  );
}
