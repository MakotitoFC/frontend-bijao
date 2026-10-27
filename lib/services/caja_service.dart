import '../data/cierres_store.dart';
import '../models/caja_servidor.dart';
import '../models/cierre_caja.dart';
import '../models/turno.dart';
import '../utils/uuid_helper.dart';
import 'api_client.dart';
import 'auth_service.dart';

// Caja contra el servidor: estado y apertura del turno, totales por medio de
// pago, cierre, traspaso y reportes (`/api/v1/caja/...`). El servidor calcula
// los totales (ventas, ingresos y salidas) y el efectivo esperado.
class CajaService {
  CajaService._();
  static final CajaService instance = CajaService._();

  final ApiClient _api = ApiClient.instance;

  // ¿La sesión tiene una sede del servidor? Sin ella (datos de demostración) la
  // caja se lleva solo en la app.
  bool get enServidor =>
      UuidHelper.isValid(AuthService.instance.currentUser?.sedeId ?? '');

  // Lee el estado de la caja (abierta o cerrada) con sus totales y deja todo en
  // memoria. Si el estado no trae los totales, los pide aparte.
  Future<EstadoCaja> cargarEstado() async {
    final res = await _api.get('/api/v1/caja/estado-actual');
    if (res is! Map<String, dynamic>) {
      throw Exception('El servidor no devolvió el estado de la caja');
    }
    var estado = EstadoCaja.fromJson(res);
    if (estado.totales == null) {
      final t = await _api.get('/api/v1/caja/totales-actual');
      if (t is Map<String, dynamic>) {
        estado = EstadoCaja(
          abierta: estado.abierta,
          apertura: estado.apertura,
          totales: TotalesCajaServidor.fromJson(t),
        );
      }
    }
    estadoCajaServidor = estado;
    return estado;
  }

  // Trae los cierres anteriores (del más reciente al más antiguo).
  Future<void> cargarCierres() async {
    final res = await _api.get('/api/v1/caja/cierres');
    if (res is! List) return;
    cierresCaja
      ..clear()
      ..addAll(res.whereType<Map<String, dynamic>>().map(CierreCaja.fromJson));
  }

  // Abre el turno con el efectivo inicial. El servidor rechaza abrir si ya hay
  // una caja abierta.
  Future<void> abrir({
    required double montoInicial,
    String? turnoId,
    String? fechaOperativa,
    String? notas,
  }) async {
    final sedeId = AuthService.instance.currentUser?.sedeId;
    await _api.post(
      '/api/v1/caja/apertura',
      body: {
        'sede_id': sedeId,
        'monto_inicial': montoInicial,
        if ((turnoId ?? '').trim().isNotEmpty) 'turno_id': turnoId!.trim(),
        if ((fechaOperativa ?? '').trim().isNotEmpty)
          'fecha_operativa': fechaOperativa!.trim(),
        if ((notas ?? '').trim().isNotEmpty) 'notas': notas!.trim(),
      },
    );
    await cargarEstado();
  }

  // Realiza el traspaso de la caja actual a otro usuario responsable sin cerrarla.
  Future<void> traspaso({
    required String nuevoUsuarioId,
    String? notas,
  }) async {
    final sedeId = AuthService.instance.currentUser?.sedeId;
    final qs = (sedeId != null && sedeId.isNotEmpty) ? '?sede_id=$sedeId' : '';
    await _api.post(
      '/api/v1/caja/traspaso$qs',
      body: {
        'nuevo_usuario_id': nuevoUsuarioId,
        if ((notas ?? '').trim().isNotEmpty) 'notas': notas!.trim(),
      },
    );
    await cargarEstado();
  }

  // Cierra la caja con lo declarado. El monto inicial sale de la apertura; solo
  // se manda uno si la caja no tenía apertura.
  Future<CierreCaja> cerrar({
    required double declaradoEfectivo,
    required double declaradoTarjeta,
    required double declaradoDigital,
    String? notas,
    double montoInicial = 0,
  }) async {
    final res = await _api.post(
      '/api/v1/caja/cierre',
      body: {
        if (montoInicial > 0) 'monto_inicial': montoInicial,
        'declarado_efectivo': declaradoEfectivo,
        'declarado_tarjeta': declaradoTarjeta,
        'declarado_digital': declaradoDigital,
        if ((notas ?? '').trim().isNotEmpty) 'notas': notas!.trim(),
      },
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('El servidor no devolvió el cierre');
    }
    final cierre = CierreCaja.fromJson(res);
    estadoCajaServidor = null;
    await cargarEstado();
    await cargarCierres();
    return cierre;
  }

  // ============================================================================
  // TURNOS DE CAJA
  // ============================================================================

