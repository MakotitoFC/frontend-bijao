import '../data/pedidos_store.dart';
import '../data/presentaciones_store.dart';
import '../data/promociones_store.dart';
import '../data/variantes_store.dart';
import '../models/carta_presentacion.dart';
import '../models/carta_variante.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../models/promocion.dart';
import '../models/promocion_componente.dart';
import '../utils/json_num.dart';
import '../utils/uuid_helper.dart';

// Traducción entre el carrito de la app y `/api/v1/mozo/pedidos`.
//
// Reglas del backend: la app NUNCA envía precios (el backend los calcula desde
// carta, variante, presentación, promoción y táper); la única excepción es el
// precio del plato libre. El táper va en una fila aparte, con su cantidad.

bool _esUuid(String? v) => v != null && v.isNotEmpty && UuidHelper.isValid(v);

// Datos de entrega a domicilio (`delivery`).
class DatosDelivery {
  final String direccion;
  final String? referencia;
  final String? telefono;
  final double? costoEnvio;

  const DatosDelivery({
    required this.direccion,
    this.referencia,
    this.telefono,
    this.costoEnvio,
  });

  Map<String, dynamic> toJson() => {
    'direccion': direccion,
    if (referencia != null && referencia!.isNotEmpty) 'referencia': referencia,
    if (telefono != null && telefono!.isNotEmpty) 'telefono': telefono,
    if (costoEnvio != null) 'costo_envio': costoEnvio,
  };
}

// Cuerpo de `POST /api/v1/mozo/pedidos`.
Map<String, dynamic> armarPedidoMozo({
  required List<PedidoLine> lineas,
  String? mesaId,
  String? comentarios,
  String tipo = 'normal',
  String tipoEntrega = 'mesa',
  String? nombreCliente,
  DatosDelivery? delivery,
}) {
  return {
    if (_esUuid(mesaId)) 'mesa_id': mesaId,
    'tipo': tipo,
    // 'mesa', 'llevar' o 'delivery': el backend lo guarda y lo devuelve.
    'tipo_entrega': tipoEntrega,
    if (nombreCliente != null && nombreCliente.trim().isNotEmpty)
      'nombre_cliente': nombreCliente.trim(),
    if (comentarios != null && comentarios.isNotEmpty)
      'comentarios': comentarios,
    'delivery': ?delivery?.toJson(),
    'items': [
      for (final l in lineas)
        ...itemsDeLinea(
          l,
          tipoEntrega: tipoEntrega,
          conDelivery: delivery != null,
        ),
    ],
  };
}

