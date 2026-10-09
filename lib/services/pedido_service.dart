import '../data/mesas_store.dart';
import '../data/pedidos_store.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../utils/uuid_helper.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'catalog_service.dart';

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
  }) async {
    final user = AuthService.instance.currentUser;
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
    if ((idMesa == null || idMesa.isEmpty) && mesaNumero != null && mesaNumero > 0) {
      final encontrada = mesas.where((m) => m.numero == mesaNumero).firstOrNull;
      if (encontrada != null) {
        idMesa = encontrada.id;
      }
    }

    final detallesPayload = lineas.map((l) {
      final detUuid = (l.id.isNotEmpty && UuidHelper.isValid(l.id))
          ? l.id
          : UuidHelper.v7();
      final esCarta = l.cartaId.isNotEmpty && UuidHelper.isValid(l.cartaId) && !l.esLibre;
      final esPromo = l.promocion != null && UuidHelper.isValid(l.promocion!.id);
      final aplicaTaper = l.aplicaTaper || (taperId != null && taperId.isNotEmpty);
      final idTaper = l.taperId ?? taperId;
      final pTaper = l.aplicaTaper ? l.precioTaper : precioTaper;
      final tipoEnt = l.tipoEntrega.isNotEmpty ? l.tipoEntrega : tipoEntrega;

      return {
        'id': detUuid,
        'pedidos_id': pedidoUuid,
        if (esCarta) 'carta_id': l.cartaId,
        if (esPromo) 'promocion_id': l.promocion!.id,
        if (esPromo)
          'componentes': [for (final e in l.componentes) e.toJson()],
        'cantidad': l.cantidad,
        'tipo_entrega': tipoEnt,
        'aplica_taper': aplicaTaper,
        if (aplicaTaper && idTaper != null && idTaper.isNotEmpty && UuidHelper.isValid(idTaper))
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
        'precio': (l.precioUnitario * l.cantidad) + (aplicaTaper ? pTaper * l.cantidad : 0.0),
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
        if (mesaNumero != null && mesaNumero > 0)
          'mesa_numero': mesaNumero,
        if (comentarios != null && comentarios.isNotEmpty)
          'comentarios': comentarios,
        'version': 1,
      },
      if (idMesa != null && idMesa.isNotEmpty && UuidHelper.isValid(idMesa))
        'mesa_id': idMesa,
      if (mesaNumero != null && mesaNumero > 0)
        'mesa_numero': mesaNumero,
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

  /// Carga los pedidos persistidos desde PostgreSQL, sincronizando pedidos activos y del día
  Future<List<Pedido>> cargarPedidos({bool soloActivos = false, String? fecha}) async {
    try {
      final queryParams = <String, String>{};
      if (soloActivos) queryParams['activos'] = 'true';
      if (fecha != null && fecha.isNotEmpty) queryParams['fecha'] = fecha;

      final user = AuthService.instance.currentUser;
      if (user?.sedeId != null && user!.sedeId!.isNotEmpty) {
        queryParams['sede_id'] = user.sedeId!;
      }

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final path = queryString.isEmpty ? '/api/pedidos' : '/api/pedidos?$queryString';

      final res = await _api.get(path);
      if (res is List) {
        final List<Pedido> listaPedidos = [];
        final Map<String, List<PedidoLine>> mapDetalles = {};

        for (final item in res) {
          if (item is Map<String, dynamic>) {
            final p = Pedido.fromJson(item);
            listaPedidos.add(p);

            final detList = item['detalles'];
            if (detList is List) {
              final lineas = detList
                  .whereType<Map<String, dynamic>>()
                  .map((d) => PedidoLine.fromJson(d))
                  .toList();
              mapDetalles[p.id] = lineas;
            }
          }
        }

        sincronizarPedidosDesdeServidor(listaPedidos, mapDetalles);
        return listaPedidos;
      }
    } catch (e) {
      // Ignorar error de red puntual para mantener local
    }
    return pedidos;
  }

  /// Cambia el estado del pedido ('pendiente', 'servido', 'pagado', 'devuelto', 'anulado', etc.)
  Future<void> cambiarEstadoPedido(String pedidoId, String nuevoEstado) async {
    final body = {'estado': nuevoEstado};
    await _api.put('/api/pedidos/$pedidoId/estado', body: body);
    actualizarEstadoPedido(pedidoId, nuevoEstado);

    // Si se pagó, anuló o devolvió, recargar mesas para ver la liberación inmediata
    if (nuevoEstado == 'pagado' ||
        nuevoEstado == 'anulado' ||
        nuevoEstado == 'devuelto' ||
        nuevoEstado == 'cancelado') {
      await CatalogService.instance.cargarMesas();
    }
  }

  /// Libera una mesa a 'disponible' directamente en PostgreSQL
  Future<void> liberarMesa(String mesaId, int numeroMesa) async {
    final body = {'estado': 'disponible'};
    await _api.put('/api/mesas/$mesaId/estado', body: body);
    actualizarEstadoMesa(numeroMesa, 'disponible');
  }
}
