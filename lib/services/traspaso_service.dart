import '../data/traspasos_store.dart';
import '../models/rbac.dart';
import '../models/traspaso_pedido.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'catalog_service.dart';
import 'pedido_mozo_service.dart';

// Traspaso de pedidos entre mozos (`/api/v1/mozo/traspasos`): el mozo que se
// va lo envía a UN solo mozo, que lo acepta o lo rechaza.
class TraspasoService {
  TraspasoService._();
  static final TraspasoService instance = TraspasoService._();

  static const _base = '/api/v1/mozo/traspasos';
  final ApiClient _api = ApiClient.instance;

  // Trae las solicitudes pendientes del usuario. Si el servidor todavía no
  // tiene la ruta, la lista queda vacía sin molestar.
  Future<void> cargar() async {
    try {
      final res = await _api.get('$_base?estado=pendiente');
      final lista = res is List
          ? res
          : (res is Map<String, dynamic> && res['traspasos'] is List
                ? res['traspasos'] as List
                : const []);
      reemplazarTraspasos([
        for (final j in lista.whereType<Map<String, dynamic>>())
          TraspasoPedido.fromJson(j),
      ]);
    } catch (_) {
      // Sin ruta o sin conexión: se mantiene lo que había.
    }
  }

  // Mozos activos de la sede a quienes se puede traspasar, tal como los tiene
  // el servidor (nunca la lista de prueba de la app). Primero la ruta pensada
  // para el mozo; si no existe, la lista de usuarios (solo con ese permiso).
  Future<List<({String id, String nombre})>> mozosDisponibles() async {
    final yo = AuthService.instance.currentUser?.id;
    try {
      final res = await _api.get('/api/v1/mozo/mozos');
      final lista = res is List
          ? res
          : (res is Map<String, dynamic> && res['mozos'] is List
                ? res['mozos'] as List
                : null);
      if (lista != null) {
        return [
          for (final j in lista.whereType<Map<String, dynamic>>())
            if (j['id']?.toString() != yo && j['activo'] != false)
              (
                id: j['id']?.toString() ?? '',
                nombre: (j['nombre'] ?? j['usuario'])?.toString() ?? '',
              ),
        ];
      }
    } catch (_) {
      // Sin la ruta: se prueba con la lista general de usuarios.
    }
    final usuarios = await CatalogService.instance.cargarUsuariosRBAC();
    return [
      for (final UserRBACModel u in usuarios)
        if (u.estado && u.id != yo && u.rolNombre.toUpperCase() == 'MOZO')
          (id: u.id, nombre: u.usuario),
    ];
  }

  // El mozo dueño del pedido lo ofrece a [destinoId].
  Future<void> solicitar(String pedidoId, String destinoId) async {
    await _api.post(
      '/api/v1/mozo/pedidos/$pedidoId/traspaso',
      body: {'mozo_destino_id': destinoId},
    );
    await cargar();
  }

  // El administrador pasa el pedido a otro mozo sin que este tenga que aceptar
  // (por ejemplo, cuando el mozo dueño ya se fue).
  Future<void> reasignar(String pedidoId, String destinoId) async {
    await _api.post(
      '/api/v1/mozo/pedidos/$pedidoId/reasignar',
      body: {'mozo_destino_id': destinoId},
    );
    await PedidoMozoService.instance.sincronizar(sobreLegacy: true);
  }

  Future<void> aceptar(String id) => _responder(id, 'aceptar');
  Future<void> rechazar(String id) => _responder(id, 'rechazar');
  Future<void> cancelar(String id) => _responder(id, 'cancelar');

  Future<void> _responder(String id, String accion) async {
    await _api.post('$_base/$id/$accion', body: {});
    await cargar();
  }

  void limpiar() => reemplazarTraspasos(const []);
}
