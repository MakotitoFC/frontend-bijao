import 'dart:typed_data';

import '../utils/json_num.dart';

const estadoDisponible = 'disponible';
const estadoAgotado = 'agotado';
const estadoInhabilitado = 'inhabilitado';
const estadoEliminado = 'eliminado';

// Refleja la tabla `carta` en PostgreSQL (con soporte para modificadores/agregados).
class CartaItem {
  final String id;
  final String nombrePlato;
  final String descripcion;
  final String categoriaId;
  final String? categoriaNombre;
  // Subcategorías del plato (Segundo, Bebida, Snack…). El backend solo guarda
  // una (`carta.subcategoria_id`): se envía la primera.
  final List<String> subcategoriaIds;
  final String? taperId;
  final String? taperNombre;
  final double? precioCliente;
  final double? precioPersonal;
  // Estados: 'disponible' | 'agotado' | 'inhabilitado' | 'eliminado' (borrado
  // lógico). El backend aún no lo respalda: es una convención del frontend sobre
  // el texto libre de `carta.estado` (ver BACKEND_PENDIENTES.md).
  final String estado;
  final String? sedeId;
  final double? costo;
  final String? sku;
  final int stock;
  final List<Map<String, dynamic>> agregados;
  final int? limiteAgregados;
  final DateTime? creadoEn;
  final Uint8List? imagenBytes;
  // Foto del plato: dirección guardada en el backend (`carta.url_imagen`).
  final String? urlImagen;
  final bool platoDelDia;

  const CartaItem({
    required this.id,
    required this.nombrePlato,
    required this.descripcion,
    required this.categoriaId,
    this.categoriaNombre,
    this.subcategoriaIds = const [],
    this.taperId,
    this.taperNombre,
    this.precioCliente,
    this.precioPersonal,
    this.estado = 'disponible',
    this.sedeId,
    this.costo,
    this.sku,
    this.stock = 0,
    this.agregados = const [],
    this.limiteAgregados,
    this.creadoEn,
    this.imagenBytes,
    this.urlImagen,
    this.platoDelDia = false,
  });

  String? get subcategoriaId =>
      subcategoriaIds.isEmpty ? null : subcategoriaIds.first;

  bool get agotado => estado == estadoAgotado;
  bool get inhabilitado => estado == estadoInhabilitado;
  bool get eliminado => estado == estadoEliminado;
  bool get disponible => !agotado && !inhabilitado && !eliminado;

  CartaItem copyWith({
    String? id,
    String? nombrePlato,
    String? descripcion,
    String? categoriaId,
    String? categoriaNombre,
    List<String>? subcategoriaIds,
    String? taperId,
    String? taperNombre,
    double? precioCliente,
    double? precioPersonal,
    String? estado,
    String? sedeId,
    double? costo,
    String? sku,
    int? stock,
    List<Map<String, dynamic>>? agregados,
    int? limiteAgregados,
    DateTime? creadoEn,
    Uint8List? imagenBytes,
    String? urlImagen,
    bool? platoDelDia,
  }) => CartaItem(
    id: id ?? this.id,
    nombrePlato: nombrePlato ?? this.nombrePlato,
    descripcion: descripcion ?? this.descripcion,
    categoriaId: categoriaId ?? this.categoriaId,
    categoriaNombre: categoriaNombre ?? this.categoriaNombre,
    subcategoriaIds: subcategoriaIds ?? this.subcategoriaIds,
    taperId: taperId ?? this.taperId,
    taperNombre: taperNombre ?? this.taperNombre,
    precioCliente: precioCliente ?? this.precioCliente,
    precioPersonal: precioPersonal ?? this.precioPersonal,
    estado: estado ?? this.estado,
    sedeId: sedeId ?? this.sedeId,
    costo: costo ?? this.costo,
    sku: sku ?? this.sku,
    stock: stock ?? this.stock,
    agregados: agregados ?? this.agregados,
    limiteAgregados: limiteAgregados ?? this.limiteAgregados,
    creadoEn: creadoEn ?? this.creadoEn,
    imagenBytes: imagenBytes ?? this.imagenBytes,
    urlImagen: urlImagen ?? this.urlImagen,
    platoDelDia: platoDelDia ?? this.platoDelDia,
  );

  factory CartaItem.fromJson(Map<String, dynamic> json) {
    // Normalizar modificadores recibidos del backend
    final List<Map<String, dynamic>> rawMods = [];
    if (json['modificadores'] is List) {
      for (final m in json['modificadores']) {
        if (m is Map<String, dynamic>) {
          rawMods.add({
            'id': m['id'],
            'nombre': m['nombre'] ?? '',
            'tipo': m['tipo'] ?? 'ajuste',
            'precio': jsonDouble(m['precio_ajuste']) ?? 0.0,
          });
        }
      }
    }

    final pCli = jsonDouble(json['precio_cliente']);
    final pPer = jsonDouble(json['precio_personal']);

    return CartaItem(
      id: json['id'] as String,
      nombrePlato:
          json['nombre_plato'] as String? ?? json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      categoriaId:
          json['categoria_comida_id'] as String? ??
          json['categoria_id'] as String? ??
          '',
      categoriaNombre: json['categoria_nombre'] as String?,
      subcategoriaIds: json['subcategoria_ids'] is List
          ? [for (final s in json['subcategoria_ids']) s.toString()]
          : [
              if (json['subcategoria_id'] is String)
                json['subcategoria_id'] as String,
            ],
      taperId: json['taper_id'] as String?,
      taperNombre: json['taper_nombre'] as String?,
      precioCliente: pCli,
      precioPersonal: pPer,
      estado: _normalizarEstado(json['estado'] as String?),
      sedeId: json['sede_id'] as String?,
      agregados: rawMods.isNotEmpty ? rawMods : const [],
      costo: jsonDouble(json['costo']),
      sku: json['sku'] as String?,
      stock: (json['stock'] is int) ? json['stock'] as int : 0,
      urlImagen:
          (json['url_imagen'] is String &&
              (json['url_imagen'] as String).isNotEmpty)
          ? json['url_imagen'] as String
          : null,
      platoDelDia: json['plato_del_dia'] as bool? ?? false,
    );
  }

  // Valores antiguos: 'inactivo' pasó a 'inhabilitado' y 'activo' a 'disponible'.
  static String _normalizarEstado(String? e) => switch (e) {
    null || '' || 'activo' || 'libre' => estadoDisponible,
    'inactivo' => estadoInhabilitado,
    _ => e,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre_plato': nombrePlato,
    'descripcion': descripcion,
    'categoria_id': categoriaId,
    if (subcategoriaId != null) 'subcategoria_id': subcategoriaId,
    if (taperId != null) 'taper_id': taperId,
    if (taperNombre != null) 'taper_nombre': taperNombre,
    'estado': estado,
    if (precioCliente != null) 'precio_cliente': precioCliente,
    if (precioPersonal != null) 'precio_personal': precioPersonal,
    if (sedeId != null) 'sede_id': sedeId,
    if (urlImagen != null) 'url_imagen': urlImagen,
  };
}
