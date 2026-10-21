import 'dart:developer' as developer;

import '../data/cartas_store.dart';
import '../data/catalogos_store.dart';
import '../data/configuracion_store.dart';
import '../data/compras_store.dart';
import '../data/categorias_store.dart';
import '../data/inventario_store.dart';
import '../data/mesas_store.dart';
import '../data/presentaciones_store.dart';
import '../data/subcategorias_store.dart';
import '../data/variantes_store.dart';
import '../data/utensilios_store.dart';
import '../models/carta_item.dart';
import '../models/carta_presentacion.dart';
import '../models/carta_variante.dart';
import '../models/unidad_bebida.dart';
import '../models/compra.dart';
import '../models/compra_detalle.dart';
import '../models/inventario_movimiento.dart';
import '../models/tipo_movimiento.dart';
import '../models/categoria_comida.dart';
import '../models/medio_pago.dart';
import '../models/mesa.dart';
import '../models/pago_cuenta_empleado.dart';
import '../models/producto_inventario.dart';
import '../models/rbac.dart';
import '../models/subcategoria.dart';
import '../models/taper.dart';
import '../models/tipo_producto.dart';
import '../models/unidad_producto.dart';
import '../models/utensilio_roto.dart';
import '../models/zona.dart';
import '../utils/uuid_helper.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'disponibilidad_service.dart';
import 'promocion_service.dart';

class CatalogService {
  CatalogService._();
  static final CatalogService instance = CatalogService._();

  final ApiClient _api = ApiClient.instance;

  // Lista en memoria de tapers disponibles
  final List<Taper> tapers = [];

  // Lista en memoria de zonas disponibles
  final List<Zona> zonas = [];

  // ==========================================
  // CARGA COMPLETA DE CATÁLOGOS
  // ==========================================

  Future<void> cargarCatalogos() async {
    try {
      await Future.wait([
        cargarZonas(),
        cargarMesas(),
        cargarCategorias(),
        cargarSubcategorias(),
        cargarUnidadesBebida(),
        cargarCarta(),
        DisponibilidadService.instance.cargarHoy(),
        cargarVariantes(),
        cargarPresentaciones(),
        cargarCompras(),
        cargarTapers(),
        cargarTiposProducto(),
        cargarUnidadesProducto(),
        cargarProductosInventario(),
        cargarTiposMovimiento(),
        cargarUtensiliosRotos(),
        cargarMediosPago(),
        PromocionService.instance.cargar(),
      ]);
      developer.log('[CatalogService] Catálogos cargados exitosamente');
    } catch (e) {
      developer.log('[CatalogService] Error cargando catálogos: $e');
    }
  }

  // ==========================================
  // MÉTODOS DE PAGO
  // ==========================================