  Future<List<Turno>> cargarTurnos() async {
    final sedeId = AuthService.instance.currentUser?.sedeId;
    final res = await _api.get(
      '/api/v1/configuracion/turnos',
      queryParams: {'sede_id': sedeId ?? ''},
    );
    if (res is! List) return [];
    return res.whereType<Map<String, dynamic>>().map(Turno.fromJson).toList();
  }

  Future<Turno> crearTurno({
    required String nombre,
    required String horaInicio,
    required String horaFin,
    required int orden,
    bool estado = true,
  }) async {
    final sedeId = AuthService.instance.currentUser?.sedeId;
    final res = await _api.post(
      '/api/v1/configuracion/turnos',
      body: {
        'sede_id': sedeId,
        'nombre': nombre,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'orden': orden,
        'estado': estado,
      },
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('No se pudo crear el turno');
    }
    return Turno.fromJson(res);
  }

  Future<Turno> actualizarTurno(
    String id, {
    String? nombre,
    String? horaInicio,
    String? horaFin,
    int? orden,
    bool? estado,
  }) async {
    final res = await _api.put(
      '/api/v1/configuracion/turnos/$id',
      body: {
        if (nombre != null) 'nombre': nombre,
        if (horaInicio != null) 'hora_inicio': horaInicio,
        if (horaFin != null) 'hora_fin': horaFin,
        if (orden != null) 'orden': orden,
        if (estado != null) 'estado': estado,
      },
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('No se pudo actualizar el turno');
    }
    return Turno.fromJson(res);
  }

  Future<void> eliminarTurno(String id) async {
    await _api.delete('/api/v1/configuracion/turnos/$id');
  }

  // ============================================================================
  // REPORTES DE CAJA
  // ============================================================================

  Future<Map<String, dynamic>> obtenerReporteTurno({
    String? aperturaId,
    String? cierreId,
  }) async {
    final sedeId = AuthService.instance.currentUser?.sedeId;
    final res = await _api.get(
      '/api/v1/caja/reportes/turno',
      queryParams: {
        'sede_id': sedeId ?? '',
        if (aperturaId != null) 'apertura_id': aperturaId,
        if (cierreId != null) 'cierre_id': cierreId,
      },
    );
    return res is Map<String, dynamic> ? res : {};
  }

  Future<void> imprimirReporteTurno({
    String? aperturaId,
    String? cierreId,
  }) async {
    final sedeId = AuthService.instance.currentUser?.sedeId;
    final params = <String>[
      if (sedeId != null && sedeId.isNotEmpty) 'sede_id=$sedeId',
      if (aperturaId != null && aperturaId.isNotEmpty) 'apertura_id=$aperturaId',
      if (cierreId != null && cierreId.isNotEmpty) 'cierre_id=$cierreId',
    ];
    final qs = params.isNotEmpty ? '?${params.join('&')}' : '';
    await _api.post('/api/v1/caja/reportes/turno/imprimir$qs');
  }

  Future<Map<String, dynamic>> obtenerReporteDiaConsolidado({
    String? fechaOperativa,
  }) async {
    final sedeId = AuthService.instance.currentUser?.sedeId;
    final res = await _api.get(
      '/api/v1/caja/reportes/dia-consolidado',
      queryParams: {
        'sede_id': sedeId ?? '',
        if (fechaOperativa != null) 'fecha_operativa': fechaOperativa,
      },
    );
    return res is Map<String, dynamic> ? res : {};
  }

  Future<void> imprimirReporteDiaConsolidado({String? fechaOperativa}) async {
    final sedeId = AuthService.instance.currentUser?.sedeId;
    final params = <String>[
      if (sedeId != null && sedeId.isNotEmpty) 'sede_id=$sedeId',
      if (fechaOperativa != null && fechaOperativa.isNotEmpty) 'fecha_operativa=$fechaOperativa',
    ];
    final qs = params.isNotEmpty ? '?${params.join('&')}' : '';
    await _api.post('/api/v1/caja/reportes/dia-consolidado/imprimir$qs');
  }

  Future<Map<String, dynamic>> obtenerReporteDiaDetallado({
    String? fechaOperativa,
  }) async {
    final sedeId = AuthService.instance.currentUser?.sedeId;
    final res = await _api.get(
      '/api/v1/caja/reportes/dia-detallado',
      queryParams: {
        'sede_id': sedeId ?? '',
        if (fechaOperativa != null) 'fecha_operativa': fechaOperativa,
      },
    );
    return res is Map<String, dynamic> ? res : {};
  }

  String urlReporteDiaDetalladoHTML({String? fechaOperativa}) {
    final base = _api.baseUrl;
    final sedeId = AuthService.instance.currentUser?.sedeId ?? '';
    final f = fechaOperativa != null ? '&fecha_operativa=$fechaOperativa' : '';
    return '$base/api/v1/caja/reportes/dia-detallado/html?sede_id=$sedeId$f';
  }
}
