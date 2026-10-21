import '../data/movimientos_caja_store.dart';
import '../models/medio_pago.dart';
import '../models/movimiento_caja.dart';
import '../utils/uuid_helper.dart';
import 'api_client.dart';

// Ingresos y salidas de caja contra el servidor: `/api/categorias-movimiento` y
// `/api/movimientos`. Con categorías o medios de demostración (ids que no son
// del servidor) el movimiento se queda solo en memoria.
class MovimientoCajaService {
  MovimientoCajaService._();
  static final MovimientoCajaService instance = MovimientoCajaService._();

  // Editar y anular usan `PUT /api/movimientos/:id` y
  // `POST /api/movimientos/:id/anular`, que el backend ya entrega. En false, la
  // pantalla muestra los botones desactivados.
  static bool edicionDisponible = true;

  final ApiClient _api = ApiClient.instance;

  bool _enServidor(String categoriaId, String medioId) =>
      UuidHelper.isValid(categoriaId) && UuidHelper.isValid(medioId);

  Future<void> cargarCategorias() async {
    final res = await _api.get('/api/categorias-movimiento');
    if (res is! List) return;
    categoriasMovimiento
      ..clear()
      ..addAll(
        res.whereType<Map<String, dynamic>>().map(CategoriaMovimiento.fromJson),
      );
  }

  Future<CategoriaMovimiento> crearCategoria({
    required String nombre,
    required TipoMovimiento tipo,
  }) async {
    final res = await _api.post(
      '/api/categorias-movimiento',
      body: {
        'categoria': nombre.trim(),
        'tipo': tipo.codigo,
        'estado': true,
      },
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('El servidor no devolvió la categoría creada');
    }
    final cat = CategoriaMovimiento.fromJson(res);
    categoriasMovimiento.add(cat);
    return cat;
  }

  Future<CategoriaMovimiento> editarCategoria({
    required String id,
    required String nombre,
    required TipoMovimiento tipo,
    required bool activo,
  }) async {
    final res = await _api.put(
      '/api/categorias-movimiento/$id',
      body: {
        'categoria': nombre.trim(),
        'tipo': tipo.codigo,
        'estado': activo,
      },
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('El servidor no devolvió la categoría actualizada');
    }
    final cat = CategoriaMovimiento.fromJson(res);
    final idx = categoriasMovimiento.indexWhere((c) => c.id == id);
    if (idx != -1) {
      categoriasMovimiento[idx] = cat;
    }
    return cat;
  }

  Future<void> eliminarCategoria(String id) async {
    await _api.delete('/api/categorias-movimiento/$id');
    categoriasMovimiento.removeWhere((c) => c.id == id);
  }

  // Trae los movimientos desde [desde] (el inicio de la caja actual). Los que
  // solo existen en memoria se conservan.
  Future<void> cargarDelTurno(DateTime desde) async {
    final res = await _api.get(
      '/api/movimientos',
      queryParams: {
        'fecha_desde': desde.toUtc().toIso8601String(),
        // Los anulados se ven tachados y con su motivo.
        'incluir_anulados': 'true',
      },
    );
    if (res is! List) return;
    final delServidor = [
      for (final j in res.whereType<Map<String, dynamic>>())
        MovimientoCaja.fromJson(
          j,
          notaLocal: notasMovimientoLocales[j['id']?.toString()],
        ),
    ];
    movimientosCaja
      ..removeWhere((m) => UuidHelper.isValid(m.id))
      ..addAll(delServidor);
  }

  // Registra un ingreso o una salida; el tipo lo da la categoría. Si el
  // servidor lo rechaza, lanza el error y no deja nada registrado.
  Future<MovimientoCaja> registrar({
    required CategoriaMovimiento categoria,
    required double monto,
    required MedioPago medio,
    String? nota,
  }) async {
    final texto = (nota ?? '').trim();
    MovimientoCaja nuevo;
    if (_enServidor(categoria.id, medio.id)) {
      final res = await _api.post(
        '/api/movimientos',
        body: {
          'categoria_movimiento_id': categoria.id,
          'precio': monto,
          'medio_pago_id': medio.id,
          if (texto.isNotEmpty) 'nota': texto,
        },
      );
      if (res is! Map<String, dynamic>) {
        throw Exception('El servidor no devolvió el movimiento registrado');
      }
      nuevo = MovimientoCaja.fromJson(res, notaLocal: texto);
      if (texto.isNotEmpty) notasMovimientoLocales[nuevo.id] = texto;
    } else {
      nuevo = MovimientoCaja(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        tipo: categoria.tipo,
        categoriaId: categoria.id,
        categoriaNombre: categoria.nombre,
        monto: monto,
        medioPagoId: medio.id,
        medioPagoNombre: medio.medioPago,
        fecha: DateTime.now(),
        nota: texto.isEmpty ? null : texto,
      );
    }
    movimientosCaja.add(nuevo);
    return nuevo;
  }

  // Corrige un movimiento (categoría, monto, medio de pago o nota).
  Future<MovimientoCaja> editar(
    MovimientoCaja m, {
    required CategoriaMovimiento categoria,
    required double monto,
    required MedioPago medio,
    String? nota,
  }) async {
    final texto = (nota ?? '').trim();
    var editado = m.copyWith(
      tipo: categoria.tipo,
      categoriaId: categoria.id,
      categoriaNombre: categoria.nombre,
      monto: monto,
      medioPagoId: medio.id,
      medioPagoNombre: medio.medioPago,
      nota: texto,
      editado: true,
    );
    if (UuidHelper.isValid(m.id)) {
      final res = await _api.put(
        '/api/movimientos/${m.id}',
        body: {
          'categoria_movimiento_id': categoria.id,
          'precio': monto,
          'medio_pago_id': medio.id,
          'nota': texto,
        },
      );
      if (res is Map<String, dynamic>) {
        editado = MovimientoCaja.fromJson(res, notaLocal: texto);
      }
      if (texto.isNotEmpty) notasMovimientoLocales[m.id] = texto;
    }
    _reemplazar(editado);
    return editado;
  }

  // Anula un movimiento: queda en la lista con su motivo, pero ya no cuenta en
  // los totales. Nunca se borra.
  Future<MovimientoCaja> anular(
    MovimientoCaja m, {
    required String motivo,
  }) async {
    final texto = motivo.trim();
    if (texto.isEmpty) throw Exception('Escribe el motivo de la anulación');
    var anulado = m.copyWith(anulado: true, motivoAnulacion: texto);
    if (UuidHelper.isValid(m.id)) {
      final res = await _api.post(
        '/api/movimientos/${m.id}/anular',
        body: {'motivo': texto},
      );
      if (res is Map<String, dynamic>) {
        final delServidor = MovimientoCaja.fromJson(res);
        anulado = delServidor.anulado
            ? delServidor
            : anulado.copyWith(motivoAnulacion: texto);
      }
    }
    _reemplazar(anulado);
    return anulado;
  }

  void _reemplazar(MovimientoCaja m) {
    final i = movimientosCaja.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      movimientosCaja[i] = m;
    } else {
      movimientosCaja.add(m);
    }
  }
}
