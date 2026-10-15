import 'dart:developer' as developer;

import '../data/promociones_store.dart';
import '../models/promocion.dart';
import '../models/promocion_componente.dart';
import 'api_client.dart';

// Promociones guardadas en el backend: `promocion`, `promocion_componente` y
// `promocion_componente_opcion`. La copia en memoria vive en
// `promociones_store.dart`; cada cambio se envía primero al servidor y solo si
// sale bien se refleja aquí.
class PromocionService {
  PromocionService._();
  static final PromocionService instance = PromocionService._();

  final ApiClient _api = ApiClient.instance;

  // ---------------------------------------------------------------- lectura

  Future<void> cargar() async {
    try {
      final res = await _api.get('/api/promociones');
      if (res is! List) return;
      final r = parsearPromociones(res);
      reemplazarPromociones(
        nuevas: r.promociones,
        componentes: r.componentes,
        opciones: r.opciones,
      );
    } catch (e) {
      developer.log('[PromocionService] Error al cargar promociones: $e');
    }
  }

  // ------------------------------------------------------------ promociones

  Future<Promocion> crearPromocion(Promocion p) async {
    final res = await _api.post('/api/promociones', body: p.aBackend());
    final creada = Promocion.fromJson(res as Map<String, dynamic>);
    agregarPromocion(creada);
    return creada;
  }

  Future<Promocion> actualizarPromocionEnServidor(Promocion p) async {
    final res = await _api.put(
      '/api/promociones/${p.id}',
      body: p.aBackend(incluirId: false),
    );
    final actualizada = Promocion.fromJson(res as Map<String, dynamic>);
    actualizarPromocion(actualizada);
    return actualizada;
  }

  Future<void> eliminarPromocionEnServidor(String id) async {
    await _api.delete('/api/promociones/$id');
    eliminarPromocion(id);
  }

  // ------------------------------------------------------------ componentes

  Future<PromocionComponente> crearComponente(PromocionComponente c) async {
    final res = await _api.post(
      '/api/promociones/${c.promocionId}/componentes',
      body: {
        'id': c.id,
        'promocion_id': c.promocionId,
        'subcategoria_id': c.subcategoriaId,
        'cantidad': c.cantidad,
      },
    );
    final creado = PromocionComponente.fromJson(res as Map<String, dynamic>);
    agregarComponente(creado);
    return creado;
  }

  Future<void> actualizarComponenteEnServidor(PromocionComponente c) async {
    await _api.put(
      '/api/promocion-componentes/${c.id}',
      body: {'subcategoria_id': c.subcategoriaId, 'cantidad': c.cantidad},
    );
    actualizarComponente(c);
  }

  Future<void> eliminarComponenteEnServidor(String id) async {
    await _api.delete('/api/promocion-componentes/$id');
    eliminarComponente(id);
  }

  // --------------------------------------------------------------- opciones

  // La primera opción de un componente es la incluida; las siguientes, cambios.
  Future<PromocionOpcion> crearOpcion(PromocionOpcion o) async {
    final esPrimera = opcionesDe(o.componenteId, soloActivas: true).isEmpty;
    final nueva = o.copyWith(esFijo: esPrimera);
    final res = await _api.post(
      '/api/promocion-componentes/${nueva.componenteId}/opciones',
      body: nueva.aBackend(),
    );
    final creada = PromocionOpcion.fromJson(res as Map<String, dynamic>);
    agregarOpcion(creada);
    return creada;
  }

  Future<void> actualizarOpcionEnServidor(PromocionOpcion o) async {
    await _api.put(
      '/api/promocion-opciones/${o.id}',
      body: o.aBackend(incluirId: false),
    );
    actualizarOpcion(o);
  }

  Future<void> eliminarOpcionEnServidor(PromocionOpcion o) async {
    await _api.delete('/api/promocion-opciones/${o.id}');
    eliminarOpcion(o.id);
    // Si era la incluida, la primera que quede activa pasa a serlo.
    final siguiente = opcionIncluida(o.componenteId);
    if (o.esFijo && siguiente != null && !siguiente.esFijo) {
      await actualizarOpcionEnServidor(siguiente.copyWith(esFijo: true));
    }
  }

  // El producto incluido de un componente pasa a ser [opcion].
  Future<void> hacerIncluidaEnServidor(PromocionOpcion opcion) async {
    for (final o in opcionesDe(opcion.componenteId)) {
      final debeSerFija = o.id == opcion.id;
      if (o.esFijo != debeSerFija) {
        await actualizarOpcionEnServidor(o.copyWith(esFijo: debeSerFija));
      }
    }
    hacerIncluida(opcion.id);
  }
}

// Lo que devuelve `GET /api/promociones`: por promoción, sus componentes y las
// opciones de cada componente.
({
  List<Promocion> promociones,
  List<PromocionComponente> componentes,
  List<PromocionOpcion> opciones,
})
parsearPromociones(List<dynamic> json) {
  final promos = <Promocion>[];
  final componentes = <PromocionComponente>[];
  final opciones = <PromocionOpcion>[];
  for (final item in json) {
    if (item is! Map<String, dynamic>) continue;
    final promo = item['promocion'];
    if (promo is! Map<String, dynamic>) continue;
    promos.add(Promocion.fromJson(promo));
    final lista = item['promocion_componentes'];
    if (lista is! List) continue;
    var orden = 1;
    for (final c in lista.whereType<Map<String, dynamic>>()) {
      final componente = PromocionComponente.fromJson(c)
          .copyWith(orden: orden++);
      componentes.add(componente);
      final ops = c['componente_opcion'];
      if (ops is List) {
        final lista = ops
            .whereType<Map<String, dynamic>>()
            .map(PromocionOpcion.fromJson)
            .toList();
        // La opción incluida va primero dentro de su componente.
        opciones
          ..addAll(lista.where((o) => o.esFijo))
          ..addAll(lista.where((o) => !o.esFijo));
      }
    }
  }
  return (promociones: promos, componentes: componentes, opciones: opciones);
}
