import '../data/mesas_por_liberar_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/app_role.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../utils/uuid_helper.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'catalog_service.dart';
import 'pedido_mozo_mapper.dart';

// Otro dispositivo (o el cajero) cambió el pedido antes que esta acción: la
// app ya recargó el pedido; hay que volver a intentar.
class PedidoCambioException implements Exception {
  final String mensaje;
  PedidoCambioException([String? mensaje])
    : mensaje =
          mensaje ??
          'El pedido cambió mientras lo editabas. Ya se actualizó, revisa e '
              'inténtalo de nuevo.';

  @override
  String toString() => mensaje;
}

// Resultado de validar el PIN de un supervisor.
class ResultadoPin {
  final bool valido;
  final String? usuarioId;
  final String? nombre;
  final String? mensaje;

  const ResultadoPin({
    required this.valido,
    this.usuarioId,
    this.nombre,
    this.mensaje,
  });
}

// Operaciones del mozo sobre `/api/v1/mozo/pedidos`. Cada operación envía la
// versión que la app conoce, y con la respuesta (el pedido completo) deja el
// estado local igual al del servidor.
class PedidoMozoService {
  PedidoMozoService._();
  static final PedidoMozoService instance = PedidoMozoService._();

  static const _base = '/api/v1/mozo/pedidos';
  final ApiClient _api = ApiClient.instance;

  // Marca de cambio por pedido para no pedir el detalle en cada consulta.
  final Map<String, String> _marcas = {};

  // Al cerrar sesión: las marcas eran de los pedidos del usuario anterior.
  void limpiarMarcas() => _marcas.clear();

  // ¿Los pedidos de esta sesión se manejan con la API del mozo?
  bool get activo {
    final rol = AuthService.instance.currentUser?.rol;
    return rol == AppRole.mesero || rol == AppRole.administrador;
  }

  // El mozo opera solo sus pedidos; el administrador, cualquiera.
  bool puedeOperar(Pedido p) {
    final u = AuthService.instance.currentUser;
    return u != null &&
        activo &&
        UuidHelper.isValid(p.id) &&
        (u.esAdmin || p.usuarioId == u.id);
  }

  // ---------------------------------------------------------------- lectura

