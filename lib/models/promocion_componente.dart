import '../utils/json_num.dart';

// Refleja la tabla `promocion_componente`: un "hueco" del combo definido por una
// subcategoría (ej. 1 Segundo, 1 Bebida).
class PromocionComponente {
  final String id;
  final String promocionId;
  final String subcategoriaId;
  final int cantidad;
  final int orden;

  const PromocionComponente({
    required this.id,
    required this.promocionId,
    required this.subcategoriaId,
    this.cantidad = 1,
    this.orden = 0,
  });

  factory PromocionComponente.fromJson(Map<String, dynamic> json) =>
      PromocionComponente(
        id: json['id']?.toString() ?? '',
        promocionId: json['promocion_id']?.toString() ?? '',
        subcategoriaId: json['subcategoria_id']?.toString() ?? '',
        cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
        orden: (json['orden'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'promocion_id': promocionId,
    'subcategoria_id': subcategoriaId,
    'cantidad': cantidad,
    'orden': orden,
  };

  PromocionComponente copyWith({
    String? subcategoriaId,
    int? cantidad,
    int? orden,
  }) => PromocionComponente(
    id: id,
    promocionId: promocionId,
    subcategoriaId: subcategoriaId ?? this.subcategoriaId,
    cantidad: cantidad ?? this.cantidad,
    orden: orden ?? this.orden,
  );
}

// Refleja la tabla `promocion_componente_opcion`: un producto que el admin
// permite en ese hueco (con su presentación si es bebida) y su precio de
// promoción. El producto "incluido" es la primera opción activa; las demás son
// los cambios que el mozo puede hacer si el cliente lo pide.
class PromocionOpcion {
  final String id;
  final String componenteId;
  final String cartaId;
  final String? cartaPresentacionId;
  // Tamaño con precio propio (`carta_variante`), p. ej. del pescado.
  final String? cartaVarianteId;
  // Precio de promoción; 0 = sin precio propio (se usa el precio normal con el
  // porcentaje de descuento de la promoción).
  final double precio;
  final bool estado;
  // El producto incluido en la promoción (`es_fijo`); las demás opciones son
  // los cambios que puede pedir el cliente.
  final bool esFijo;

  const PromocionOpcion({
    required this.id,
    required this.componenteId,
    required this.cartaId,
    this.cartaPresentacionId,
    this.cartaVarianteId,
    this.precio = 0,
    this.estado = true,
    this.esFijo = false,
  });

  factory PromocionOpcion.fromJson(Map<String, dynamic> json) =>
      PromocionOpcion(
        id: json['id']?.toString() ?? '',
        componenteId: json['componente_id']?.toString() ?? '',
        cartaId: json['carta_id']?.toString() ?? '',
        cartaPresentacionId: json['carta_presentacion_id']?.toString(),
        cartaVarianteId: json['carta_variante_id']?.toString(),
        precio: jsonDouble(json['precio']) ?? 0,
        estado: json['estado'] != false,
        esFijo: json['es_fijo'] == true,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'componente_id': componenteId,
    'carta_id': cartaId,
    'carta_presentacion_id': cartaPresentacionId,
    'carta_variante_id': cartaVarianteId,
    'precio': precio,
    'estado': estado,
    'es_fijo': esFijo,
  };

  // Cuerpo para el backend. Un precio 0 no se envía (sin precio propio).
  Map<String, dynamic> aBackend({bool incluirId = true}) => {
    if (incluirId) 'id': id,
    'componente_id': componenteId,
    'carta_id': cartaId,
    'carta_presentacion_id': ?cartaPresentacionId,
    'carta_variante_id': ?cartaVarianteId,
    'cantidad': 1,
    if (precio > 0) 'precio': precio,
    'estado': estado,
    'es_fijo': esFijo,
  };

  PromocionOpcion copyWith({double? precio, bool? estado, bool? esFijo}) =>
      PromocionOpcion(
        id: id,
        componenteId: componenteId,
        cartaId: cartaId,
        cartaPresentacionId: cartaPresentacionId,
        cartaVarianteId: cartaVarianteId,
        precio: precio ?? this.precio,
        estado: estado ?? this.estado,
        esFijo: esFijo ?? this.esFijo,
      );
}

// Refleja `pedidos_detalle_componente`: lo que quedó en cada hueco de una
// promoción vendida. [esCambio] es true cuando, a pedido del cliente, el mozo
// cambió el producto incluido por otro que el admin registró.
class ComponenteElegido {
  final String componenteId;
  final String opcionId;
  final String cartaId;
  final String? cartaPresentacionId;
  final String? cartaVarianteId;
  // Para mostrar en pantalla y en cocina.
  final String nombre;
  final int cantidad;
  final bool esCambio;
  // Lo que cuesta este componente en la promoción (ya multiplicado por la
  // cantidad) y su diferencia contra el producto incluido.
  final double precio;
  final double precioAjuste;

  const ComponenteElegido({
    required this.componenteId,
    required this.opcionId,
    required this.cartaId,
    this.cartaPresentacionId,
    this.cartaVarianteId,
    required this.nombre,
    this.cantidad = 1,
    this.esCambio = false,
    required this.precio,
    this.precioAjuste = 0,
  });

  // Lo que se envía al registrar el detalle del pedido.
  Map<String, dynamic> toJson() => {
    'componente_id': componenteId,
    'opcion_id': opcionId,
    'carta_id': cartaId,
    if (cartaPresentacionId != null)
      'carta_presentacion_id': cartaPresentacionId,
    if (cartaVarianteId != null) 'carta_variante_id': cartaVarianteId,
    'es_cambio': esCambio,
    'precio_ajuste': precioAjuste,
  };
}