// Una línea del carrito puede dar dos filas: el plato y su táper.
//
// Si el pedido lleva datos de delivery, el costo de envío viaja en ellos y la
// línea de "cargo por delivery" del carrito no se envía como ítem.
List<Map<String, dynamic>> itemsDeLinea(
  PedidoLine l, {
  String tipoEntrega = 'mesa',
  bool conDelivery = false,
}) {
  // En un pedido de delivery todas las filas salen por delivery.
  final entrega = (tipoEntrega == 'delivery' || tipoEntrega == 'llevar')
      ? tipoEntrega
      : (l.tipoEntrega.isNotEmpty ? l.tipoEntrega : tipoEntrega);
  final comentario = (l.comentario != null && l.comentario!.isNotEmpty)
      ? l.comentario
      : null;

  Map<String, dynamic> libre(String nombre, double precio) => {
    'es_libre': true,
    'nombre_libre': nombre,
    if (l.descripcionLibre != null && l.descripcionLibre!.isNotEmpty)
      'descripcion_libre': l.descripcionLibre,
    'precio_unitario_libre': precio,
    'cantidad': l.cantidad,
    'tipo_entrega': entrega,
    'comentario': ?comentario,
  };

  // Cargo de delivery: con datos de delivery viaja en `delivery.costo_envio`.
  if (l.cartaId == cartaIdCargoDelivery) {
    return conDelivery ? const [] : [libre(l.nombrePlato, l.precioUnitario)];
  }
  // Propina, tupper global y demás ajustes manuales no son productos.
  if (l.cartaId == cartaIdAjuste) return const [];

  // Fila solo de táper.
  if (l.cartaId == cartaIdTaper) {
    if (!_esUuid(l.taperId)) return const [];
    return [
      {
        'taper_id': l.taperId,
        'cantidad': l.cantidad,
        'tipo_entrega': entrega,
        'comentario': ?comentario,
      },
    ];
  }

  if (l.promocion != null && _esUuid(l.promocion!.id)) {
    return [
      {
        'promocion_id': l.promocion!.id,
        'cantidad': l.cantidad,
        'tipo_entrega': entrega,
        'comentario': ?comentario,
        'componentes': [
          for (final c in l.componentes)
            {
              'componente_id': c.componenteId,
              'opcion_id': c.opcionId,
              'carta_id': c.cartaId,
              if (c.cartaPresentacionId != null)
                'carta_presentacion_id': c.cartaPresentacionId,
              if (c.cartaVarianteId != null)
                'carta_variante_id': c.cartaVarianteId,
            },
        ],
      },
    ];
  }

  if (l.esLibre || !_esUuid(l.cartaId)) {
    final precio = l.precioBase > 0 ? l.precioBase : l.precioUnitario;
    return [libre(l.nombreLibre ?? l.nombrePlato, precio)];
  }

  return [
    {
      'carta_id': l.cartaId,
      if (l.variante != null && _esUuid(l.variante!.id))
        'carta_variante_id': l.variante!.id,
      if (l.presentacion != null && _esUuid(l.presentacion!.id))
        'carta_presentacion_id': l.presentacion!.id,
      'cantidad': l.cantidad,
      'tipo_entrega': entrega,
      'comentario': ?comentario,
    },
    // El táper se cobra aparte: una fila propia con su cantidad.
    if (l.aplicaTaper && _esUuid(l.taperId))
      {'taper_id': l.taperId, 'cantidad': l.cantidad, 'tipo_entrega': entrega},
  ];
}

// Descuento aplicado al pedido (o a una fila) que devuelve el backend.
class DescuentoServidor {
  final String id;
  final String? detalleId;
  final String motivo;
  final String tipo; // 'porcentaje' | 'monto'
  final double valor;
  final double monto;
  final String? autorizoNombre;

  const DescuentoServidor({
    required this.id,
    required this.detalleId,
    required this.motivo,
    required this.tipo,
    required this.valor,
    required this.monto,
    this.autorizoNombre,
  });
}

// Datos de envío que devuelve el backend en un pedido de delivery.
class DeliveryServidor {
  final String direccion;
  final String? referencia;
  final String? telefono;
  final double costoEnvio;

  const DeliveryServidor({
    required this.direccion,
    this.referencia,
    this.telefono,
    this.costoEnvio = 0,
  });
}

// Detalle de un pedido tal como lo devuelve el backend.
class PedidoMozoDetalle {
  final String id;
  final int version;
  final String estado;
  final String tipo;
  // Número de orden del día ("#0004"), el mismo que sale en la comanda.
  final String? codigoOrden;
  // 'mesa', 'llevar' o 'delivery' (lo decide el backend).
  final String tipoEntrega;
  final String? nombreCliente;
  final DeliveryServidor? delivery;
  final String? mesaId;
  final int? mesaNumero;
  final String usuarioId;
  final String? mozoNombre;
  final String? comentarios;
  final DateTime? inicio;
  // Cuándo terminó el pedido (hora de fin o, si se cerró, la última
  // actualización).
  final DateTime? fin;
  final double subtotal;
  final double totalDescuento;
  final double costoDelivery;
  final double total;
  final List<DescuentoServidor> descuentos;
  // Filas del pedido (más cargo de delivery y descuentos del pedido como líneas
  // de ajuste, para que los totales de la app coincidan con los del backend).
  final List<PedidoLine> lineas;
  // Filas que el backend marca como servidas.
  final Set<String> servidas;

