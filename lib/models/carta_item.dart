import 'dart:typed_data';

// Refleja la tabla `productos` (esquema real en Supabase): nombre,
// descripcion, precio, costo, sku, stock, disponible (estado), imagen_url,
// agregados (jsonb) y limite_agregados. `precioCliente` es null cuando el
// ítem se vende por presentaciones (ver `carta_presentacion`, ej. bebidas por
// vaso/botella).
class CartaItem {
  final String id;
  final String nombrePlato;
  final String descripcion;
  final String categoriaId;
  final double? precioCliente;
  final String estado; // 'activo' | 'inactivo' (productos.disponible)
  final double? costo; // productos.costo
  final String? sku; // productos.sku
  final int stock; // productos.stock
  // productos.agregados (jsonb): lista de extras, cada uno con `nombre` y
  // opcionalmente `precio`.
  final List<Map<String, dynamic>> agregados;
  final int? limiteAgregados; // productos.limite_agregados
  final DateTime? creadoEn; // productos.created_at
  // Imagen subida desde el formulario (en memoria hasta que exista
  // `imagen_url` real en el backend).
  final Uint8List? imagenBytes;
  // Se ofrece en el pedido con el botón naranja "Plato del día".
  final bool platoDelDia;

  const CartaItem({
    required this.id,
    required this.nombrePlato,
    required this.descripcion,
    required this.categoriaId,
    this.precioCliente,
    this.estado = 'activo',
    this.costo,
    this.sku,
    this.stock = 0,
    this.agregados = const [],
    this.limiteAgregados,
    this.creadoEn,
    this.imagenBytes,
    this.platoDelDia = false,
  });

  bool get disponible => estado != 'inactivo';

  CartaItem copyWith({String? estado}) => CartaItem(
    id: id,
    nombrePlato: nombrePlato,
    descripcion: descripcion,
    categoriaId: categoriaId,
    precioCliente: precioCliente,
    estado: estado ?? this.estado,
    costo: costo,
    sku: sku,
    stock: stock,
    agregados: agregados,
    limiteAgregados: limiteAgregados,
    creadoEn: creadoEn,
    imagenBytes: imagenBytes,
    platoDelDia: platoDelDia,
  );
}
