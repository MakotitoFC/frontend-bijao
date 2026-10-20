import '../data/cierres_store.dart';
import '../models/caja_servidor.dart';
import '../models/cierre_caja.dart';
import '../utils/uuid_helper.dart';
import 'api_client.dart';
import 'auth_service.dart';

// Caja contra el servidor: estado y apertura del turno, totales por medio de
// pago, cierre y cierres anteriores (`/api/v1/caja/...`). El servidor calcula
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
  Future<void> abrir({required double montoInicial, String? notas}) async {
    final sedeId = AuthService.instance.currentUser?.sedeId;
    await _api.post(
      '/api/v1/caja/apertura',
      body: {
        'sede_id': sedeId,
        'monto_inicial': montoInicial,
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
}
