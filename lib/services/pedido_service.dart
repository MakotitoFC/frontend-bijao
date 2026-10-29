import '../data/mesas_store.dart';
import '../data/pedidos_store.dart';
import '../data/presentaciones_store.dart';
import '../data/variantes_store.dart';
import '../config/app_config.dart';
import '../models/app_role.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../utils/uuid_helper.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'catalog_service.dart';
import 'pedido_mozo_mapper.dart';
import 'pedido_mozo_service.dart';

// Línea del listado con su presentación (jarra, vaso…) y su variante, que el
// servidor manda solo como id: se buscan en la carta ya cargada.
PedidoLine _lineaConOpciones(Map<String, dynamic> d) {
  final linea = PedidoLine.fromJson(d);
  final presId = d['carta_presentacion_id']?.toString();
  final varId = d['carta_variante_id']?.toString();
  final presentacion = presId == null
      ? null
      : presentaciones.where((p) => p.id == presId).firstOrNull;
  final variante = varId == null
      ? null
      : variantes.where((v) => v.id == varId).firstOrNull;
  if (presentacion == null && variante == null) return linea;
  return linea.copyWith(presentacion: presentacion, variante: variante);
}

class PedidoService {
  PedidoService._();
  static final PedidoService instance = PedidoService._();

  final ApiClient _api = ApiClient.instance;

  /// Registra un pedido completo en PostgreSQL vía `POST /api/pedidos`
  Future<Pedido> crearPedido({
    required Pedido pedido,
    required List<PedidoLine> lineas,
    String? mesaId,
    int? mesaNumero,
    String? taperId,
    double precioTaper = 0.0,
    String tipoEntrega = 'mesa',
    String? comentarios,
    // Pedido de personal (empleado): el precio de cada plato se escribe a mano.
    bool esPersonal = false,
  }) async {
    final user = AuthService.instance.currentUser;
    if (AppConfig.usarApiPedidosMozo &&
        (user?.rol == AppRole.mesero || user?.rol == AppRole.administrador)) {
      return _crearPedidoMozo(
        pedido: pedido,
        lineas: lineas,
        mesaId: mesaId,
        mesaNumero: mesaNumero,
        tipoEntrega: tipoEntrega,
        comentarios: comentarios,
        esPersonal: esPersonal,
      );
    }
    final now = DateTime.now();

    final fechaStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final horaStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final pedidoUuid = (pedido.id.isNotEmpty && UuidHelper.isValid(pedido.id))
        ? pedido.id
        : UuidHelper.v7();

    // Resolver mesaId si solo vino el número de mesa
    String? idMesa = mesaId;
    if ((idMesa == null || idMesa.isEmpty) &&
        mesaNumero != null &&
        mesaNumero > 0) {
      final encontrada = mesas.where((m) => m.numero == mesaNumero).firstOrNull;
      if (encontrada != null) {
        idMesa = encontrada.id;
      }
    }

    final detallesPayload = lineas.map((l) {
      final detUuid = (l.id.isNotEmpty && UuidHelper.isValid(l.id))
          ? l.id
          : UuidHelper.v7();
      final esCarta =
          l.cartaId.isNotEmpty && UuidHelper.isValid(l.cartaId) && !l.esLibre;
      final esPromo =
          l.promocion != null && UuidHelper.isValid(l.promocion!.id);
      final aplicaTaper =
          l.aplicaTaper || (taperId != null && taperId.isNotEmpty);
      final idTaper = l.taperId ?? taperId;
      final pTaper = l.aplicaTaper ? l.precioTaper : precioTaper;
      final tipoEnt = l.tipoEntrega.isNotEmpty ? l.tipoEntrega : tipoEntrega;

      return {
        'id': detUuid,
        'pedidos_id': pedidoUuid,
        if (esCarta) 'carta_id': l.cartaId,
        if (esPromo) 'promocion_id': l.promocion!.id,
        if (esPromo) 'componentes': [for (final e in l.componentes) e.toJson()],
        'cantidad': l.cantidad,
        'tipo_entrega': tipoEnt,
        'aplica_taper': aplicaTaper,
        if (aplicaTaper &&
            idTaper != null &&
            idTaper.isNotEmpty &&
            UuidHelper.isValid(idTaper))
          'taper_id': idTaper,
        'precio_taper': aplicaTaper ? pTaper : 0.0,
        if (l.presentacion != null && UuidHelper.isValid(l.presentacion!.id))
          'carta_presentacion_id': l.presentacion!.id,
        if (l.variante != null && UuidHelper.isValid(l.variante!.id))
          'carta_variante_id': l.variante!.id,
        'es_libre': l.esLibre || (!esCarta && !esPromo),
        if (l.esLibre || (!esCarta && !esPromo))
          'nombre_libre': (l.nombreLibre ?? l.nombrePlato),
        if (l.descripcionLibre != null && l.descripcionLibre!.isNotEmpty)
          'descripcion_libre': l.descripcionLibre,
        'precio_base': l.precioBase > 0 ? l.precioBase : l.precioUnitario,
        'precio':
            (l.precioUnitario * l.cantidad) +
            (aplicaTaper ? pTaper * (l.cantidadTaper ?? l.cantidad) : 0.0),
        if (l.comentario != null && l.comentario!.isNotEmpty)
          'comentarios': l.comentario,
        'estado': 'pedido',
        'version': 1,
      };
    }).toList();

    final body = {
      'pedido': {
        'id': pedidoUuid,
        if (user != null && UuidHelper.isValid(user.id)) 'usuario_id': user.id,
        'tipo': 'normal',
        if (user?.sedeId != null && user!.sedeId!.isNotEmpty)
          'sede_id': user.sedeId,
        'fecha_pedido': fechaStr,
        'hora_inicio': horaStr,
        'estado': 'pedido',
        if (idMesa != null && idMesa.isNotEmpty && UuidHelper.isValid(idMesa))
          'mesa_id': idMesa,
        if (mesaNumero != null && mesaNumero > 0) 'mesa_numero': mesaNumero,
        if (comentarios != null && comentarios.isNotEmpty)
          'comentarios': comentarios,
        'version': 1,
      },
      if (idMesa != null && idMesa.isNotEmpty && UuidHelper.isValid(idMesa))
        'mesa_id': idMesa,
      if (mesaNumero != null && mesaNumero > 0) 'mesa_numero': mesaNumero,
      'detalles': detallesPayload,
    };

    final res = await _api.post('/api/pedidos', body: body);
    if (res is Map<String, dynamic>) {
      // Pedido creado con éxito en backend
      final nuevoPedido = pedido.copyWith(
        id: pedidoUuid,
        estado: 'pendiente',
        usuarioId: user?.id,
      );

      // Guardar también en la tienda en memoria para UI reactiva inmediata
      registrarPedido(nuevoPedido, lineas);

      // Si fue para mesa, actualizar estado local de la mesa a 'ocupada'
      if (mesaNumero != null && mesaNumero > 0) {
        actualizarEstadoMesa(mesaNumero, 'ocupada');
      }

      return nuevoPedido;
    }

    throw Exception('Error inesperado al crear el pedido en el servidor');
  }

