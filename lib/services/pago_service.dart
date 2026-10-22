import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/medio_pago.dart';
import '../models/pago.dart';
import '../models/pedido.dart';
import '../utils/uuid_helper.dart';
import 'api_client.dart';

// Pagos contra el servidor: `POST /api/pagos` para cobrar y
// `GET /api/pedidos/:id/pagos` para leer lo ya cobrado. El servidor calcula el
// recargo del método de pago y pasa el pedido a 'pagado' cuando se cubre el
// total; la app guarda en memoria lo que él responde.
class PagoService {
  PagoService._();
  static final PagoService instance = PagoService._();

  final ApiClient _api = ApiClient.instance;

  // Solo los pedidos y métodos que existen en el servidor (ids UUID) se cobran
  // ahí. Los datos de demostración locales siguen funcionando en memoria.
  bool _enServidor(Pedido pedido, MedioPago medio) =>
      UuidHelper.isValid(pedido.id) && UuidHelper.isValid(medio.id);

  // Cobra [montoAbonado] de la cuenta con [medio]. Si el servidor rechaza el
  // pago, lanza el error y NO deja nada registrado en la app. [pagador] es el
  // nombre en un pago compartido.
  Future<Pago> registrar({
    required Pedido pedido,
    required MedioPago medio,
    required double montoAbonado,
    double propina = 0,
    String? pagador,
    String? categoriaMovimientoId,
  }) async {
    // Un pedido del servidor no puede cobrarse con un método que no lo es (p. ej.
    // los de respaldo que se muestran cuando el servidor no tiene ninguno): el
    // cobro quedaría solo en esta pantalla y el servidor no lo sabría.
    if (UuidHelper.isValid(pedido.id) && !UuidHelper.isValid(medio.id)) {
      throw Exception(
        'El método de pago "${medio.medioPago}" no existe en el servidor. '
        'Configura los métodos de pago (Configuración) o cierra sesión y vuelve '
        'a entrar para cargarlos.',
      );
    }
    if (!_enServidor(pedido, medio)) {
      return registrarPago(
        pedido: pedido,
        medioPago: medio,
        montoAbonado: montoAbonado,
        propina: propina,
        pagador: pagador,
      );
    }
    // El servidor solo acepta abonar lo que falta de la cuenta: la propina y el
    // táper de la app no cuentan. Se manda lo que el cajero cobra de cuenta y,
    // aparte, la propina pendiente (solo en el primer pago que la lleva).
    final saldoCuenta = saldoCuentaDePedido(pedido.id);
    final abono = montoAbonado > saldoCuenta + 0.01
        ? saldoCuenta
        : montoAbonado;
    final propinaAEnviar = propina > 0
        ? propina
        : propinaPendienteDePedido(pedido.id);
    final res = await _api.post(
      '/api/pagos',
      body: {
        'pedido_id': pedido.id,
        'medio_pago_id': medio.id,
        'monto_abonado': abono,
        'propina': propinaAEnviar,
        if (pagador != null && pagador.isNotEmpty) 'pagador': pagador,
        if (categoriaMovimientoId != null &&
            UuidHelper.isValid(categoriaMovimientoId))
          'categoria_movimiento_id': categoriaMovimientoId,
      },
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('El servidor no devolvió el pago registrado');
    }
    return aplicarPagoDelServidor(
      pedido: pedido,
      medio: medio,
      json: res,
      pagador: pagador,
    );
  }

  // Trae los pagos del día (`GET /api/pagos?desde=&hasta=`) para las pantallas
  // Pagos y Caja: así no quedan vacías al recargar la página.
  Future<void> cargarDelDia() {
    final hoy = DateTime.now();
    return cargarDelRango(hoy, hoy);
  }

  // Trae los pagos de un rango de fechas (inclusive) y los suma a los que ya
  // están en pantalla.
  Future<void> cargarDelRango(DateTime desde, DateTime hasta) async {
    String dos(int n) => n.toString().padLeft(2, '0');
    String f(DateTime d) => '${d.year}-${dos(d.month)}-${dos(d.day)}';
    final res = await _api.get(
      '/api/pagos?desde=${f(desde)}&hasta=${f(hasta)}',
    );
    if (res is! List) return;
    agregarPagosDelServidor(res.whereType<Map<String, dynamic>>().toList());
  }

  // Vuelve a leer del servidor los pagos de un pedido y deja su estado al día.
  // Sirve al abrir la pantalla de cobro (para no cobrar dos veces) y después de
  // un pago que quedó a medias.
  Future<void> cargarDePedido(Pedido pedido) async {
    if (!UuidHelper.isValid(pedido.id)) return;
    final res = await _api.get('/api/pedidos/${pedido.id}/pagos');
    if (res is! Map<String, dynamic>) return;
    final lista = res['pagos'];
    reemplazarPagosDePedido(pedido, [
      if (lista is List) ...lista.whereType<Map<String, dynamic>>(),
    ]);
    if (res['estado_pedido'] == 'pagado') {
      actualizarEstadoPedido(pedido.id, 'pagado');
    }
  }
}
