import '../models/carta_presentacion.dart';
import '../models/carta_variante.dart';
import '../models/modificador.dart';
import '../models/pedido_line.dart';
import '../models/promocion.dart';
import '../models/promocion_componente.dart';
import '../models/unidad_bebida.dart';

// Forma de guardar en el dispositivo una línea del pedido que aún no se envió
// (el borrador). No es lo que recibe el backend: solo sirve para retomar el
// pedido tal cual estaba.

Map<String, dynamic> lineaAJsonLocal(PedidoLine l) => {
  'id': l.id,
  'carta_id': l.cartaId,
  'nombre_plato': l.nombrePlato,
  'cantidad': l.cantidad,
  'modificadores': [for (final m in l.modificadores) m.toJson()],
  if (l.presentacion != null)
    'presentacion': {
      'id': l.presentacion!.id,
      'carta_id': l.presentacion!.cartaId,
      'unidad_id': l.presentacion!.unidad.id,
      'unidad': l.presentacion!.unidad.unidadPresentacion,
      'volumen_ml': l.presentacion!.volumenMl,
      'precio_cliente': l.presentacion!.precioCliente,
    },
  if (l.variante != null) 'variante': l.variante!.toJson(),
  if (l.promocion != null) 'promocion': l.promocion!.toJson(),
  'componentes': [
    for (final e in l.componentes)
      {
        'componente_id': e.componenteId,
        'opcion_id': e.opcionId,
        'carta_id': e.cartaId,
        'carta_presentacion_id': e.cartaPresentacionId,
        'carta_variante_id': e.cartaVarianteId,
        'nombre': e.nombre,
        'cantidad': e.cantidad,
        'es_cambio': e.esCambio,
        'precio': e.precio,
        'precio_ajuste': e.precioAjuste,
      },
  ],
  'comentario': l.comentario,
  'precio_unitario': l.precioUnitario,
  'descuento_aplicado': l.descuentoAplicado,
  'precio_total_linea': l.precioTotalLinea,
  'tipo_entrega': l.tipoEntrega,
  'aplica_taper': l.aplicaTaper,
  'taper_id': l.taperId,
  'precio_taper': l.precioTaper,
  'cantidad_taper': l.cantidadTaper,
  'es_libre': l.esLibre,
  'nombre_libre': l.nombreLibre,
  'descripcion_libre': l.descripcionLibre,
  'precio_base': l.precioBase,
};

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

PedidoLine lineaDeJsonLocal(Map<String, dynamic> j) {
  final pres = j['presentacion'];
  final promo = j['promocion'];
  final variante = j['variante'];
  return PedidoLine(
    id: j['id']?.toString() ?? '',
    cartaId: j['carta_id']?.toString() ?? '',
    nombrePlato: j['nombre_plato']?.toString() ?? '',
    cantidad: (j['cantidad'] as num?)?.toInt() ?? 1,
    modificadores: [
      for (final m in (j['modificadores'] as List? ?? const []))
        Modificador.fromJson(m as Map<String, dynamic>),
    ],
    presentacion: pres is Map<String, dynamic>
        ? CartaPresentacion(
            id: pres['id']?.toString() ?? '',
            cartaId: pres['carta_id']?.toString() ?? '',
            unidad: UnidadBebida(
              id: pres['unidad_id']?.toString() ?? '',
              unidadPresentacion: pres['unidad']?.toString() ?? '',
            ),
            volumenMl: (pres['volumen_ml'] as num?)?.toInt() ?? 0,
            precioCliente: _num(pres['precio_cliente']),
          )
        : null,
    variante: variante is Map<String, dynamic>
        ? CartaVariante.fromJson(variante)
        : null,
    promocion: promo is Map<String, dynamic> ? Promocion.fromJson(promo) : null,
    componentes: [
      for (final e in (j['componentes'] as List? ?? const []))
        ComponenteElegido(
          componenteId: (e as Map)['componente_id']?.toString() ?? '',
          opcionId: e['opcion_id']?.toString() ?? '',
          cartaId: e['carta_id']?.toString() ?? '',
          cartaPresentacionId: e['carta_presentacion_id']?.toString(),
          cartaVarianteId: e['carta_variante_id']?.toString(),
          nombre: e['nombre']?.toString() ?? '',
          cantidad: (e['cantidad'] as num?)?.toInt() ?? 1,
          esCambio: e['es_cambio'] == true,
          precio: _num(e['precio']),
          precioAjuste: _num(e['precio_ajuste']),
        ),
    ],
    comentario: j['comentario']?.toString(),
    precioUnitario: _num(j['precio_unitario']),
    descuentoAplicado: _num(j['descuento_aplicado']),
    precioTotalLinea: _num(j['precio_total_linea']),
    tipoEntrega: j['tipo_entrega']?.toString() ?? 'mesa',
    aplicaTaper: j['aplica_taper'] == true,
    taperId: j['taper_id']?.toString(),
    precioTaper: _num(j['precio_taper']),
    cantidadTaper: (j['cantidad_taper'] as num?)?.toInt(),
    esLibre: j['es_libre'] == true,
    nombreLibre: j['nombre_libre']?.toString(),
    descripcionLibre: j['descripcion_libre']?.toString(),
    precioBase: _num(j['precio_base']),
  );
}