  /// Crea el pedido con `POST /api/v1/mozo/pedidos`: el backend calcula todos
  /// los precios y el táper va en una fila aparte. El pedido queda registrado
  /// con el id, las filas y los precios que devuelve el backend.
  Future<Pedido> _crearPedidoMozo({
    required Pedido pedido,
    required List<PedidoLine> lineas,
    String? mesaId,
    int? mesaNumero,
    String tipoEntrega = 'mesa',
    String? comentarios,
    bool esPersonal = false,
  }) async {
    var idMesa = mesaId;
    if ((idMesa == null || idMesa.isEmpty) &&
        mesaNumero != null &&
        mesaNumero > 0) {
      idMesa = mesas.where((m) => m.numero == mesaNumero).firstOrNull?.id;
    }

    // Un pedido de mesa sin mesa identificada se registraría como "Mesa 0".
    if (pedido.tipoPedido == 'mesa' &&
        (idMesa == null || !UuidHelper.isValid(idMesa))) {
      throw Exception(
        'No se pudo identificar la mesa del pedido. Actualiza las mesas y '
        'vuelve a elegirla.',
      );
    }

    DatosDelivery? delivery;
    if (pedido.tipoPedido == 'delivery') {
      final envio = lineas
          .where((l) => l.cartaId == cartaIdCargoDelivery)
          .fold(0.0, (s, l) => s + l.precioTotalLinea);
      delivery = DatosDelivery(
        direccion: pedido.direccionDelivery ?? '',
        referencia: pedido.referenciaDelivery,
        telefono: pedido.clienteCelular,
        costoEnvio: envio,
      );
    }

    final servicio = PedidoMozoService.instance;
    final creado = await servicio.crear(
      lineas: lineas,
      mesaId: idMesa,
      comentarios: comentarios,
      tipoEntrega: tipoEntrega,
      nombreCliente: pedido.clienteNombre,
      tipo: esPersonal ? 'empleado' : 'normal',
      delivery: delivery,
      base: pedido,
    );
    if (mesaNumero != null && mesaNumero > 0) {
      actualizarEstadoMesa(mesaNumero, 'ocupada');
    }
    return pedidos.firstWhere((p) => p.id == creado.id);
  }

