import '../models/reglas_cocina.dart';
import 'api_client.dart';

// Reglas de qué se imprime en la comanda de cocina
// (`/api/v1/impresion/reglas-cocina`). La impresión la hace el servidor: la app
// solo le dice qué categorías y platos deben salir.
class ReglasCocinaService {
  ReglasCocinaService._();
  static final ReglasCocinaService instance = ReglasCocinaService._();

  static const _ruta = '/api/v1/impresion/reglas-cocina';
  final ApiClient _api = ApiClient.instance;

  // Reglas guardadas en el servidor; null si todavía no existe la ruta.
  Future<ReglasCocina?> cargar() async {
    try {
      final res = await _api.get(_ruta);
      if (res is Map<String, dynamic>) return ReglasCocina.fromJson(res);
    } catch (_) {
      // Sin ruta o sin conexión.
    }
    return null;
  }

  Future<void> guardar(ReglasCocina reglas) async {
    await _api.put(_ruta, body: reglas.toJson());
  }
}
