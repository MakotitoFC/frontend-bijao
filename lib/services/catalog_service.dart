import 'dart:developer' as developer;
import '../data/cartas_store.dart';
import '../data/catalogos_store.dart';
import '../data/categorias_store.dart';
import '../data/inventario_store.dart';
import '../data/mesas_store.dart';
import '../data/utensilios_store.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../models/mesa.dart';
import '../models/modificador.dart';
import '../models/pago_cuenta_empleado.dart';
import '../models/producto_inventario.dart';
import '../models/rbac.dart';
import '../models/taper.dart';
import '../models/tipo_producto.dart';
import '../models/tipo_seguimiento.dart';
import '../models/unidad_producto.dart';
import '../models/utensilio_roto.dart';
import '../models/zona.dart';
import '../utils/uuid_helper.dart';
import 'api_client.dart';

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
        cargarCarta(),
        cargarTapers(),
        cargarTiposProducto(),
        cargarTiposSeguimiento(),
        cargarUnidadesProducto(),
        cargarProductosInventario(),
        cargarUtensiliosRotos(),
      ]);
      developer.log('[CatalogService] Catálogos cargados exitosamente');
    } catch (e) {
      developer.log('[CatalogService] Error cargando catálogos: $e');
    }
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
        final activas = zonas.where((z) => z.estado).map((z) => z.zona).toList();
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

  Future<Zona> crearZona({
    required String nombre,
    bool estado = true,
  }) async {
    final clientUuid = UuidHelper.v7();
    final body = {
      'id': clientUuid,
      'zona': nombre.trim(),
      'estado': estado,
    };

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

  Future<Zona> actualizarZona(
    String id, {
    String? nombre,
    bool? estado,
  }) async {
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
        orElse: () => zonas.isNotEmpty ? zonas.first : const Zona(id: '11111111-2222-3333-4444-555555555555', zona: 'Salón Principal'),
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
      final nueva = Mesa.fromJson(res).copyWith(
        capacidad: capacidad,
        zona: zona,
        zonaId: idZona,
      );
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
        orElse: () => zonas.isNotEmpty ? zonas.first : const Zona(id: '11111111-2222-3333-4444-555555555555', zona: 'Salón Principal'),
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
            .map((item) => CategoriaComida.fromJson(item as Map<String, dynamic>))
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
    final body = {
      'id': clientUuid,
      'categoria': nombre.trim(),
    };

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
  // CARTA (PLATOS Y BEBIDAS)
  // ==========================================

  Future<List<CartaItem>> cargarCarta({String? categoriaId, String? estado}) async {
    try {
      final params = <String, String>{};
      if (categoriaId != null && categoriaId.isNotEmpty) {
        params['categoria_id'] = categoriaId;
      }
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

        cartasNotifier.value = lista;
        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener carta: $e');
    }
    return cartasNotifier.value;
  }

  Future<CartaItem> crearPlato(CartaItem item) async {
    final clientUuid = (item.id.isNotEmpty && UuidHelper.isValid(item.id))
        ? item.id
        : UuidHelper.v7();

    final body = {
      'id': clientUuid,
      'nombre_plato': item.nombrePlato,
      'descripcion': item.descripcion,
      'categoria_id': item.categoriaId,
      if (item.taperId != null && item.taperId!.isNotEmpty) 'taper_id': item.taperId,
      'estado': item.estado,
      if (item.precioCliente != null) 'precio_cliente': item.precioCliente,
      if (item.precioPersonal != null) 'precio_personal': item.precioPersonal,
      if (item.sedeId != null) 'sede_id': item.sedeId,
    };

    final res = await _api.post('/api/carta', body: body);
    if (res is Map<String, dynamic>) {
      final nuevo = CartaItem.fromJson(res).copyWith(
        platoDelDia: item.platoDelDia,
        costo: item.costo,
        sku: item.sku,
        stock: item.stock,
      );

      // Crear modificadores asociados si los tuviera
      if (item.agregados.isNotEmpty) {
        for (final extra in item.agregados) {
          final modUuid = UuidHelper.v7();
          await crearModificador(Modificador(
            id: modUuid,
            cartaId: nuevo.id,
            nombre: extra['nombre'] ?? '',
            tipo: extra['tipo'] ?? 'ajuste',
            precioAjuste: (extra['precio'] is num) ? (extra['precio'] as num).toDouble() : 0.0,
          ));
        }
      }

      cartasNotifier.value = [...cartasNotifier.value, nuevo];
      return nuevo;
    }
    throw Exception('Error al crear plato');
  }

  Future<CartaItem> actualizarPlato(CartaItem item) async {
    final body = {
      'nombre_plato': item.nombrePlato,
      'descripcion': item.descripcion,
      'categoria_id': item.categoriaId,
      'taper_id': (item.taperId != null && item.taperId!.isNotEmpty)
          ? item.taperId
          : '00000000-0000-0000-0000-000000000000',
      'estado': item.estado,
      if (item.precioCliente != null) 'precio_cliente': item.precioCliente,
      if (item.precioPersonal != null) 'precio_personal': item.precioPersonal,
      if (item.sedeId != null) 'sede_id': item.sedeId,
    };

    final res = await _api.put('/api/carta/${item.id}', body: body);
    if (res is Map<String, dynamic>) {
      final actualizado = CartaItem.fromJson(res).copyWith(
        platoDelDia: item.platoDelDia,
        costo: item.costo,
        sku: item.sku,
        stock: item.stock,
        agregados: item.agregados,
      );

      cartasNotifier.value = cartasNotifier.value
          .map((c) => c.id == item.id ? actualizado : c)
          .toList();

      return actualizado;
    }
    throw Exception('Error al actualizar plato');
  }

  Future<void> alternarEstadoPlato(CartaItem item) async {
    final nuevoEstado = item.disponible ? 'inactivo' : 'disponible';
    final actualizado = item.copyWith(estado: nuevoEstado);
    await actualizarPlato(actualizado);
  }

  Future<void> eliminarPlato(String id) async {
    await _api.delete('/api/carta/$id');
    cartasNotifier.value = cartasNotifier.value.where((c) => c.id != id).toList();
  }

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
  }) async {
    final clientUuid = UuidHelper.v7();
    final body = {
      'id': clientUuid,
      'nombre': nombre.trim(),
      'precio': precio,
      'estado': true,
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
  }) async {
    final body = <String, dynamic>{};
    if (nombre != null) body['nombre'] = nombre.trim();
    if (precio != null) body['precio'] = precio;
    if (estado != null) body['estado'] = estado;
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
  // MODIFICADORES
  // ==========================================

  Future<List<Modificador>> cargarModificadores({String? cartaId}) async {
    try {
      final query = (cartaId != null && cartaId.isNotEmpty) ? '?carta_id=$cartaId' : '';
      final res = await _api.get('/api/modificadores$query');
      if (res is List) {
        return res
            .map((item) => Modificador.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener modificadores: $e');
    }
    return [];
  }

  Future<Modificador> crearModificador(Modificador mod) async {
    final clientUuid = (mod.id.isNotEmpty && UuidHelper.isValid(mod.id))
        ? mod.id
        : UuidHelper.v7();

    final body = {
      'id': clientUuid,
      'carta_id': mod.cartaId,
      'nombre': mod.nombre,
      'tipo': mod.tipo,
      'precio_ajuste': mod.precioAjuste,
    };

    final res = await _api.post('/api/modificadores', body: body);
    if (res is Map<String, dynamic>) {
      return Modificador.fromJson(res);
    }
    throw Exception('Error al crear modificador');
  }

  Future<void> eliminarModificador(String id) async {
    await _api.delete('/api/modificadores/$id');
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
    await _api.post('/api/roles/$rolId/permisos', body: {'permiso_id': permisoId});
  }

  Future<void> removerPermisoRol(String rolId, String permisoId) async {
    await _api.delete('/api/roles/$rolId/permisos/$permisoId');
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
    await _api.post('/api/usuarios/$userId/permisos', body: {'permiso_id': permisoId});
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
      final query = (sedeId != null && sedeId.isNotEmpty) ? '?sede_id=$sedeId' : '';
      final res = await _api.get('/api/tipos-producto$query');
      if (res is List) {
        final lista = res.map((j) => TipoProducto.fromJson(j as Map<String, dynamic>)).toList();
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
  // INVENTARIO: TIPOS DE SEGUIMIENTO
  // ==========================================

  Future<List<TipoSeguimiento>> cargarTiposSeguimiento({String? sedeId}) async {
    try {
      final query = (sedeId != null && sedeId.isNotEmpty) ? '?sede_id=$sedeId' : '';
      final res = await _api.get('/api/tipos-seguimiento$query');
      if (res is List) {
        final lista = res.map((j) => TipoSeguimiento.fromJson(j as Map<String, dynamic>)).toList();
        tiposSeguimiento
          ..clear()
          ..addAll(lista);
        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener tipos de seguimiento: $e');
    }
    return tiposSeguimiento;
  }

  Future<TipoSeguimiento> crearTipoSeguimiento({
    required String tipoSeguimiento,
    bool estado = true,
    String? sedeId,
  }) async {
    final clientUuid = UuidHelper.v7();
    final body = {
      'id': clientUuid,
      'tipo_seguimiento': tipoSeguimiento.trim(),
      'estado': estado,
      if (sedeId != null && sedeId.isNotEmpty) 'sede_id': sedeId,
    };
    final res = await _api.post('/api/tipos-seguimiento', body: body);
    if (res is Map<String, dynamic>) {
      final nuevo = TipoSeguimiento.fromJson(res);
      tiposSeguimiento.add(nuevo);
      return nuevo;
    }
    throw Exception('Error al crear tipo de seguimiento');
  }

  Future<void> eliminarTipoSeguimiento(String id) async {
    await _api.delete('/api/tipos-seguimiento/$id');
    tiposSeguimiento.removeWhere((t) => t.id == id);
  }

  // ==========================================
  // INVENTARIO: UNIDADES DE PRODUCTO
  // ==========================================

  Future<List<UnidadProducto>> cargarUnidadesProducto({String? sedeId}) async {
    try {
      final query = (sedeId != null && sedeId.isNotEmpty) ? '?sede_id=$sedeId' : '';
      final res = await _api.get('/api/unidades-producto$query');
      if (res is List) {
        final lista = res.map((j) => UnidadProducto.fromJson(j as Map<String, dynamic>)).toList();
        unidadesProducto
          ..clear()
          ..addAll(lista);
        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener unidades de producto: $e');
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

  Future<void> eliminarUnidadProducto(String id) async {
    await _api.delete('/api/unidades-producto/$id');
    unidadesProducto.removeWhere((u) => u.id == id);
  }

  // ==========================================
  // INVENTARIO: PRODUCTOS DE INVENTARIO
  // ==========================================

  Future<List<ProductoInventario>> cargarProductosInventario({String? sedeId}) async {
    try {
      final query = (sedeId != null && sedeId.isNotEmpty) ? '?sede_id=$sedeId' : '';
      final res = await _api.get('/api/productos-inventario$query');
      if (res is List) {
        final lista = res.map((j) => ProductoInventario.fromJson(j as Map<String, dynamic>)).toList();
        productosInventario
          ..clear()
          ..addAll(lista);
        return lista;
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener productos de inventario: $e');
    }
    return productosInventario;
  }

  Future<ProductoInventario> crearProductoInventario(ProductoInventario prod) async {
    final id = (prod.id.isNotEmpty && UuidHelper.isValid(prod.id)) ? prod.id : UuidHelper.v7();
    final body = {
      'id': id,
      'nombre': prod.nombre.trim(),
      'descripcion': prod.descripcion?.trim(),
      'tipo_producto_id': prod.tipoProductoId,
      'tipo_seguimiento_id': prod.tipoSeguimientoId,
      'unidad_producto_id': prod.unidadProductoId,
      'stock_actual': prod.stockActual,
      'stock_minimo': prod.stockMinimo,
      'costo_reposicion': prod.costoReposicion,
      'notas': prod.notas?.trim(),
      'estado': prod.estado,
      if (prod.sedeId != null && prod.sedeId!.isNotEmpty) 'sede_id': prod.sedeId,
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

  Future<ProductoInventario> actualizarProductoInventario(ProductoInventario prod) async {
    final body = {
      'nombre': prod.nombre.trim(),
      'descripcion': prod.descripcion?.trim(),
      'tipo_producto_id': prod.tipoProductoId,
      'tipo_seguimiento_id': prod.tipoSeguimientoId,
      'unidad_producto_id': prod.unidadProductoId,
      'stock_actual': prod.stockActual,
      'stock_minimo': prod.stockMinimo,
      'costo_reposicion': prod.costoReposicion,
      'notas': prod.notas?.trim(),
      'estado': prod.estado,
      if (prod.sedeId != null && prod.sedeId!.isNotEmpty) 'sede_id': prod.sedeId,
    };
    final res = await _api.put('/api/productos-inventario/${prod.id}', body: body);
    if (res is Map<String, dynamic>) {
      final act = ProductoInventario.fromJson(res);
      final idx = productosInventario.indexWhere((p) => p.id == act.id);
      if (idx != -1) productosInventario[idx] = act;
      return act;
    }
    throw Exception('Error al actualizar producto');
  }

  Future<void> actualizarCostoReposicion(String id, double costo) async {
    await _api.put('/api/productos-inventario/$id/costo-reposicion', body: {'costo_reposicion': costo});
    final idx = productosInventario.indexWhere((p) => p.id == id);
    if (idx != -1) {
      productosInventario[idx] = productosInventario[idx].copyWith(costoReposicion: costo);
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
      final query = (sedeId != null && sedeId.isNotEmpty) ? '?sede_id=$sedeId' : '';
      final res = await _api.get('/api/utensilios-roto$query');
      if (res is List) {
        final lista = res.map((j) => UtensilioRoto.fromJson(j as Map<String, dynamic>)).toList();
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
    final id = (u.id.isNotEmpty && UuidHelper.isValid(u.id)) ? u.id : UuidHelper.v7();
    final body = {
      'id': id,
      'producto_inventario_id': u.productoInventarioId,
      'empleado_id': u.empleadoId,
      'cantidad': u.cantidad,
      'costo_total': u.costoTotal,
      if (u.usuarioId != null && u.usuarioId!.isNotEmpty) 'usuario_id': u.usuarioId,
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

  Future<List<PagoCuentaEmpleado>> cargarPagosCuentaEmpleado({String? utensilioRotoId}) async {
    try {
      final query = (utensilioRotoId != null && utensilioRotoId.isNotEmpty)
          ? '?utensilio_roto_id=$utensilioRotoId'
          : '';
      final res = await _api.get('/api/pagos-cuenta-empleado$query');
      if (res is List) {
        return res.map((j) => PagoCuentaEmpleado.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      developer.log('[CatalogService] Error al obtener pagos cuenta empleado: $e');
    }
    return [];
  }

  Future<PagoCuentaEmpleado> crearPagoCuentaEmpleado(PagoCuentaEmpleado p) async {
    final id = (p.id.isNotEmpty && UuidHelper.isValid(p.id)) ? p.id : UuidHelper.v7();
    final body = {
      'id': id,
      'empleado_id': p.empleadoId,
      'monto': p.monto,
      'medio_pago_id': p.medioPagoId,
      if (p.pedidosId != null && p.pedidosId!.isNotEmpty) 'pedidos_id': p.pedidosId,
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