  // Trae la lista liviana y solo pide el detalle de lo que cambió.
  //
  // Con [sobreLegacy] (administrador) la lista general de pedidos ya está en
  // memoria, traída del servicio anterior: se reemplazan los pedidos propios
  // por los del servidor nuevo (con sus versiones) y no se quita ninguno.
  Future<void> sincronizar({bool sobreLegacy = false}) async {
    final res = await _api.get(_base);
    if (res is! List) return;
    final vigentes = <String>{};
    for (final raw in res) {
      if (raw is! Map<String, dynamic>) continue;
      final id = raw['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      vigentes.add(id);
      final marca = '${raw['version']}|${raw['updated_at']}|${raw['total']}';
      final previo = pedidos.where((p) => p.id == id).firstOrNull;
      final total = (raw['total'] as num?)?.toDouble();
      final activo = raw['estado'] == 'pendiente' || raw['estado'] == 'servido';
      final igual =
          !(sobreLegacy && activo) &&
          previo != null &&
          detallesPorPedido[id] != null &&
          _marcas[id] == marca &&
          (total == null || (totalDePedido(id) - total).abs() < 0.005);
      if (igual) continue;
      try {
        await obtener(id);
        _marcas[id] = marca;
      } catch (_) {
        // Se reintenta en la siguiente consulta.
      }
    }
    // Las mesas cobradas que faltan liberar las informa el backend (ya filtradas
    // por usuario); no se deduce nada por los pedidos que dejan de venir.
    // Las mesas por liberar son del mozo y del administrador; el cajero solo lee.
    if (activo) await recargarMesasPorLiberar();
    if (sobreLegacy) return;
    pedidos.removeWhere((p) => !vigentes.contains(p.id));
    detallesPorPedido.removeWhere((id, _) => !vigentes.contains(id));
    _marcas.removeWhere((id, _) => !vigentes.contains(id));
  }

  // Detalle completo de un pedido.
  Future<PedidoMozoDetalle> obtener(String pedidoId) async {
    final res = await _api.get('$_base/$pedidoId');
    return _aplicar(res as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------- creación

  Future<PedidoMozoDetalle> crear({
    required List<PedidoLine> lineas,
    String? mesaId,
    String? comentarios,
    String tipoEntrega = 'mesa',
    String tipo = 'normal',
    String? nombreCliente,
    DatosDelivery? delivery,
    Pedido? base,
  }) async {
    final body = armarPedidoMozo(
      lineas: lineas,
      mesaId: mesaId,
      tipo: tipo,
      nombreCliente: nombreCliente,
      comentarios: comentarios,
      tipoEntrega: tipoEntrega,
      delivery: delivery,
    );
    final res = await _api.post(_base, body: body);
    if (res is! Map<String, dynamic>) {
      throw Exception('Error inesperado al crear el pedido en el servidor');
    }
    return _aplicar(res, base: base);
  }

  // Agrega un producto (y su táper, en fila aparte) a un pedido existente.
  Future<PedidoMozoDetalle> agregarProducto(
    String pedidoId,
    PedidoLine linea, {
    String tipoEntrega = 'mesa',
  }) async {
    final p = _pedido(pedidoId);
    final items = itemsDeLinea(
      linea,
      tipoEntrega: tipoEntrega,
      conDelivery: p?.tipoPedido == 'delivery',
      // (el tipo de entrega del pedido fuerza el de cada fila)
    );
    if (items.isEmpty) {
      throw Exception('Este tipo de línea no se puede agregar al pedido');
    }
    PedidoMozoDetalle? ultimo;
    for (final it in items) {
      ultimo = await _enviar(
        pedidoId,
        () => _api.post('$_base/$pedidoId/items', body: {'item': it}),
      );
    }
    return ultimo!;
  }

  // ---------------------------------------------------------------- filas

  Future<PedidoMozoDetalle> cambiarCantidad(
    String pedidoId,
    PedidoLine linea,
    int cantidad,
  ) => _enviar(
    pedidoId,
    () => _api.patch(
      '$_base/$pedidoId/items/${linea.id}/cantidad',
      body: {'cantidad': cantidad, 'version': linea.version},
    ),
  );

  // Pedido de personal: cambia el precio por unidad de un plato.
  Future<PedidoMozoDetalle> precioPersonalFila(
    String pedidoId,
    PedidoLine linea,
    double precio,
  ) => _enviar(
    pedidoId,
    () => _api.patch(
      '$_base/$pedidoId/items/${linea.id}/precio-personal',
      body: {'precio_personal': precio, 'version': linea.version},
    ),
  );

  Future<PedidoMozoDetalle> comentarioFila(
    String pedidoId,
    PedidoLine linea,
    String? comentario,
  ) => _enviar(
    pedidoId,
    () => _api.patch(
      '$_base/$pedidoId/items/${linea.id}/comentario',
      body: {'comentario': comentario ?? '', 'version': linea.version},
    ),
  );

  Future<PedidoMozoDetalle> marcarServido(
    String pedidoId,
    PedidoLine linea,
    bool servido,
  ) => _enviar(
    pedidoId,
    () => _api.patch(
      '$_base/$pedidoId/items/${linea.id}/servido',
      body: {'servido': servido, 'version': linea.version},
    ),
  );

  Future<PedidoMozoDetalle> tipoEntregaFila(
    String pedidoId,
    PedidoLine linea,
    String tipoEntrega, {
    bool aplicaTaper = false,
  }) => _enviar(
    pedidoId,
    () => _api.patch(
      '$_base/$pedidoId/items/${linea.id}/tipo-entrega',
      body: {'tipo_entrega': tipoEntrega, 'aplica_taper': aplicaTaper},
    ),
  );

  // Anula la fila entera o solo [cantidad] unidades.
  Future<PedidoMozoDetalle> anularFila(
    String pedidoId,
    PedidoLine linea, {
    required int cantidad,
    required String motivo,
    String? urlEvidencia,
    bool fueServido = false,
  }) => _enviar(
    pedidoId,
    () => _api.patch(
      '$_base/$pedidoId/items/${linea.id}/anular',
      body: {
        'cantidad_anular': cantidad,
        'comentario': motivo,
        'url_evidencia': ?urlEvidencia,
        'fue_servido': fueServido,
        'version': linea.version,
      },
    ),
  );

  // ---------------------------------------------------------------- pedido

  Future<PedidoMozoDetalle> comentarioPedido(
    String pedidoId,
    String? comentarios,
  ) => _enviar(
    pedidoId,
    () => _api.patch(
      '$_base/$pedidoId/comentarios',
      body: {'comentarios': comentarios ?? '', 'version': _version(pedidoId)},
    ),
  );

  // [estado]: 'pendiente' o 'servido'.
  Future<PedidoMozoDetalle> cambiarEstado(String pedidoId, String estado) =>
      _enviar(
        pedidoId,
        () => _api.patch(
          '$_base/$pedidoId/estado',
          body: {'estado': estado, 'version': _version(pedidoId)},
        ),
      );

  Future<void> anularPedido(
    String pedidoId, {
    required String motivo,
    String? urlEvidencia,
    bool fueServido = false,
  }) async {
    try {
      await _api.patch(
        '$_base/$pedidoId/anular',
        body: {
          'comentario': motivo,
          'url_evidencia': ?urlEvidencia,
          'fue_servido': fueServido,
          'version': _version(pedidoId),
        },
      );
    } on ApiException catch (e) {
      await _traducir(e, pedidoId);
    }
    actualizarEstadoPedido(pedidoId, 'anulado');
    await CatalogService.instance.cargarMesas();
    _marcas.remove(pedidoId);
  }

  Future<PedidoMozoDetalle> cambiarMesa(
    String pedidoId,
    String nuevaMesaId,
  ) async {
    final d = await _enviar(
      pedidoId,
      () => _api.patch(
        '$_base/$pedidoId/cambiar-mesa',
        body: {'nueva_mesa_id': nuevaMesaId},
      ),
    );
    await CatalogService.instance.cargarMesas();
    return d;
  }

  // [tipoPedido]: 'mesa', 'llevar' o 'delivery'.
  Future<PedidoMozoDetalle> tipoEntregaPedido(
    String pedidoId,
    String tipoPedido, {
    String? nuevaMesaId,
    bool aplicaTaper = false,
    DatosDelivery? delivery,
  }) async {
    final d = await _enviar(
      pedidoId,
      () => _api.patch(
        '$_base/$pedidoId/tipo-entrega',
        body: {
          'tipo_pedido': tipoPedido,
          'nueva_mesa_id': ?nuevaMesaId,
          'aplica_taper': aplicaTaper,
          'delivery': ?delivery?.toJson(),
        },
      ),
    );
    await CatalogService.instance.cargarMesas();
    return d;
  }

  // ---------------------------------------------------------------- descuentos

  // Descuento al pedido, o a una fila si se indica [detalleId]. Los descuentos
  // manuales exigen el permiso de otorgar descuentos (propio o de un
  // supervisor, con [autorizoId]).
  Future<PedidoMozoDetalle> aplicarDescuento(
    String pedidoId, {
    required String motivo,
    required bool porcentaje,
    required double valor,
    String? detalleId,
    String? autorizoId,
  }) => _enviar(
    pedidoId,
    () => _api.post(
      '$_base/$pedidoId/descuentos',
      body: {
        'pedidos_detalle_id': ?detalleId,
        'motivo': motivo,
        'tipo': porcentaje ? 'porcentaje' : 'monto',
        'valor': valor,
        'usuario_autorizo_id': ?autorizoId,
      },
    ),
  );

  Future<PedidoMozoDetalle> quitarDescuento(
    String pedidoId,
    String descuentoId,
  ) => _enviar(
    pedidoId,
    () => _api.delete('$_base/$pedidoId/descuentos/$descuentoId'),
  );

  // ---------------------------------------------------------------- apoyo

  // Valida el PIN de un supervisor (permiso de otorgar descuentos).
  Future<ResultadoPin> validarPin(
    String pin, {
    String permiso = 'OTORGAR.DESCUENTO',
  }) async {
    try {
      final res = await _api.post(
        '/api/auth/validar-pin-supervisor',
        body: {'pin': pin, 'permiso_requerido': permiso},
      );
      final m = res as Map<String, dynamic>;
      return ResultadoPin(
        valido: m['valido'] == true,
        usuarioId: m['usuario_autorizo_id']?.toString(),
        nombre: m['nombre']?.toString(),
        mensaje: m['mensaje']?.toString(),
      );
    } on ApiException catch (e) {
      final det = e.details;
      final msg = det is Map ? (det['mensaje'] ?? det['error']) : null;
      return ResultadoPin(valido: false, mensaje: msg?.toString() ?? e.message);
    }
  }

  // Sube la foto de evidencia de una anulación y devuelve su URL.
  Future<String> subirEvidencia(List<int> bytes, String nombreArchivo) async {
    final res = await _api.subirArchivo(
      '/api/v1/uploads/evidencias',
      bytes: bytes,
      nombreArchivo: nombreArchivo,
    );
    final url = res is Map ? res['url']?.toString() : null;
    if (url == null || url.isEmpty) {
      throw Exception('El servidor no devolvió la dirección de la foto');
    }
    return url;
  }

  // Libera la mesa; con [forzar] (solo administrador) aunque tenga pedidos.
  Future<void> liberarMesa(String mesaId, {bool forzar = false}) async {
    await _api.post(
      '/api/v1/mozo/mesas/$mesaId/liberar',
      body: {'forzar': forzar},
    );
    await CatalogService.instance.cargarMesas();
  }

  // ---------------------------------------------------------------- interno

  Pedido? _pedido(String id) => pedidos.where((p) => p.id == id).firstOrNull;

  int _version(String pedidoId) => _pedido(pedidoId)?.version ?? 1;

  Future<PedidoMozoDetalle> _enviar(
    String pedidoId,
    Future<dynamic> Function() llamada,
  ) async {
    try {
      final res = await llamada();
      if (res is Map<String, dynamic> && res['items'] is List) {
        return _aplicar(res);
      }
      return await obtener(pedidoId);
    } on ApiException catch (e) {
      return _traducir(e, pedidoId);
    }
  }

  // 409 sin código = alguien más cambió el pedido: se recarga y se avisa. Los
  // demás errores (incluida la falta de stock, con `codigo`) siguen como están.
  Future<Never> _traducir(ApiException e, String pedidoId) async {
    final det = e.details;
    final conCodigo = det is Map && det['codigo'] != null;
    if (e.statusCode == 409 && !conCodigo) {
      try {
        await obtener(pedidoId);
      } catch (_) {}
      throw PedidoCambioException(
        e.message.isNotEmpty
            ? '${e.message}. Ya se actualizó el pedido.'
            : null,
      );
    }
    throw e;
  }

  // Deja el pedido del servidor en los stores locales.
  PedidoMozoDetalle _aplicar(Map<String, dynamic> json, {Pedido? base}) {
    final d = parsearDetalleMozo(json);
    final previo = base ?? _pedido(d.id);
    // El tipo de entrega, el cliente y los datos de envío vienen del backend.
    final entrega = d.tipoEntrega;
    final nuevo = Pedido(
      id: d.id,
      // El número de orden del día que da el servidor (igual al de la comanda).
      numeroPedido:
          d.codigoOrden?.replaceFirst('#', '') ??
          previo?.numeroPedido ??
          d.id.substring(0, d.id.length < 4 ? d.id.length : 4),
      mesaNumero: d.mesaNumero ?? 0,
      mesasUnidas: previo?.mesasUnidas ?? const [],
      estado: d.estado,
      tipoPedido: entrega,
      fechaPedido: d.inicio?.toLocal() ?? previo?.fechaPedido ?? DateTime.now(),
      notas: d.comentarios,
      clienteNombre: d.nombreCliente,
      clienteCelular: d.delivery?.telefono,
      direccionDelivery: d.delivery?.direccion,
      referenciaDelivery: d.delivery?.referencia,
      // Si el pedido volvió a un estado abierto, el cronómetro vuelve a correr.
      fechaFinalizacion: Pedido.estadosTerminales.contains(d.estado)
          ? (d.fin ?? previo?.fechaFinalizacion)
          : null,
      usuarioId: d.usuarioId,
      version: d.version,
      mozoNombre: d.mozoNombre,
      esEmpleado: d.tipo == 'empleado',
    );

    // La propina y el tupper global viven solo en la app: se conservan.
    final propias = [
      for (final l in detallesPorPedido[d.id] ?? const <PedidoLine>[])
        if (esLineaPropina(l) || esLineaTupper(l)) l,
    ];
    final antes = detallesPorPedido[d.id] ?? const <PedidoLine>[];
    for (final l in antes) {
      lineasEntregadas.remove(l.id);
    }
    lineasEntregadas.addAll(d.servidas);

    final i = pedidos.indexWhere((p) => p.id == d.id);
    if (i == -1) {
      pedidos.insert(0, nuevo);
    } else {
      pedidos[i] = nuevo;
    }
    detallesPorPedido[d.id] = [...d.lineas, ...propias];
    return d;
  }

  // Auditoría de anulaciones para inventario
  Future<List<Map<String, dynamic>>> obtenerAnulaciones({
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final params = <String, String>{};
    if (desde != null) params['fecha_desde'] = desde.toIso8601String();
    if (hasta != null) params['fecha_hasta'] = hasta.toIso8601String();
    final res = await _api.get(
      '/api/inventario/anulaciones',
      queryParams: params.isEmpty ? null : params,
    );
    if (res is List) {
      return res.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }
}
