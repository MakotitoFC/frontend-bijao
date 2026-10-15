import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/mesas_por_liberar_store.dart';
import 'api_client.dart';
import 'catalog_service.dart';
import 'disponibilidad_service.dart';
import 'eventos/evento_sse.dart';
import 'eventos/flujo.dart';
import 'pedido_service.dart';

// Qué hay que volver a leer del servidor cuando llega un evento.
class AccionesDeEvento {
  final bool pedidos;
  final bool mesas;
  final bool stock;

  const AccionesDeEvento({
    this.pedidos = false,
    this.mesas = false,
    this.stock = false,
  });

  bool get ninguna => !pedidos && !mesas && !stock;

  AccionesDeEvento unir(AccionesDeEvento o) => AccionesDeEvento(
    pedidos: pedidos || o.pedidos,
    mesas: mesas || o.mesas,
    stock: stock || o.stock,
  );
}

// Tabla de eventos del backend y lo que cambia cada uno.
AccionesDeEvento traducirEvento(String nombre) {
  switch (nombre) {
    case 'PEDIDO_NUEVO':
    case 'PRODUCTO_AGREGADO':
    case 'PEDIDO_ACTUALIZADO':
    case 'PEDIDO_ANULADO':
      // Pedir o anular cambia el stock; nuevo o anulado también la mesa.
      return AccionesDeEvento(
        pedidos: true,
        stock: true,
        mesas: nombre == 'PEDIDO_NUEVO' || nombre == 'PEDIDO_ANULADO',
      );
    case 'ITEM_SERVIDO':
    case 'PEDIDO_ESTADO_CAMBIADO':
      return const AccionesDeEvento(pedidos: true);
    case 'CAMBIO_MESA':
      return const AccionesDeEvento(pedidos: true, mesas: true);
    case 'MESA_LIBERADA':
      return const AccionesDeEvento(mesas: true);
    case 'PLATO_AGOTADO':
    case 'STOCK_ACTUALIZADO':
    case 'APERTURA_DIARIA_COMPLETA':
      return const AccionesDeEvento(stock: true);
    default:
      return const AccionesDeEvento();
  }
}

// Cambios en vivo: mantiene abierto el flujo de eventos del servidor
// (`GET /api/v1/eventos`) y, cuando algo cambia (un pedido nuevo, una mesa
// liberada, un plato agotado...), vuelve a leer solo eso. Si la conexión se
// cae, reintenta sola y las pantallas siguen consultando cada cierto tiempo.
class EventosService {
  EventosService._();
  static final EventosService instance = EventosService._();

  // ¿Hay conexión viva con el flujo de eventos?
  final ValueNotifier<bool> conectado = ValueNotifier(false);
  // Sube cada vez que, por un evento, se actualizaron datos: las pantallas se
  // redibujan al notarlo.
  final ValueNotifier<int> revision = ValueNotifier(0);

  bool _activo = false;
  StreamSubscription<EventoSse>? _suscripcion;
  Timer? _reintento;
  Timer? _agrupar;
  int _intentos = 0;
  AccionesDeEvento _pendientes = const AccionesDeEvento();

  void iniciar() {
    if (_activo) return;
    _activo = true;
    _intentos = 0;
    _conectar();
  }

  void detener() {
    _activo = false;
    _reintento?.cancel();
    _agrupar?.cancel();
    _suscripcion?.cancel();
    _suscripcion = null;
    _pendientes = const AccionesDeEvento();
    conectado.value = false;
  }

  Future<void> _conectar() async {
    if (!_activo) return;
    final token = ApiClient.instance.accessToken;
    if (token == null || token.isEmpty) {
      _programarReintento();
      return;
    }
    final url = Uri.parse('${ApiClient.instance.baseUrl}/api/v1/eventos');
    await _suscripcion?.cancel();
    try {
      _suscripcion = abrirFlujoDeEventos(url: url, token: token).listen(
        _recibir,
        onError: _alFallar,
        onDone: () => _alFallar(null),
        cancelOnError: true,
      );
    } catch (e) {
      _alFallar(e);
    }
  }

  void _recibir(EventoSse evento) {
    if (evento.nombre == 'conexion_establecida') {
      _intentos = 0;
      conectado.value = true;
      // Pudo haber cambios mientras no había conexión: se lee todo una vez.
      _pendientes = const AccionesDeEvento(
        pedidos: true,
        mesas: true,
        stock: true,
      );
      _agendar();
      return;
    }
    if (evento.nombre == 'MESA_LIBERADA') {
      final mesaId = evento.json?['mesa_id']?.toString();
      if (mesaId != null) quitarMesaPorLiberar(mesaId);
    }
    final acciones = traducirEvento(evento.nombre);
    if (acciones.ninguna) return;
    _pendientes = _pendientes.unir(acciones);
    _agendar();
  }

  // Varios eventos seguidos (por ejemplo, un pedido con muchas filas) se
  // resuelven con una sola lectura.
  void _agendar() {
    _agrupar?.cancel();
    _agrupar = Timer(const Duration(milliseconds: 300), _aplicar);
  }

  Future<void> _aplicar() async {
    final acciones = _pendientes;
    _pendientes = const AccionesDeEvento();
    try {
      await Future.wait([
        if (acciones.pedidos) PedidoService.instance.cargarPedidos(),
        if (acciones.mesas) CatalogService.instance.cargarMesas(),
        if (acciones.stock) DisponibilidadService.instance.cargarHoy(),
      ]);
    } catch (_) {
      // Las pantallas vuelven a consultar por su cuenta.
    }
    revision.value++;
  }

  Future<void> _alFallar(Object? error) async {
    conectado.value = false;
    await _suscripcion?.cancel();
    _suscripcion = null;
    if (!_activo) return;
    // Sesión vencida: una consulta común renueva el token antes de reintentar.
    if (error is ErrorFlujoEventos && error.codigo == 401) {
      try {
        await ApiClient.instance.get('/api/auth/me');
      } catch (_) {}
    }
    _programarReintento();
  }

  // 2, 4, 8, 16 y, como máximo, 30 segundos entre intentos.
  void _programarReintento() {
    if (!_activo) return;
    _intentos++;
    final segundos = (1 << (_intentos < 5 ? _intentos : 5)).clamp(2, 30);
    _reintento?.cancel();
    _reintento = Timer(Duration(seconds: segundos), _conectar);
  }
}
