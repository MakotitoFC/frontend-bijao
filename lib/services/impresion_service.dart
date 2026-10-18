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
  Future<void> reimprimirPedido(String pedidoId) async {
    await _api.post('$_base/pedidos/$pedidoId/reimprimir', body: {});
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
}