  const PedidoMozoDetalle({
    required this.id,
    required this.version,
    required this.estado,
    required this.tipo,
    this.codigoOrden,
    required this.tipoEntrega,
    required this.nombreCliente,
    required this.delivery,
    required this.mesaId,
    required this.mesaNumero,
    required this.usuarioId,
    required this.mozoNombre,
    required this.comentarios,
    required this.inicio,
    required this.fin,
    required this.subtotal,
    required this.totalDescuento,
    required this.costoDelivery,
    required this.total,
    required this.descuentos,
    required this.lineas,
    required this.servidas,
  });
}

CartaPresentacion? _presentacionPorId(String? id) {
  if (id == null) return null;
  for (final p in presentaciones) {
    if (p.id == id) return p;
  }
  return null;
}

CartaVariante? _variantePorId(String? id) {
  if (id == null) return null;
  for (final v in variantes) {
    if (v.id == id) return v;
  }
  return null;
}

Promocion? _promocionPorId(String? id) {
  if (id == null) return null;
  for (final p in promociones) {
    if (p.id == id) return p;
  }
  return null;
}

String? _texto(Object? v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

// El backend devuelve el instante con offset (America/Lima).
DateTime? _instante(Object? v) => DateTime.tryParse(v?.toString() ?? '');

void _lineasDeItem(
  Map<String, dynamic> it,
  List<PedidoLine> destino,
  Set<String> servidas,
) {
  final estado = it['estado']?.toString();
  final id = it['id']?.toString() ?? '';
  final nombre = it['nombre']?.toString() ?? 'Producto';
  final cantidad = (it['cantidad'] as num?)?.toInt() ?? 1;
  final version = (it['version'] as num?)?.toInt() ?? 1;
  final unitario = jsonDouble(it['precio_unitario']) ?? 0;
  final descuento = jsonDouble(it['descuento_fila']) ?? 0;
  final total = jsonDouble(it['total_fila']) ?? unitario * cantidad;
  final tipo = it['tipo_item']?.toString();

  if (estado != 'anulado' && estado != 'devuelto') {
    final presentacionId = _texto(it['carta_presentacion_id']);
    final varianteId = _texto(it['carta_variante_id']);
    final promocionId = _texto(it['promocion_id']);
    final taperId = _texto(it['taper_id']);
    final cartaId = _texto(it['carta_id']);
    final esTaper = tipo == 'taper';
    final esLibre = tipo == 'libre';
    final esPromo = tipo == 'promocion';

    final componentes = <ComponenteElegido>[
      for (final c in (it['componentes'] as List? ?? const []))
        ComponenteElegido(
          componenteId: (c as Map)['componente_id']?.toString() ?? '',
          opcionId: c['opcion_id']?.toString() ?? '',
          cartaId: c['carta_id']?.toString() ?? '',
          nombre: c['nombre']?.toString() ?? '',
          cantidad: (c['cantidad'] as num?)?.toInt() ?? 1,
          precio: jsonDouble(c['total_componente']) ?? 0,
        ),
    ];

    destino.add(
      PedidoLine(
        id: id,
        cartaId: esTaper
            ? cartaIdTaper
            : esPromo
            ? cartaIdPromocion
            : (cartaId ?? ''),
        nombrePlato: nombre,
        cantidad: cantidad,
        modificadores: const [],
        presentacion: _presentacionPorId(presentacionId),
        variante: _variantePorId(varianteId),
        promocion: _promocionPorId(promocionId),
        componentes: componentes,
        comentario: _texto(it['comentario']),
        precioUnitario: unitario,
        descuentoAplicado: descuento,
        precioTotalLinea: total,
        tipoEntrega: it['tipo_entrega']?.toString() ?? 'mesa',
        taperId: taperId,
        esLibre: esLibre,
        nombreLibre: esLibre ? nombre : null,
        precioBase: unitario,
        estado: (estado == null || estado == 'pendiente' || estado == 'servido')
            ? null
            : estado,
        version: version,
      ),
    );
    if (estado == 'servido') servidas.add(id);
  }

  for (final h in (it['hijos'] as List? ?? const [])) {
    _lineasDeItem(h as Map<String, dynamic>, destino, servidas);
  }
}

DeliveryServidor? _delivery(Object? raw) {
  if (raw is! Map) return null;
  return DeliveryServidor(
    direccion: raw['direccion']?.toString() ?? '',
    referencia: _texto(raw['referencia']),
    telefono: _texto(raw['telefono']),
    costoEnvio: jsonDouble(raw['costo_envio']) ?? 0,
  );
}

// Lee el detalle que devuelve el backend (`PedidoMozoDetalleDTO`).
PedidoMozoDetalle parsearDetalleMozo(Map<String, dynamic> json) {
  final id = json['id']?.toString() ?? '';
  final lineas = <PedidoLine>[];
  final servidas = <String>{};
  for (final raw in (json['items'] as List? ?? const [])) {
    _lineasDeItem(raw as Map<String, dynamic>, lineas, servidas);
  }

  final descuentos = <DescuentoServidor>[
    for (final d in (json['descuentos'] as List? ?? const []))
      DescuentoServidor(
        id: (d as Map)['id']?.toString() ?? '',
        detalleId: _texto(d['pedidos_detalle_id']),
        motivo: d['motivo']?.toString() ?? 'Descuento',
        tipo: d['tipo']?.toString() ?? 'monto',
        valor: jsonDouble(d['valor']) ?? 0,
        monto: jsonDouble(d['monto_aplicado']) ?? 0,
        autorizoNombre: _texto(d['usuario_autorizo_nombre']),
      ),
  ];
  final costoDelivery = jsonDouble(json['costo_delivery']) ?? 0;

  // El cargo de delivery y los descuentos del pedido entran como líneas de
  // ajuste: la app suma líneas para calcular totales, y así coincide con el
  // backend. Los descuentos de una fila ya vienen en el total de esa fila.
  if (costoDelivery > 0) {
    lineas.add(
      PedidoLine(
        id: 'delivery-$id',
        cartaId: cartaIdCargoDelivery,
        nombrePlato: 'Cargo por delivery',
        cantidad: 1,
        modificadores: const [],
        presentacion: null,
        promocion: null,
        comentario: null,
        precioUnitario: costoDelivery,
        descuentoAplicado: 0,
        precioTotalLinea: costoDelivery,
      ),
    );
  }
  for (final d in descuentos.where((d) => d.detalleId == null)) {
    lineas.add(
      PedidoLine(
        id: d.id,
        cartaId: cartaIdAjuste,
        nombrePlato: 'Descuento: ${d.motivo}',
        cantidad: 1,
        modificadores: const [],
        presentacion: null,
        promocion: null,
        comentario: null,
        precioUnitario: -d.monto,
        descuentoAplicado: 0,
        precioTotalLinea: -d.monto,
      ),
    );
  }

  final estado = json['estado']?.toString() ?? 'pendiente';
  final inicio = _instante(json['instante_inicio']);
  final base = (inicio ?? DateTime.now()).toLocal();
  final fin =
      fechaDeFin(json['hora_fin'], base) ??
      (Pedido.estadosTerminales.contains(estado)
          ? fechaDeFin(json['updated_at'], base)
          : null);
  return PedidoMozoDetalle(
    id: id,
    version: (json['version'] as num?)?.toInt() ?? 1,
    estado: estado == 'pedido' ? 'pendiente' : estado,
    tipo: json['tipo']?.toString() ?? 'normal',
    codigoOrden: _texto(json['codigo_orden']),
    tipoEntrega: _texto(json['tipo_entrega']) ?? 'mesa',
    nombreCliente: _texto(json['nombre_cliente']),
    delivery: _delivery(json['delivery']),
    mesaId: _texto(json['mesa_id']),
    mesaNumero: (json['mesa_numero'] as num?)?.toInt(),
    usuarioId: json['usuario_id']?.toString() ?? '',
    mozoNombre: _texto(json['mozo_nombre']),
    comentarios: _texto(json['comentarios']),
    inicio: inicio,
    fin: fin,
    subtotal: jsonDouble(json['subtotal']) ?? 0,
    totalDescuento: jsonDouble(json['total_descuento']) ?? 0,
    costoDelivery: costoDelivery,
    total: jsonDouble(json['total']) ?? 0,
    descuentos: descuentos,
    lineas: lineas,
    servidas: servidas,
  );
}
