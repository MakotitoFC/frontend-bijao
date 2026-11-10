import '../data/cargos_extra_store.dart';
import '../data/configuracion_store.dart';
import '../data/movimientos_caja_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/medio_pago.dart';
import '../models/movimiento_caja.dart';
import '../models/pago.dart';
import '../models/pedido.dart';
import '../utils/uuid_helper.dart';
import 'api_client.dart';
import 'movimiento_caja_service.dart';

// Pagos contra el servidor: `POST /api/pagos` para cobrar y
// `GET /api/pedidos/:id/pagos` para leer lo ya cobrado. El servidor calcula el
// recargo del método de pago y pasa el pedido a 'pagado' cuando se cubre el
// total; la app guarda en memoria lo que él responde.
class PagoService {
  PagoService._();
  static final PagoService instance = PagoService._();

  final ApiClient _api = ApiClient.instance;

  // Aviso para quien cobra cuando la propina no pudo salir del efectivo de la
  // caja (la pantalla lo muestra una vez y lo limpia).
  String? avisoPropina;

  // La propina pagada con Yape, tarjeta u otro medio que no es efectivo sale
  // del efectivo de la caja para dársela al mozo: se registra como una salida.
  // Si se pagó en efectivo, el dinero ya está en la caja y no hay salida.
  Future<void> _salidaPorPropina(
    Pedido pedido,
    MedioPago medioDelPago,
    double monto,
  ) async {
    if (monto <= 0.005) return;
    final esEfectivo =
        medioDelPago.grupo == 'efectivo' ||
        medioDelPago.medioPago.toLowerCase().contains('efectivo');
    if (esEfectivo) return;
    try {
      final efectivo = mediosPagoActivos
          .where((m) => m.grupo == 'efectivo')
          .firstOrNull;
      if (efectivo == null) {
        avisoPropina =
            'No hay un método de pago en efectivo para registrar la salida de '
            'la propina (S/ ${monto.toStringAsFixed(2)}). Regístrala en Caja.';
        return;
      }
      if (categoriasMovimiento.isEmpty) {
        await MovimientoCajaService.instance.cargarCategorias();
      }
      var categoria = categoriasMovimiento
          .where(
            (c) =>
                c.activo &&
                c.tipo == TipoMovimiento.egreso &&
                c.nombre.toLowerCase().contains('propina'),
          )
          .firstOrNull;
      categoria ??= await MovimientoCajaService.instance.crearCategoria(
        nombre: 'Propinas',
        tipo: TipoMovimiento.egreso,
      );
      final mozo = (pedido.mozoNombre ?? '').trim();
      await MovimientoCajaService.instance.registrar(
        categoria: categoria,
        monto: monto,
        medio: efectivo,
        nota:
            'Propina del pedido #${pedido.numeroPedido}'
            '${mozo.isEmpty ? '' : ' para $mozo'} '
            '(pagada con ${medioDelPago.medioPago})',
      );
    } catch (_) {
      avisoPropina =
          'No se pudo registrar la salida de la propina (S/ '
          '${monto.toStringAsFixed(2)}). Regístrala en Caja como salida.';
    }
  }

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
    double? montoRecibido,
    double? vuelto,
    List<CargoExtra>? cargosExtra,
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
    final cargosTotal = cargosExtra?.fold(0.0, (s, c) => s + c.monto) ?? 0.0;
    final saldoMaximo = saldoCuenta + cargosTotal;
    final abono = montoAbonado > saldoMaximo + 0.01
        ? saldoMaximo
        : montoAbonado;
    // Nunca se registra un cobro en cero por un error de cálculo del saldo
    // (por ejemplo, si el pedido aún no cargó sus productos): se pide
    // actualizar y reintentar. Los cobros en cero solo existen en cuentas de
    // familia, que mandan monto 0 a propósito.
    if (montoAbonado > 0.005 && abono <= 0.005) {
      throw Exception(
        'No se pudo calcular el saldo de este pedido. Actualiza la pantalla y '
        'vuelve a intentar el cobro.',
      );
    }
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
        if (montoRecibido != null && montoRecibido > 0)
          'monto_recibido': montoRecibido,
        if (vuelto != null && vuelto > 0) 'vuelto': vuelto,
        if (cargosExtra != null && cargosExtra.isNotEmpty)
          'cargos_extra': cargosExtra
              .map(
                (c) => {
                  'concepto': 'rotura',
                  'producto': c.nombre,
                  'monto': c.monto,
                },
              )
              .toList(),
      },
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('El servidor no devolvió el pago registrado');
    }
    final pago = aplicarPagoDelServidor(
      pedido: pedido,
      medio: medio,
      json: res,
      pagador: pagador,
    );
    await _salidaPorPropina(pedido, medio, propinaAEnviar);
    return pago;
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
    // El servidor toma una fecha sola ("2026-11-08") como medianoche UTC: el
    // "hoy" se corría 5 horas y los cobros de la noche (desde las 7 p. m. en
    // Lima) no volvían al recargar. Se manda el día completo con la hora de
    // este equipo, como instantes.
    String f(DateTime d) =>
        Uri.encodeQueryComponent(d.toUtc().toIso8601String());
    final inicio = DateTime(desde.year, desde.month, desde.day);
    final fin = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59);
    final res = await _api.get('/api/pagos?desde=${f(inicio)}&hasta=${f(fin)}');
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

  // Rectifica el medio de pago de un cobro ya registrado (Módulo de Descargos).
  Future<Map<String, dynamic>> rectificarPago({
    required String pagoId,
    required String nuevoMedioPagoId,
    required String motivo,
  }) async {
    final res = await _api.post(
      '/api/pagos/$pagoId/rectificar',
      body: {'nuevo_medio_pago_id': nuevoMedioPagoId, 'motivo': motivo.trim()},
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('El servidor no devolvió la confirmación del descargo');
    }
    return res;
  }

  // Busca todos los datos de pago y movimientos de un pedido por su ID
  Future<Map<String, dynamic>> getPagosByPedido(String pedidoId) async {
    final res = await _api.get('/api/pedidos/$pedidoId/pagos');
    if (res is! Map<String, dynamic>) {
      throw Exception('No se encontraron pagos para el pedido');
    }
    return res;
  }

  // Busca todos los datos de pago y movimientos de un pedido por su número de orden de comanda
  Future<Map<String, dynamic>> buscarPedidoPorComanda(int comandaNumero, {DateTime? fecha}) async {
    String q = '';
    if (fecha != null) {
      final fStr = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
      q = '?fecha=$fStr';
    }
    final res = await _api.get('/api/caja/pedidos/comanda/$comandaNumero$q');
    if (res is! Map<String, dynamic>) {
      throw Exception('No se encontró pedido con el número de comanda indicado');
    }
    return res;
  }
}
