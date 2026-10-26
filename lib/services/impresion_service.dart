import '../models/config_impresora.dart';
import 'api_client.dart';

// Impresoras térmicas (ESC/POS, 80 mm) que maneja el backend: comandas de
// cocina automáticas al pedir, reimpresión, prueba, cola y configuración.
class ImpresionService {
  ImpresionService._();
  static final ImpresionService instance = ImpresionService._();

  static const _base = '/api/v1/impresion';
  final ApiClient _api = ApiClient.instance;

  // Hace ping a las impresoras: puede tardar unos segundos si no responden.
  Future<EstadoImpresoras> obtenerEstado() async {
    final res = await _api.get(
      '$_base/estado',
      timeout: const Duration(seconds: 15),
    );
    return EstadoImpresoras.fromJson(res as Map<String, dynamic>);
  }

  Future<ConfigImpresora> obtenerConfig() async {
    final res = await _api.get('$_base/config');
    return ConfigImpresora.fromJson(res as Map<String, dynamic>);
  }

  // Todos los campos son opcionales: se envía solo lo que cambia.
  Future<void> actualizarConfig(Map<String, dynamic> cambios) async {
    await _api.put('$_base/config', body: cambios);
  }

  Future<void> guardarConfig(ConfigImpresora config) =>
      actualizarConfig(config.toJson());

  // Sube el logo de los tickets de caja (.png, .jpg, .jpeg, .bmp).
  // Devuelve la ruta que guardó el backend.
  Future<String> subirLogo(List<int> bytes, String nombreArchivo) async {
    final res = await _api.subirArchivo(
      '$_base/config/logo',
      bytes: bytes,
      nombreArchivo: nombreArchivo,
      campo: 'logo',
    );
    return res is Map ? (res['ruta']?.toString() ?? '') : '';
  }

  Future<void> imprimirPrueba(String destino) async {
    await _api.post('$_base/test', body: {'destino': destino});
  }

  // Imprime de nuevo la comanda completa del pedido, con el rótulo
  // "REIMPRESION" y el mismo número de orden.
  // [tipo]: 'cocina' (la comanda) o 'cuenta' (la precuenta en la impresora de
  // caja, con el recargo si ya hay pagos con tarjeta).
  Future<void> reimprimirPedido(
    String pedidoId, {
    String tipo = 'cocina',
  }) async {
    await _api.post('$_base/pedidos/$pedidoId/reimprimir?tipo=$tipo', body: {});
  }

  Future<void> pausarCola(bool pausar) async {
    await _api.post('$_base/cola/pausar', body: {'pausar': pausar});
  }

  Future<int> cancelarPendientes() async {
    final res = await _api.post('$_base/cola/cancelar-pendientes', body: {});
    return res is Map ? (res['cancelados'] as num?)?.toInt() ?? 0 : 0;
  }

  Future<ColaImpresion> obtenerCola() async {
    final res = await _api.get('$_base/cola');
    return ColaImpresion.fromJson(res as Map<String, dynamic>);
  }

  Future<void> reintentarTrabajo(String jobId) async {
    await _api.post('$_base/jobs/$jobId/reintentar', body: {});
  }

  // Pulso para abrir el cajón de dinero (cajero o administrador).
  Future<void> abrirCajon() async {
    await _api.post('/api/v1/caja/abrir-cajon', body: {});
  }

  // ----------------------------------------------------------------------
  // PLANTILLAS DE IMPRESIÓN LOW-CODE
  // ----------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> obtenerPlantillas() async {
    final res = await _api.get('$_base/plantillas');
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> obtenerPlantilla(String tipo) async {
    final res = await _api.get('$_base/plantillas/$tipo');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> actualizarPlantilla(
    String tipo,
    Map<String, dynamic> datos,
  ) async {
    final res = await _api.put('$_base/plantillas/$tipo', body: datos);
    if (res is Map && res['plantilla'] is Map) {
      return Map<String, dynamic>.from(res['plantilla'] as Map);
    }
    return {};
  }
}