  Future<void> cargarMediosPago() async {
    try {
      final res = await _api.get('/api/medios-pago');
      if (res is List) {
        mediosPago
          ..clear()
          ..addAll(
            res.whereType<Map<String, dynamic>>().map(MedioPago.fromJson),
          );
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener métodos de pago: $e');
    }
  }

  Future<MedioPago> crearMedioPago({
    required String nombre,
    String? descripcion,
    bool aplicaComision = false,
    double porcentajeComision = 0,
  }) async {
    final sedeId = AuthService.instance.currentUser?.sedeId;
    final res = await _api.post(
      '/api/medios-pago',
      body: {
        'id': UuidHelper.v7(),
        'medio_pago': nombre.trim(),
        if (descripcion != null && descripcion.trim().isNotEmpty)
          'descripcion': descripcion.trim(),
        'aplica_comision': aplicaComision,
        'porcentaje_comision': aplicaComision ? porcentajeComision : 0,
        'estado': true,
        if (sedeId != null && sedeId.isNotEmpty) 'sede_id': sedeId,
      },
    );
    final nuevo = MedioPago.fromJson(res as Map<String, dynamic>);
    mediosPago.add(nuevo);
    return nuevo;
  }

  Future<MedioPago> actualizarMedioPago(
    String id, {
    String? nombre,
    String? descripcion,
    bool? aplicaComision,
    double? porcentajeComision,
    bool? activo,
  }) async {
    final res = await _api.put(
      '/api/medios-pago/$id',
      body: {
        if (nombre != null) 'medio_pago': nombre.trim(),
        'descripcion': ?descripcion?.trim(),
        'aplica_comision': ?aplicaComision,
        'porcentaje_comision': ?porcentajeComision,
        'estado': ?activo,
      },
    );
    final actualizado = MedioPago.fromJson(res as Map<String, dynamic>);
    final i = mediosPago.indexWhere((m) => m.id == id);
    if (i != -1) mediosPago[i] = actualizado;
    return actualizado;
  }

  Future<void> eliminarMedioPago(String id) async {
    await _api.delete('/api/medios-pago/$id');
    mediosPago.removeWhere((m) => m.id == id);
  }

  // ==========================================
  // ZONAS
  // ==========================================

  Future<List<Zona>> cargarZonas() async {
    try {
      final res = await _api.get('/api/zonas');
      if (res is List) {
        final List<Zona> lista = res
            .map((item) => Zona.fromJson(item as Map<String, dynamic>))
            .toList();

        zonas
          ..clear()
          ..addAll(lista);

        // Sincronizar zonas activas en el store de la UI
        final activas = zonas
            .where((z) => z.estado)
            .map((z) => z.zona)
            .toList();
        zonasMesas
          ..clear()
          ..addAll(activas.isNotEmpty ? activas : ['Salón Principal']);

        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener zonas: $e');
    }
    return zonas;
  }

  Future<Zona> crearZona({required String nombre, bool estado = true}) async {
    final clientUuid = UuidHelper.v7();
    final body = {'id': clientUuid, 'zona': nombre.trim(), 'estado': estado};

    final res = await _api.post('/api/zonas', body: body);
    if (res is Map<String, dynamic>) {
      final nueva = Zona.fromJson(res);
      zonas.removeWhere((z) => z.id == nueva.id);
      zonas.add(nueva);
      if (nueva.estado && !zonasMesas.contains(nueva.zona)) {
        zonasMesas.add(nueva.zona);
      }
      return nueva;
    }
    throw Exception('Error al crear zona');
  }

  Future<Zona> actualizarZona(String id, {String? nombre, bool? estado}) async {
    final body = <String, dynamic>{};
    if (nombre != null) body['zona'] = nombre.trim();
    if (estado != null) body['estado'] = estado;

    final res = await _api.put('/api/zonas/$id', body: body);
    if (res is Map<String, dynamic>) {
      final actualizada = Zona.fromJson(res);
      final idx = zonas.indexWhere((z) => z.id == id);
      if (idx != -1) {
        zonas[idx] = actualizada;
      }
      final activas = zonas.where((z) => z.estado).map((z) => z.zona).toList();
      zonasMesas
        ..clear()
        ..addAll(activas.isNotEmpty ? activas : ['Salón Principal']);
      return actualizada;
    }
    throw Exception('Error al actualizar zona');
  }

  Future<void> eliminarZona(String id, String nombre) async {
    await _api.delete('/api/zonas/$id');
    zonas.removeWhere((z) => z.id == id);
    zonasMesas.remove(nombre);
  }

  // ==========================================
  // MESAS
  // ==========================================

  Future<List<Mesa>> cargarMesas() async {
    try {
      final res = await _api.get('/api/mesas');
      if (res is List) {
        final List<Mesa> lista = res
            .map((item) => Mesa.fromJson(item as Map<String, dynamic>))
            .toList();

        mesas
          ..clear()
          ..addAll(lista)
          ..sort((a, b) => a.numero.compareTo(b.numero));

        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener mesas: $e');
    }
    return mesas;
  }

  Future<Mesa> crearMesa({
    required int numero,
    int capacidad = 0,
    String? zonaId,
    String zona = 'Salón Principal',
  }) async {
    final clientUuid = UuidHelper.v7();
    String? idZona = zonaId;
    if (idZona == null || idZona.isEmpty) {
      final match = zonas.firstWhere(
        (z) => z.zona.toLowerCase() == zona.toLowerCase(),
        orElse: () => zonas.isNotEmpty
            ? zonas.first
            : const Zona(
                id: '11111111-2222-3333-4444-555555555555',
                zona: 'Salón Principal',
              ),
      );
      idZona = match.id;
    }

    final body = {
      'id': clientUuid,
      'numero': numero,
      'estado': 'disponible',
      'numero_sillas': capacidad,
      'zona_id': idZona,
    };

    final res = await _api.post('/api/mesas', body: body);
    if (res is Map<String, dynamic>) {
      final nueva = Mesa.fromJson(res)
          .copyWith(capacidad: capacidad, zona: zona, zonaId: idZona);
      mesas
        ..removeWhere((m) => m.id == nueva.id || m.numero == nueva.numero)
        ..add(nueva)
        ..sort((a, b) => a.numero.compareTo(b.numero));
      return nueva;
    }
    throw Exception('Error al crear mesa');
  }

  Future<Mesa> actualizarMesa(
    String id, {
    int? numero,
    String? estado,
    int? capacidad,
    String? zonaId,
    String? zona,
  }) async {
    final body = <String, dynamic>{};
    if (numero != null) body['numero'] = numero;
    if (capacidad != null) body['numero_sillas'] = capacidad;
    if (estado != null) {
      body['estado'] = (estado == 'libre') ? 'disponible' : estado;
    }
    if (zonaId != null && zonaId.isNotEmpty) {
      body['zona_id'] = zonaId;
    } else if (zona != null) {
      final match = zonas.firstWhere(
        (z) => z.zona.toLowerCase() == zona.toLowerCase(),
        orElse: () => zonas.isNotEmpty
            ? zonas.first
            : const Zona(
                id: '11111111-2222-3333-4444-555555555555',
                zona: 'Salón Principal',
              ),
      );
      body['zona_id'] = match.id;
    }

    final res = await _api.put('/api/mesas/$id', body: body);
    if (res is Map<String, dynamic>) {
      final actualizada = Mesa.fromJson(res).copyWith(
        capacidad: capacidad,
        zona: zona,
        zonaId: body['zona_id'] as String?,
      );
      final idx = mesas.indexWhere((m) => m.id == id);
      if (idx != -1) {
        mesas[idx] = actualizada;
      }
      return actualizada;
    }
    throw Exception('Error al actualizar mesa');
  }

  Future<void> eliminarMesa(String id, int numero) async {
    await _api.delete('/api/mesas/$id');
    mesas.removeWhere((m) => m.id == id || m.numero == numero);
  }

  // ==========================================
  // CATEGORIAS
  // ==========================================

  Future<List<CategoriaComida>> cargarCategorias() async {
    try {
      final res = await _api.get('/api/categorias');
      if (res is List) {
        final List<CategoriaComida> lista = res
            .map(
              (item) => CategoriaComida.fromJson(item as Map<String, dynamic>),
            )
            .toList();

        categorias
          ..clear()
          ..addAll(lista);

        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener categorías: $e');
    }
    return categorias;
  }

  Future<CategoriaComida> crearCategoria(String nombre) async {
    final clientUuid = UuidHelper.v7();
    final body = {'id': clientUuid, 'categoria': nombre.trim()};

    final res = await _api.post('/api/categorias', body: body);
    if (res is Map<String, dynamic>) {
      final nueva = CategoriaComida.fromJson(res);
      categorias.add(nueva);
      return nueva;
    }
    throw Exception('Error al crear categoría');
  }

  Future<CategoriaComida> actualizarCategoria(String id, String nombre) async {
    final body = {'categoria': nombre.trim()};
    final res = await _api.put('/api/categorias/$id', body: body);
    if (res is Map<String, dynamic>) {
      final actualizada = CategoriaComida.fromJson(res);
      final idx = categorias.indexWhere((c) => c.id == id);
      if (idx != -1) {
        categorias[idx] = actualizada;
      }
      return actualizada;
    }
    throw Exception('Error al actualizar categoría');
  }

  Future<void> eliminarCategoria(String id) async {
    await _api.delete('/api/categorias/$id');
    categorias.removeWhere((c) => c.id == id);
  }

  // ==========================================
  // SUBCATEGORIAS
  // ==========================================

  Future<List<Subcategoria>> cargarSubcategorias() async {
    try {
      final res = await _api.get('/api/subcategorias');
      if (res is List) {
        final lista = res
            .map((item) => Subcategoria.fromJson(item as Map<String, dynamic>))
            .toList();
        subcategorias
          ..clear()
          ..addAll(lista);
        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener subcategorías: $e');
    }
    return subcategorias;
  }

  Future<Subcategoria> crearSubcategoria(
    String categoriaId,
    String nombre,
  ) async {
    final body = {
      'id': UuidHelper.v7(),
      'subcategoria': nombre.trim(),
      'categoria_comida_id': categoriaId,
    };
    final res = await _api.post('/api/subcategorias', body: body);
    if (res is Map<String, dynamic>) {
      final nueva = Subcategoria.fromJson(res);
      subcategorias.add(nueva);
      return nueva;
    }
    throw Exception('Error al crear subcategoría');
  }

  Future<Subcategoria> actualizarSubcategoria(
    Subcategoria s, {
    String? nombre,
    bool? estado,
  }) async {
    final body = {
      if (nombre != null) 'subcategoria': nombre.trim(),
      'estado': ?estado,
    };
    final res = await _api.put('/api/subcategorias/${s.id}', body: body);
    if (res is Map<String, dynamic>) {
      final actualizada = Subcategoria.fromJson(res);
      final idx = subcategorias.indexWhere((x) => x.id == s.id);
      if (idx != -1) subcategorias[idx] = actualizada;
      return actualizada;
    }
    throw Exception('Error al actualizar subcategoría');
  }

  Future<void> eliminarSubcategoria(String id) async {
    await _api.delete('/api/subcategorias/$id');
    subcategorias.removeWhere((s) => s.id == id);
  }

  // ==========================================
  // CARTA (PLATOS Y BEBIDAS)
  // ==========================================

  bool _recargandoCarta = false;
  bool _recargaCartaPendiente = false;

  // Vuelve a leer del servidor las categorías, subcategorías, platos, tamaños,
  // presentaciones y tapers.
  // Si llega un evento SSE mientras hay una recarga en curso, se encola una pasada adicional
  // al terminar para que ningún cambio en tiempo real se pierda.
  Future<void> recargarCarta() async {
    if (_recargandoCarta) {
      _recargaCartaPendiente = true;
      return;
    }
    _recargandoCarta = true;
    try {
      do {
        _recargaCartaPendiente = false;
        await Future.wait([
          cargarCategorias(),
          cargarSubcategorias(),
          cargarUnidadesBebida(),
          cargarCarta(),
          cargarVariantes(),
          cargarPresentaciones(),
          cargarTapers(),
          DisponibilidadService.instance.cargarHoy(),
        ]);
      } while (_recargaCartaPendiente);
    } finally {
      _recargandoCarta = false;
    }
  }

  Future<List<CartaItem>> cargarCarta({
    String? categoriaId,
    String? estado,
  }) async {
    try {
      final params = <String, String>{'con_disponibilidad': 'true'};
      if (estado != null && estado.isNotEmpty) {
        params['estado'] = estado;
      }

      final queryStr = params.isNotEmpty
          ? '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final res = await _api.get('/api/carta$queryStr');
      if (res is List) {
        final List<CartaItem> lista = res
            .map((item) => CartaItem.fromJson(item as Map<String, dynamic>))
            .toList();

        // El servidor devuelve los tamaños y presentaciones de cada plato dentro del plato.
        for (final raw in res.whereType<Map<String, dynamic>>()) {
          final id = raw['id']?.toString();
          if (id == null) continue;
          final tamanos = raw['variantes'];
          if (tamanos is List) {
            reemplazarVariantesDeCarta(id, [
              for (final v in tamanos.whereType<Map<String, dynamic>>())
                CartaVariante.fromJson({'carta_id': id, ...v}),
            ]);
          }
          final presList = raw['presentaciones'];
          if (presList is List) {
            reemplazarPresentacionesDeCarta(id, [
              for (final p in presList.whereType<Map<String, dynamic>>())
                CartaPresentacion.fromJson(
                  {'carta_id': id, ...p},
                  catalogoUnidades: unidadesBebida,
                ),
            ]);
          }
        }

        cartasNotifier.value = lista.where((c) => !c.eliminado).toList();
        cartasEliminadas
          ..clear()
          ..addAll(lista.where((c) => c.eliminado));
        return cartasNotifier.value;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener carta: $e');
    }
    return cartasNotifier.value;
  }

  // Un tamaño como lo recibe `POST/PUT /api/carta`: con `id` actualiza el que
  // ya existe y sin `id` crea uno nuevo.
  Map<String, dynamic> _varianteParaEnvio(CartaVariante v) => {
    if (v.id.isNotEmpty && UuidHelper.isValid(v.id)) 'id': v.id,
    'nombre': v.nombre.trim(),
    'precio_cliente': v.precioCliente,
    'precio_personal': v.precioPersonal,
    'peso_min_kg': ?v.pesoMinKg,
    'peso_max_kg': ?v.pesoMaxKg,
    'estado': v.estado,
  };

  Map<String, dynamic> _presentacionParaEnvio(CartaPresentacion p) => {
    if (p.id.isNotEmpty && UuidHelper.isValid(p.id)) 'id': p.id,
    'unidad_bebida_id': p.unidad.id,
    if (p.volumenMl > 0) 'volumen_ml': p.volumenMl,
    'precio_cliente': p.precioCliente,
    if (p.precioPersonal != null) 'precio_personal': p.precioPersonal,
    'estado': p.estado,
  };

  // Deja en la lista de tamaños los que devuelve el servidor para el plato. Si
  // la respuesta no los trae, se vuelven a leer.
  Future<void> _actualizarVariantesTras(
    String cartaId,
    Map<String, dynamic> res,
  ) async {
    final lista = res['variantes'];
    if (lista is List) {
      reemplazarVariantesDeCarta(cartaId, [
        for (final v in lista.whereType<Map<String, dynamic>>())
          CartaVariante.fromJson({'carta_id': cartaId, ...v}),
      ]);
    } else {
      await cargarVariantes();
    }
  }

  Future<void> _actualizarPresentacionesTras(
    String cartaId,
    Map<String, dynamic> res,
  ) async {
    final lista = res['presentaciones'];
    if (lista is List) {
      reemplazarPresentacionesDeCarta(cartaId, [
        for (final p in lista.whereType<Map<String, dynamic>>())
          CartaPresentacion.fromJson(
            {'carta_id': cartaId, ...p},
            catalogoUnidades: unidadesBebida,
          ),
      ]);
    } else {
      await cargarPresentaciones();
    }
  }

  // [variantes] / [presentaciones]: tamaños o presentaciones del plato, guardados
  // en la misma operación que el plato. Cuando existen opciones activas, el precio
  // en la tabla `carta` se envía como null.
  Future<CartaItem> crearPlato(
    CartaItem item, {
    List<CartaVariante>? variantes,
    List<CartaPresentacion>? presentacionesPlato,
  }) async {
    final clientUuid = (item.id.isNotEmpty && UuidHelper.isValid(item.id))
        ? item.id
        : UuidHelper.v7();

    final tieneOpciones =
        (variantes != null && variantes.any((v) => v.estado)) ||
        (presentacionesPlato != null && presentacionesPlato.any((p) => p.estado));

    final body = {
      if (variantes != null && variantes.isNotEmpty)
        'variantes': [for (final v in variantes) _varianteParaEnvio(v)],
      if (presentacionesPlato != null && presentacionesPlato.isNotEmpty)
        'presentaciones': [
          for (final p in presentacionesPlato) _presentacionParaEnvio(p),
        ],
      'id': clientUuid,
      'nombre_plato': item.nombrePlato,
      'descripcion': item.descripcion,
      if (item.subcategoriaId != null) 'subcategoria_id': item.subcategoriaId,
      if (item.taperId != null && item.taperId!.isNotEmpty)
        'taper_id': item.taperId,
      'estado': item.estado,
      if (!tieneOpciones && item.precioCliente != null)
        'precio_cliente': item.precioCliente,
      if (!tieneOpciones && item.precioPersonal != null)
        'precio_personal': item.precioPersonal,
      if (item.sedeId != null) 'sede_id': item.sedeId,
      if (item.urlImagen != null) 'url_imagen': item.urlImagen,
    };

    final res = await _api.post('/api/carta', body: body);
    if (res is Map<String, dynamic>) {
      // La respuesta del POST no trae la categoría (solo las columnas de
      // `carta`): se conserva la que eligió el usuario en el formulario.
      final nuevo = CartaItem.fromJson(res).copyWith(
        categoriaId: item.categoriaId,
        categoriaNombre: item.categoriaNombre,
        subcategoriaIds: item.subcategoriaIds,
        costo: item.costo,
        sku: item.sku,
        stock: item.stock,
      );

      cartasNotifier.value = [...cartasNotifier.value, nuevo];
      if (variantes != null && variantes.isNotEmpty) {
        await _actualizarVariantesTras(nuevo.id, res);
      }
      if (presentacionesPlato != null && presentacionesPlato.isNotEmpty) {
        await _actualizarPresentacionesTras(nuevo.id, res);
      }
      return nuevo;
    }
    throw Exception('Error al crear plato');
  }

  Future<CartaItem> actualizarPlato(
    CartaItem item, {
    List<CartaVariante>? variantes,
    List<CartaPresentacion>? presentacionesPlato,
    bool limpiarImagen = false,
  }) async {
    final tieneOpciones =
        (variantes != null && variantes.any((v) => v.estado)) ||
        (presentacionesPlato != null && presentacionesPlato.any((p) => p.estado));

    final body = {
      if (variantes != null && variantes.isNotEmpty)
        'variantes': [for (final v in variantes) _varianteParaEnvio(v)],
      if (presentacionesPlato != null && presentacionesPlato.isNotEmpty)
        'presentaciones': [
          for (final p in presentacionesPlato) _presentacionParaEnvio(p),
        ],
      'nombre_plato': item.nombrePlato,
      'descripcion': item.descripcion,
      if (item.subcategoriaId != null) 'subcategoria_id': item.subcategoriaId,
      'taper_id': (item.taperId != null && item.taperId!.isNotEmpty)
          ? item.taperId
          : '00000000-0000-0000-0000-000000000000',
      'estado': item.estado,
      if (tieneOpciones || item.precioCliente == null)
        'limpiar_precio_cliente': true,
      if (!tieneOpciones && item.precioCliente != null)
        'precio_cliente': item.precioCliente,
      if (!tieneOpciones && item.precioPersonal != null)
        'precio_personal': item.precioPersonal,
      if (item.sedeId != null) 'sede_id': item.sedeId,
      if (limpiarImagen)
        'url_imagen': ''
      else if (item.urlImagen != null)
        'url_imagen': item.urlImagen,
    };

    final res = await _api.put('/api/carta/${item.id}', body: body);
    if (res is Map<String, dynamic>) {
      // Igual que al crear: el PUT tampoco devuelve la categoría.
      final actualizado = CartaItem.fromJson(res).copyWith(
        categoriaId: item.categoriaId,
        categoriaNombre: item.categoriaNombre,
        subcategoriaIds: item.subcategoriaIds,
        costo: item.costo,
        sku: item.sku,
        stock: item.stock,
        agregados: item.agregados,
        urlImagen: limpiarImagen ? null : (res['url_imagen']?.toString() ?? item.urlImagen),
      );

      cartasNotifier.value = cartasNotifier.value
          .map((c) => c.id == item.id ? actualizado : c)
          .toList();
      if (variantes != null && variantes.isNotEmpty) {
        await _actualizarVariantesTras(item.id, res);
      }
      if (presentacionesPlato != null && presentacionesPlato.isNotEmpty) {
        await _actualizarPresentacionesTras(item.id, res);
      }

      return actualizado;
    }
    throw Exception('Error al actualizar plato');
  }

  // Sube la foto de un plato y la guarda en `carta.url_imagen`, todo en una sola
  // petición (`POST /api/v1/carta/:id/foto`): el servidor la reduce (máx.
  // 800 px), la guarda y actualiza el plato. Antes eran dos pasos (subir y luego
  // `PUT`) y, si el segundo fallaba, la foto quedaba subida pero sin asociar.
  //
  // [advertencia] viene del servidor cuando la foto no pudo guardarse en la nube
  // y quedó solo en su disco.
  Future<({CartaItem plato, String? advertencia})> subirImagenPlato(
    CartaItem item,
    List<int> bytes,
    String nombreArchivo,
  ) async {
    final res = await _api.subirArchivo(
      '/api/v1/carta/${item.id}/foto',
      bytes: bytes,
      nombreArchivo: nombreArchivo,
    );
    final datos = res is Map ? res : const {};
    final url = datos['url']?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('El servidor no devolvió la dirección de la foto');
    }
    // Si el servidor no pudo asociar la foto al plato, no se da por guardada.
    if (datos['plato_actualizado'] != true) {
      throw Exception(
        'La foto se subió, pero el servidor no la asoció al plato. '
        'Inténtalo de nuevo.',
      );
    }
    final actualizado = item.copyWith(urlImagen: url);
    cartasNotifier.value = cartasNotifier.value
        .map((c) => c.id == item.id ? actualizado : c)
        .toList();
    final aviso = datos['warning']?.toString();
    return (
      plato: actualizado,
      advertencia: (aviso == null || aviso.isEmpty) ? null : aviso,
    );
  }

  Future<void> alternarEstadoPlato(CartaItem item) async {
    final nuevoEstado = item.disponible ? estadoInhabilitado : estadoDisponible;
    final actualizado = item.copyWith(estado: nuevoEstado);
    await actualizarPlato(actualizado);
  }

  // Eliminación lógica: el plato pasa al estado `eliminado` y deja de mostrarse,
  // pero la fila se conserva (pedidos y promociones siguen apuntando a ella).
  // TODO(backend): hoy es una convención del frontend (PUT del estado). Cuando
  // `DELETE /api/carta/:id` haga el borrado lógico, volver a llamar a ese endpoint y pedir `?incluir_eliminados=true`
  // en `cargarCarta`.
  Future<void> eliminarPlato(String id) async {
    final item = cartasNotifier.value.where((c) => c.id == id).firstOrNull;
    if (item == null) return;
    final eliminado = (await actualizarPlato(
      item.copyWith(estado: estadoEliminado),
    )).copyWith(estado: estadoEliminado);
    cartasNotifier.value = cartasNotifier.value
        .where((c) => c.id != id)
        .toList();
    cartasEliminadas.add(eliminado);
  }

  // ==========================================
  // TAMAÑOS (carta_variante)
  // ==========================================

  Future<List<CartaVariante>> cargarVariantes() async {
    try {
      final res = await _api.get('/api/carta-variantes');
      if (res is List) {
        final lista = res
            .map((item) => CartaVariante.fromJson(item as Map<String, dynamic>))
            .toList();
        variantes
          ..clear()
          ..addAll(lista);
        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener tamaños: $e');
    }
    return variantes;
  }

  // Los tamaños se registran en Inventario > Tamaños, cada uno por su cuenta.
  Future<CartaVariante> crearVariante(CartaVariante v) async {
    final res = await _api.post('/api/carta-variantes', body: v.toJson());
    final creada = res is Map<String, dynamic>
        ? CartaVariante.fromJson(res)
        : v;
    variantes.removeWhere((x) => x.id == creada.id);
    variantes.add(creada);
    if (creada.estado) {
      cartasNotifier.value = cartasNotifier.value
          .map(
            (c) => c.id == creada.cartaId ? c.copyWith(limpiarPrecio: true) : c,
          )
          .toList();
    }
    return creada;
  }

  Future<CartaVariante> actualizarVariante(CartaVariante v) async {
    final res = await _api.put(
      '/api/carta-variantes/${v.id}',
      body: {
        'nombre': v.nombre,
        'precio_cliente': v.precioCliente,
        'precio_personal': v.precioPersonal,
        'peso_min_kg': v.pesoMinKg,
        'peso_max_kg': v.pesoMaxKg,
        'estado': v.estado,
      },
    );
    final actualizada = res is Map<String, dynamic>
        ? CartaVariante.fromJson(res)
        : v;
    final i = variantes.indexWhere((x) => x.id == v.id);
    if (i != -1) variantes[i] = actualizada;
    return actualizada;
  }

  Future<void> eliminarVariante(String id) async {
    await _api.delete('/api/carta-variantes/$id');
    variantes.removeWhere((v) => v.id == id);
  }

  // ==========================================
  // UNIDADES DE BEBIDA Y PRESENTACIONES (carta_presentacion)
  // ==========================================

  Future<List<UnidadBebida>> cargarUnidadesBebida() async {
    try {
      final res = await _api.get('/api/unidades-bebida');
      if (res is List) {
        final lista = res
            .whereType<Map<String, dynamic>>()
            .map(UnidadBebida.fromJson)
            .toList();
        unidadesBebida
          ..clear()
          ..addAll(lista);
        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener unidades de bebida: $e');
    }
    return unidadesBebida;
  }

  Future<UnidadBebida> crearUnidadBebida(String nombre) async {
    final sedeId = AuthService.instance.currentUser?.sedeId;
    final res = await _api.post(
      '/api/unidades-bebida',
      body: {
        'id': UuidHelper.v7(),
        'unidad_presentacion': nombre.trim(),
        'estado': true,
        if (sedeId != null && sedeId.isNotEmpty) 'sede_id': sedeId,
      },
    );
    final creada = UnidadBebida.fromJson(res as Map<String, dynamic>);
    unidadesBebida.removeWhere((u) => u.id == creada.id);
    unidadesBebida.add(creada);
    return creada;
  }

  Future<List<CartaPresentacion>> cargarPresentaciones() async {
    try {
      final res = await _api.get('/api/carta-presentaciones');
      if (res is List) {
        final lista = res
            .whereType<Map<String, dynamic>>()
            .map(
              (j) => CartaPresentacion.fromJson(
                j,
                catalogoUnidades: unidadesBebida,
              ),
            )
            .toList();
        presentaciones
          ..clear()
          ..addAll(lista);
        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener presentaciones: $e');
    }
    return presentaciones;
  }

  Future<CartaPresentacion> crearPresentacion(CartaPresentacion p) async {
    final body = {
      if (p.id.isNotEmpty && UuidHelper.isValid(p.id)) 'id': p.id else 'id': UuidHelper.v7(),
      'carta_id': p.cartaId,
      'unidad_bebida_id': p.unidad.id,
      if (p.volumenMl > 0) 'volumen_ml': p.volumenMl,
      'precio_cliente': p.precioCliente,
      if (p.precioPersonal != null) 'precio_personal': p.precioPersonal,
      'estado': p.estado,
    };
    final res = await _api.post('/api/carta-presentaciones', body: body);
    final creada = res is Map<String, dynamic>
        ? CartaPresentacion.fromJson(res, catalogoUnidades: unidadesBebida)
        : p;
    presentaciones.removeWhere((x) => x.id == creada.id);
    presentaciones.add(creada);
    if (creada.estado) {
      cartasNotifier.value = cartasNotifier.value
          .map(
            (c) => c.id == creada.cartaId ? c.copyWith(limpiarPrecio: true) : c,
          )
          .toList();
    }
    return creada;
  }

  Future<CartaPresentacion> actualizarPresentacion(CartaPresentacion p) async {
    final res = await _api.put(
      '/api/carta-presentaciones/${p.id}',
      body: {
        'unidad_bebida_id': p.unidad.id,
        if (p.volumenMl > 0) 'volumen_ml': p.volumenMl,
        'precio_cliente': p.precioCliente,
        if (p.precioPersonal != null) 'precio_personal': p.precioPersonal,
        'estado': p.estado,
      },
    );
    final actualizada = res is Map<String, dynamic>
        ? CartaPresentacion.fromJson(res, catalogoUnidades: unidadesBebida)
        : p;
    final i = presentaciones.indexWhere((x) => x.id == p.id);
    if (i != -1) presentaciones[i] = actualizada;
    return actualizada;
  }

  Future<void> eliminarPresentacion(String id) async {
    await _api.delete('/api/carta-presentaciones/$id');
    presentaciones.removeWhere((p) => p.id == id);
  }

  // ==========================================
  // COMPRAS
  // ==========================================

  // `tipo_movimiento` "ingreso_compra" (semilla fija de la migración 00010).
  static const _tipoIngresoCompra = '55551111-1111-1111-1111-111111111101';

  Future<void> cargarCompras() async {
    try {
      final res = await _api.get('/api/compras');
      if (res is List) {
        final borradores = compras.where((c) => !c.guardada).toList();
        compras.clear();
        detallesPorCompra.removeWhere(
          (id, _) => !borradores.any((b) => b.id == id),
        );
        for (final item in res) {
          final json = item as Map<String, dynamic>;
          final detalles = [
            for (final d in (json['detalles'] as List? ?? const []))
              CompraDetalle.fromJson(d as Map<String, dynamic>),
          ];
          reemplazarCompra(Compra.fromJson(json), detalles);
        }
        compras.insertAll(0, borradores);
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener compras: $e');
    }
  }

  // Envía la compra con todos sus detalles (el backend calcula cantidad base,
  // totales y costo unitario base) y registra la entrada de stock de cada uno.
  Future<void> guardarCompra(String compraId) async {
    final compra = compras.firstWhere((c) => c.id == compraId);
    final detalles = detallesPorCompra[compraId] ?? const [];
    if (detalles.isEmpty) {
      throw Exception('Agrega al menos un producto a la compra');
    }

    final res = await _api.post(
      '/api/compras',
      body: {
        ...compra.toJson(),
        // El backend exige `usuario_id` al leer el cuerpo (luego lo reemplaza
        // con el de la sesión).
        'usuario_id': ?AuthService.instance.currentUser?.id,
        'detalles': [for (final d in detalles) d.toJson()],
      },
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('Error al guardar la compra');
    }
    final guardados = [
      for (final d in (res['detalles'] as List? ?? const []))
        CompraDetalle.fromJson(d as Map<String, dynamic>),
    ];
    reemplazarCompra(Compra.fromJson(res), guardados);

    // El backend no repone el stock al guardar la compra: se registra la
    // entrada en el libro de inventario (su trigger suma al stock).
    for (final d in guardados) {
      try {
        await _api.post(
          '/api/inventario-movimientos',
          body: {
            'producto_inventario_id': d.productoInventarioId,
            'tipo_movimiento_id': _tipoIngresoCompra,
            'cantidad': d.cantidadBase,
            'costo_unitario': d.costoUnitarioBase,
            'costo_total': d.precioTotal,
            'compra_detalle_id': d.id,
          },
        );
        registrarMovimientoInventario(
          InventarioMovimiento(
            productoInventarioId: d.productoInventarioId,
            tipoMovimiento: movEntradaCompra,
            cantidad: d.cantidadBase,
            notas: 'Compra del ${_fechaCorta(compra.fechaCompra)}',
            fecha: compra.fechaCompra,
          ),
        );
      } catch (e) {
        throw Exception(
          'La compra se guardó, pero no se pudo actualizar el stock: $e',
        );
      }
    }
  }

  String _fechaCorta(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ==========================================
  // TAPERS
  // ==========================================

  Future<List<Taper>> cargarTapers() async {
    try {
      final res = await _api.get('/api/tapers');
      if (res is List) {
        final List<Taper> lista = res
            .map((item) => Taper.fromJson(item as Map<String, dynamic>))
            .toList();

        tapers
          ..clear()
          ..addAll(lista);

        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener tápers: $e');
    }
    return tapers;
  }

  Future<Taper> crearTaper({
    required String nombre,
    required double precio,
    String? sedeId,
    double? stockInicial,
    double? stockMinimo,
  }) async {
    final clientUuid = UuidHelper.v7();
    final body = {
      'id': clientUuid,
      'nombre': nombre.trim(),
      'precio': precio,
      'estado': true,
      'stock': ?stockInicial,
      'stock_minimo': ?stockMinimo,
      if (sedeId != null && sedeId.isNotEmpty) 'sede_id': sedeId,
    };

    final res = await _api.post('/api/tapers', body: body);
    if (res is Map<String, dynamic>) {
      final nuevo = Taper.fromJson(res);
      tapers.add(nuevo);
      return nuevo;
    }
    throw Exception('Error al crear táper');
  }

  Future<Taper> actualizarTaper(
    String id, {
    String? nombre,
    double? precio,
    bool? estado,
    String? sedeId,
    double? stock,
    double? stockMinimo,
  }) async {
    final body = <String, dynamic>{};
    if (nombre != null) body['nombre'] = nombre.trim();
    if (precio != null) body['precio'] = precio;
    if (estado != null) body['estado'] = estado;
    if (stock != null) body['stock'] = stock;
    if (stockMinimo != null) body['stock_minimo'] = stockMinimo;
    if (sedeId != null && sedeId.isNotEmpty) body['sede_id'] = sedeId;

    final res = await _api.put('/api/tapers/$id', body: body);
    if (res is Map<String, dynamic>) {
      final actualizado = Taper.fromJson(res);
      final idx = tapers.indexWhere((t) => t.id == id);
      if (idx != -1) {
        tapers[idx] = actualizado;
      }
      return actualizado;
    }
    throw Exception('Error al actualizar táper');
  }

  Future<void> alternarEstadoTaper(Taper taper) async {
    await actualizarTaper(taper.id, estado: !taper.estado);
  }

  Future<void> eliminarTaper(String id) async {
    await _api.delete('/api/tapers/$id');
    tapers.removeWhere((t) => t.id == id);
  }

  // ==========================================
  // ROLES Y PERMISOS (RBAC)
  // ==========================================

  Future<List<PermisoModel>> cargarPermisos() async {
    try {
      final res = await _api.get('/api/permisos');
      if (res is List) {
        return res
            .map((item) => PermisoModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener permisos: $e');
    }
    return [];
  }

  Future<List<RolModel>> cargarRoles() async {
    try {
      final res = await _api.get('/api/roles');
      if (res is List) {
        return res
            .map((item) => RolModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener roles: $e');
    }
    return [];
  }

  Future<void> asignarPermisoRol(String rolId, String permisoId) async {
    await _api.post(
      '/api/roles/$rolId/permisos',
      body: {'permiso_id': permisoId},
    );
  }

  Future<void> removerPermisoRol(String rolId, String permisoId) async {
    await _api.delete('/api/roles/$rolId/permisos/$permisoId');
  }

  // Da de alta un usuario con su perfil (`POST /api/usuarios`). El rol se envía
  // por su id: si el backend no encuentra un rol por nombre, asigna otro.
  Future<UserRBACModel> crearUsuario({
    required String usuario,
    required String email,
    required String password,
    required String rolId,
    String? nombre,
    String? apellidos,
    String? identificacion,
    double? sueldo,
    String? pin,
  }) async {
    final res = await _api.post(
      '/api/usuarios',
      body: {
        'usuario': usuario,
        'email': email,
        'password': password,
        'rol_id': rolId,
        if (nombre != null && nombre.isNotEmpty) 'nombre': nombre,
        if (apellidos != null && apellidos.isNotEmpty) 'apellidos': apellidos,
        if (identificacion != null && identificacion.isNotEmpty)
          'identificacion': identificacion,
        'sueldo': ?sueldo,
        if (pin != null && pin.isNotEmpty) 'pin': pin,
      },
    );
    if (res is Map<String, dynamic>) return UserRBACModel.fromJson(res);
    throw Exception('El servidor no devolvió el usuario creado');
  }

  Future<List<UserRBACModel>> cargarUsuariosRBAC() async {
    try {
      final res = await _api.get('/api/usuarios');
      if (res is List) {
        return res
            .map((item) => UserRBACModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener usuarios RBAC: $e');
    }
    return [];
  }

  Future<void> asignarRolUsuario(String userId, String rolId) async {
    await _api.post('/api/usuarios/$userId/roles', body: {'rol_id': rolId});
  }

  Future<void> removerRolUsuario(String userId, String rolId) async {
    await _api.delete('/api/usuarios/$userId/roles/$rolId');
  }

  Future<void> asignarPermisoUsuario(String userId, String permisoId) async {
    await _api.post(
      '/api/usuarios/$userId/permisos',
      body: {'permiso_id': permisoId},
    );
  }

  Future<void> removerPermisoUsuario(String userId, String permisoId) async {
    await _api.delete('/api/usuarios/$userId/permisos/$permisoId');
  }

  Future<void> actualizarEstadoUsuario(String userId, bool estado) async {
    await _api.put('/api/usuarios/$userId/estado', body: {'estado': estado});
  }

  Future<void> actualizarRolUsuario(String userId, String rolId) async {
    await _api.put('/api/usuarios/$userId/rol', body: {'rol_id': rolId});
  }

  // ==========================================
  // INVENTARIO: TIPOS DE PRODUCTO
  // ==========================================

  Future<List<TipoProducto>> cargarTiposProducto({String? sedeId}) async {
    try {
      final query = (sedeId != null && sedeId.isNotEmpty)
          ? '?sede_id=$sedeId'
          : '';
      final res = await _api.get('/api/tipos-producto$query');
      if (res is List) {
        final lista = res
            .map((j) => TipoProducto.fromJson(j as Map<String, dynamic>))
            .toList();
        tiposProducto
          ..clear()
          ..addAll(lista);
        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener tipos de producto: $e');
    }
    return tiposProducto;
  }

  Future<TipoProducto> crearTipoProducto({
    required String tipoProducto,
    bool estado = true,
    String? sedeId,
  }) async {
    final clientUuid = UuidHelper.v7();
    final body = {
      'id': clientUuid,
      'tipo_producto': tipoProducto.trim(),
      'estado': estado,
      if (sedeId != null && sedeId.isNotEmpty) 'sede_id': sedeId,
    };
    final res = await _api.post('/api/tipos-producto', body: body);
    if (res is Map<String, dynamic>) {
      final nuevo = TipoProducto.fromJson(res);
      tiposProducto.add(nuevo);
      return nuevo;
    }
    throw Exception('Error al crear tipo de producto');
  }

  Future<TipoProducto> actualizarTipoProducto(
    String id, {
    required String tipoProducto,
    bool? estado,
    String? sedeId,
  }) async {
    final body = {
      'tipo_producto': tipoProducto.trim(),
      if (estado != null) ...{'estado': estado},
      if (sedeId != null) ...{'sede_id': sedeId},
    };
    final res = await _api.put('/api/tipos-producto/$id', body: body);
    if (res is Map<String, dynamic>) {
      final act = TipoProducto.fromJson(res);
      final idx = tiposProducto.indexWhere((t) => t.id == id);
      if (idx != -1) tiposProducto[idx] = act;
      return act;
    }
    throw Exception('Error al actualizar tipo de producto');
  }

  Future<void> eliminarTipoProducto(String id) async {
    await _api.delete('/api/tipos-producto/$id');
    tiposProducto.removeWhere((t) => t.id == id);
  }

  // ==========================================
  // INVENTARIO: UNIDADES DE PRODUCTO
  // ==========================================

  Future<List<UnidadProducto>> cargarUnidadesProducto({String? sedeId}) async {
    try {
      final query = (sedeId != null && sedeId.isNotEmpty)
          ? '?sede_id=$sedeId'
          : '';
      final res = await _api.get('/api/unidades-producto$query');
      if (res is List) {
        final lista = res
            .map((j) => UnidadProducto.fromJson(j as Map<String, dynamic>))
            .toList();
        unidadesProducto
          ..clear()
          ..addAll(lista);
        return lista;
      }
    } catch (e) {
      developer.log(
        '[CatalogService] Error al obtener unidades de producto: $e',
      );
    }
    return unidadesProducto;
  }

  Future<UnidadProducto> crearUnidadProducto({
    required String unidad,
    bool estado = true,
    String? sedeId,
  }) async {
    final clientUuid = UuidHelper.v7();
    final body = {
      'id': clientUuid,
      'unidad': unidad.trim(),
      'estado': estado,
      if (sedeId != null && sedeId.isNotEmpty) 'sede_id': sedeId,
    };
    final res = await _api.post('/api/unidades-producto', body: body);
    if (res is Map<String, dynamic>) {
      final nuevo = UnidadProducto.fromJson(res);
      unidadesProducto.add(nuevo);
      return nuevo;
    }
    throw Exception('Error al crear unidad de producto');
  }

  Future<UnidadProducto> actualizarUnidadProducto(
    String id, {
    required String unidad,
    bool estado = true,
    String? sedeId,
  }) async {
    final body = {
      'unidad': unidad.trim(),
      'estado': estado,
      if (sedeId != null && sedeId.isNotEmpty) 'sede_id': sedeId,
    };
    final res = await _api.put('/api/unidades-producto/$id', body: body);
    if (res is Map<String, dynamic>) {
      final act = UnidadProducto.fromJson(res);
      final idx = unidadesProducto.indexWhere((u) => u.id == id);
      if (idx != -1) unidadesProducto[idx] = act;
      return act;
    }
    throw Exception('Error al actualizar unidad de producto');
  }

  Future<void> eliminarUnidadProducto(String id) async {
    await _api.delete('/api/unidades-producto/$id');
    unidadesProducto.removeWhere((u) => u.id == id);
  }

  // ==========================================
  // INVENTARIO: TIPOS DE MOVIMIENTO Y KARDEX
  // ==========================================

  Future<void> cargarTiposMovimiento() async {
    try {
      final res = await _api.get('/api/tipos-movimiento');
      if (res is List && res.isNotEmpty) {
        tiposMovimiento
          ..clear()
          ..addAll([
            for (final j in res)
              if (j is Map<String, dynamic>) TipoMovimiento.fromJson(j),
          ]);
      }
    } catch (e) {
      developer.log('[CatalogService] Error cargando tipos de movimiento: $e');
    }
  }

  // Movimientos del libro de inventario, del más reciente al más antiguo. Con
  // [productoId] solo los de ese producto.
  Future<List<InventarioMovimiento>> cargarMovimientosInventario({
    String? productoId,
  }) async {
    try {
      final filtro = (productoId != null && productoId.isNotEmpty);
      final res = await _api.get(
        '/api/inventario-movimientos${filtro ? '?producto_inventario_id=$productoId' : ''}',
      );
      if (res is List) {
        final lista = [
          for (final j in res)
            if (j is Map<String, dynamic>) InventarioMovimiento.fromJson(j),
        ];
        if (filtro) {
          movimientosInventario[productoId] = lista;
        } else {
          movimientosInventario.clear();
          for (final m in lista) {
            movimientosInventario
                .putIfAbsent(m.productoInventarioId, () => [])
                .add(m);
          }
        }
        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error cargando movimientos: $e');
    }
    return const [];
  }

  // Registra una entrada, salida o merma en el libro de inventario. El stock lo
  // actualiza el backend; aquí solo se vuelve a leer.
  Future<InventarioMovimiento> registrarAjusteInventario({
    required String productoInventarioId,
    required String tipoMovimientoId,
    required double cantidad,
    double? costoUnitario,
    String? notas,
  }) async {
    final res = await _api.post(
      '/api/inventario-movimientos',
      body: {
        'producto_inventario_id': productoInventarioId,
        'tipo_movimiento_id': tipoMovimientoId,
        'cantidad': cantidad,
        'costo_unitario': ?costoUnitario,
        if (notas != null && notas.isNotEmpty) 'notas': notas,
      },
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('Respuesta inesperada al registrar el movimiento');
    }
    final movimiento = InventarioMovimiento.fromJson(res);
    // El stock real es el de la base de datos.
    await cargarProductosInventario();
    movimientosInventario
        .putIfAbsent(movimiento.productoInventarioId, () => [])
        .insert(0, movimiento);
    return movimiento;
  }

  // ==========================================
  // INVENTARIO: PRODUCTOS DE INVENTARIO
  // ==========================================

  Future<List<ProductoInventario>> cargarProductosInventario({
    String? sedeId,
  }) async {
    try {
      final query = (sedeId != null && sedeId.isNotEmpty)
          ? '?sede_id=$sedeId'
          : '';
      final res = await _api.get('/api/productos-inventario$query');
      if (res is List) {
        final lista = res
            .map((j) => ProductoInventario.fromJson(j as Map<String, dynamic>))
            .toList();
        productosInventario
          ..clear()
          ..addAll(lista);
        return lista;
      }
    } catch (e) {
      developer.log(
        '[CatalogService] Error al obtener productos de inventario: $e',
      );
    }
    return productosInventario;
  }

  Future<ProductoInventario> crearProductoInventario(
    ProductoInventario prod,
  ) async {
    final id = (prod.id.isNotEmpty && UuidHelper.isValid(prod.id))
        ? prod.id
        : UuidHelper.v7();
    final body = {
      'id': id,
      'nombre': prod.nombre.trim(),
      'descripcion': prod.descripcion?.trim(),
      'tipo_producto_id': prod.tipoProductoId,
      'seguimiento': prod.seguimiento,
      'unidad_producto_id': prod.unidadProductoId,
      'stock_actual': prod.stockActual,
      'stock_minimo': prod.stockMinimo,
      'costo_reposicion': prod.costoReposicion,
      'notas': prod.notas?.trim(),
      'estado': prod.estado,
      if (prod.sedeId != null && prod.sedeId!.isNotEmpty)
        'sede_id': prod.sedeId,
    };
    final res = await _api.post('/api/productos-inventario', body: body);
    if (res is Map<String, dynamic>) {
      final nuevo = ProductoInventario.fromJson(res);
      final idx = productosInventario.indexWhere((p) => p.id == nuevo.id);
      if (idx != -1) {
        productosInventario[idx] = nuevo;
      } else {
        productosInventario.add(nuevo);
      }
      return nuevo;
    }
    throw Exception('Error al crear producto de inventario');
  }

  Future<ProductoInventario> actualizarProductoInventario(
    ProductoInventario prod,
  ) async {
    final body = {
      'nombre': prod.nombre.trim(),
      'descripcion': prod.descripcion?.trim(),
      'tipo_producto_id': prod.tipoProductoId,
      'seguimiento': prod.seguimiento,
      'unidad_producto_id': prod.unidadProductoId,
      'stock_actual': prod.stockActual,
      'stock_minimo': prod.stockMinimo,
      'costo_reposicion': prod.costoReposicion,
      'notas': prod.notas?.trim(),
      'estado': prod.estado,
      if (prod.sedeId != null && prod.sedeId!.isNotEmpty)
        'sede_id': prod.sedeId,
    };
    final res = await _api.put(
      '/api/productos-inventario/${prod.id}',
      body: body,
    );
    if (res is Map<String, dynamic>) {
      final act = ProductoInventario.fromJson(res);
      final idx = productosInventario.indexWhere((p) => p.id == act.id);
      if (idx != -1) productosInventario[idx] = act;
      return act;
    }
    throw Exception('Error al actualizar producto');
  }

  Future<void> actualizarCostoReposicion(String id, double costo) async {
    await _api.put(
      '/api/productos-inventario/$id/costo-reposicion',
      body: {'costo_reposicion': costo},
    );
    final idx = productosInventario.indexWhere((p) => p.id == id);
    if (idx != -1) {
      productosInventario[idx] = productosInventario[idx].copyWith(
        costoReposicion: costo,
      );
    }
  }

  Future<void> eliminarProductoInventario(String id) async {
    await _api.delete('/api/productos-inventario/$id');
    productosInventario.removeWhere((p) => p.id == id);
  }

  // ==========================================
  // INVENTARIO: UTENSILIOS ROTOS
  // ==========================================

  Future<List<UtensilioRoto>> cargarUtensiliosRotos({String? sedeId}) async {
    try {
      final query = (sedeId != null && sedeId.isNotEmpty)
          ? '?sede_id=$sedeId'
          : '';
      final res = await _api.get('/api/utensilios-roto$query');
      if (res is List) {
        final lista = res
            .map((j) => UtensilioRoto.fromJson(j as Map<String, dynamic>))
            .toList();
        utensiliosRotos
          ..clear()
          ..addAll(lista);
        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener utensilios rotos: $e');
    }
    return utensiliosRotos;
  }

  Future<UtensilioRoto> crearUtensilioRoto(UtensilioRoto u) async {
    final id = (u.id.isNotEmpty && UuidHelper.isValid(u.id))
        ? u.id
        : UuidHelper.v7();
    final body = {
      'id': id,
      'producto_inventario_id': u.productoInventarioId,
      'empleado_id': u.empleadoId,
      'cantidad': u.cantidad,
      'costo_total': u.costoTotal,
      if (u.usuarioId != null && u.usuarioId!.isNotEmpty)
        'usuario_id': u.usuarioId,
      'notas': u.notas?.trim(),
      'is_pagado': u.isPagado,
      'is_repuesto': u.isRepuesto,
      'done': u.done,
    };
    final res = await _api.post('/api/utensilios-roto', body: body);
    if (res is Map<String, dynamic>) {
      final nuevo = UtensilioRoto.fromJson(res);
      utensiliosRotos.insert(0, nuevo);
      return nuevo;
    }
    throw Exception('Error al registrar rotura de utensilio');
  }

  Future<UtensilioRoto> actualizarUtensilioRoto(UtensilioRoto u) async {
    final body = {
      'is_pagado': u.isPagado,
      'is_repuesto': u.isRepuesto,
      'done': u.done,
      'notas': u.notas?.trim(),
    };
    final res = await _api.put('/api/utensilios-roto/${u.id}', body: body);
    if (res is Map<String, dynamic>) {
      final act = UtensilioRoto.fromJson(res);
      final idx = utensiliosRotos.indexWhere((x) => x.id == act.id);
      if (idx != -1) utensiliosRotos[idx] = act;
      return act;
    }
    throw Exception('Error al actualizar utensilio roto');
  }

  Future<void> eliminarUtensilioRoto(String id) async {
    await _api.delete('/api/utensilios-roto/$id');
    utensiliosRotos.removeWhere((u) => u.id == id);
  }

  // ==========================================
  // INVENTARIO: PAGOS A CUENTA DE EMPLEADO
  // ==========================================

  Future<List<PagoCuentaEmpleado>> cargarPagosCuentaEmpleado({
    String? utensilioRotoId,
  }) async {
    try {
      final query = (utensilioRotoId != null && utensilioRotoId.isNotEmpty)
          ? '?utensilio_roto_id=$utensilioRotoId'
          : '';
      final res = await _api.get('/api/pagos-cuenta-empleado$query');
      if (res is List) {
        return res
            .map((j) => PagoCuentaEmpleado.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      developer.log(
        '[CatalogService] Error al obtener pagos cuenta empleado: $e',
      );
    }
    return [];
  }

  Future<PagoCuentaEmpleado> crearPagoCuentaEmpleado(
    PagoCuentaEmpleado p,
  ) async {
    final id = (p.id.isNotEmpty && UuidHelper.isValid(p.id))
        ? p.id
        : UuidHelper.v7();
    final body = {
      'id': id,
      'empleado_id': p.empleadoId,
      'monto': p.monto,
      'medio_pago_id': p.medioPagoId,
      if (p.pedidosId != null && p.pedidosId!.isNotEmpty)
        'pedidos_id': p.pedidosId,
      'utensilio_roto_id': p.utensilioRotoId,
      if (p.usuarioId.isNotEmpty) 'usuario_id': p.usuarioId,
      'nota': p.nota?.trim(),
    };
    final res = await _api.post('/api/pagos-cuenta-empleado', body: body);
    if (res is Map<String, dynamic>) {
      final nuevo = PagoCuentaEmpleado.fromJson(res);
      await cargarUtensiliosRotos();
      return nuevo;
    }
    throw Exception('Error al registrar pago');
  }
}