  /// Carga los pedidos persistidos desde PostgreSQL, sincronizando pedidos activos y del día
  Future<List<Pedido>> cargarPedidos({
    bool soloActivos = false,
    String? fecha,
  }) async {
    final user = AuthService.instance.currentUser;
    if (AppConfig.usarApiPedidosMozo && user?.rol == AppRole.mesero) {
      try {
        await PedidoMozoService.instance.sincronizar();
      } catch (_) {
        // Error de red puntual: se mantiene lo que ya está en memoria.
      }
      return pedidos;
    }
    try {
      final queryParams = <String, String>{};
      if (soloActivos) queryParams['activos'] = 'true';
      if (fecha != null && fecha.isNotEmpty) queryParams['fecha'] = fecha;

      if (user?.sedeId != null && user!.sedeId!.isNotEmpty) {
        queryParams['sede_id'] = user.sedeId!;
      }

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final path = queryString.isEmpty
          ? '/api/pedidos'
          : '/api/pedidos?$queryString';

      final res = await _api.get(path);
      if (res is List) {
        final List<Pedido> listaPedidos = [];
        final Map<String, List<PedidoLine>> mapDetalles = {};

        for (final item in res) {
          if (item is Map<String, dynamic>) {
            final p = Pedido.fromJson(item);
            listaPedidos.add(p);

            final detList = item['detalles'];
            final lineas = <PedidoLine>[];
            if (detList is List) {
              lineas.addAll(
                detList
                    .whereType<Map<String, dynamic>>()
                    .map(_lineaConOpciones),
              );
            }
            if (p.costoDelivery > 0 &&
                !lineas.any((l) => l.cartaId == cartaIdCargoDelivery)) {
              lineas.add(
                PedidoLine(
                  id: 'delivery-${p.id}',
                  cartaId: cartaIdCargoDelivery,
                  nombrePlato: 'Cargo por delivery',
                  cantidad: 1,
                  modificadores: const [],
                  presentacion: null,
                  promocion: null,
                  comentario: null,
                  precioUnitario: p.costoDelivery,
                  descuentoAplicado: 0,
                  precioTotalLinea: p.costoDelivery,
                ),
              );
            }
            mapDetalles[p.id] = lineas;
          }
        }

        sincronizarPedidosDesdeServidor(listaPedidos, mapDetalles);
        // El administrador y el cajero leen el detalle completo (número de orden,
        // presentaciones, variantes): el servidor les abre esa lectura.
        if (AppConfig.usarApiPedidosMozo &&
            (user?.rol == AppRole.administrador ||
                user?.rol == AppRole.cajero)) {
          try {
            await PedidoMozoService.instance.sincronizar(sobreLegacy: true);
          } catch (_) {
            // Se mantienen los datos del servicio anterior.
          }
        }
        return pedidos;
      }
    } catch (e) {
      // Ignorar error de red puntual para mantener local
    }
    return pedidos;
  }

  /// Cambia el estado del pedido. Los estados del backend son: 'pendiente',
  /// 'servido', 'pagado', 'anulado' y 'devuelto'.
  Future<void> cambiarEstadoPedido(String pedidoId, String nuevoEstado) async {
    final propio = pedidos.where((p) => p.id == pedidoId).firstOrNull;
    if (AppConfig.usarApiPedidosMozo &&
        propio != null &&
        PedidoMozoService.instance.puedeOperar(propio) &&
        (nuevoEstado == 'servido' || nuevoEstado == 'pendiente')) {
      await PedidoMozoService.instance.cambiarEstado(pedidoId, nuevoEstado);
      return;
    }
    final body = {'estado': nuevoEstado};
    await _api.put('/api/pedidos/$pedidoId/estado', body: body);
    actualizarEstadoPedido(pedidoId, nuevoEstado);

    // Si se pagó, anuló o devolvió, recargar mesas para ver la liberación inmediata
    if (nuevoEstado == 'pagado' ||
        nuevoEstado == 'anulado' ||
        nuevoEstado == 'devuelto') {
      await CatalogService.instance.cargarMesas();
    }
  }

  /// Libera una mesa a 'disponible' directamente en PostgreSQL
  Future<void> liberarMesa(String mesaId, int numeroMesa) async {
    if (AppConfig.usarApiPedidosMozo && PedidoMozoService.instance.activo) {
      await PedidoMozoService.instance.liberarMesa(mesaId);
      actualizarEstadoMesa(numeroMesa, 'disponible');
      return;
    }
    final body = {'estado': 'disponible'};
    await _api.put('/api/mesas/$mesaId/estado', body: body);
    actualizarEstadoMesa(numeroMesa, 'disponible');
  }
}
