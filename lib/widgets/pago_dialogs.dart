import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cargos_extra_store.dart';
import '../data/configuracion_store.dart';
import '../data/inventario_store.dart';
import '../models/producto_inventario.dart';
import '../data/movimientos_caja_store.dart';
import '../data/pagos_store.dart';
import '../utils/uuid_helper.dart';
import '../data/pedidos_store.dart' show establecerPropinaPedido;
import '../models/movimiento_caja.dart';
import '../services/movimiento_caja_service.dart';
import 'app_select.dart';
import '../services/api_client.dart';
import '../services/pago_service.dart';
import '../services/catalog_service.dart';
import '../models/medio_pago.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import 'app_switch.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'comprobante_en_cobro.dart';
import 'dialogo_app.dart';
import 'indicador_abajo.dart';

const naranjaPago = Color(0xFFF07F13);

// Lo que devuelve un modal de pago cuando se toca "Regresar": el que lo abrió
// vuelve a mostrar la elección entre pago único y compartido.
class _VolverAElegirPago {
  const _VolverAElegirPago();
}

const Object volverAElegirPago = _VolverAElegirPago();

double leerMonto(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.')) ?? 0;

// Contenedor común de los modales de pago (hoja en mobile, tarjeta en escritorio).
class ModalPago extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget child;
  final double anchoEscritorio;
  // Si viene, se muestra un botón "Regresar" junto al título.
  final VoidCallback? onVolver;
  // Si viene, queda fijo abajo (fuera del scroll) y el scroll de [child] lleva
  // un padding a la derecha para que su barra no tape el contenido.
  final Widget? pie;
  // Diseño de ficha: encabezado con su separador de borde a borde, cuerpo con
  // scroll y un pie fijo con sus botones, también separado. La "x" va en un
  // cuadro redondeado a la derecha.
  final bool ficha;
  // Aire entre el contenido y la barra de scroll (sin pie fijo).
  final EdgeInsetsGeometry scrollPadding;

  const ModalPago({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.anchoEscritorio = 440,
    this.onVolver,
    this.pie,
    this.ficha = false,
    this.scrollPadding = EdgeInsets.zero,
  });

  Widget _fichaBuild(BuildContext context, bool esMobile, double ancho) {
    final divisor = Divider(height: 1, color: Colors.grey.shade200);
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? ancho : anchoEscritorio,
          maxWidth: esMobile ? ancho : anchoEscritorio,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, esMobile ? 30 : 22, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitulo,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'Cerrar',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            divisor,
            Flexible(
              child: IndicadorAbajo(
                builder: (ctl) => SingleChildScrollView(
                  controller: ctl,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: child,
                ),
              ),
            ),
            if (pie != null) ...[
              divisor,
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: pie,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    if (ficha) return _fichaBuild(context, esMobile, ancho);
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? ancho : anchoEscritorio,
          maxWidth: esMobile ? ancho : anchoEscritorio,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, esMobile ? 28 : 22, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (onVolver != null) ...[
                    Tooltip(
                      message: 'Regresar',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onVolver,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Icon(
                            LucideIcons.chevronLeft,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitulo,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BotonCerrarCircular(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SeparadorDialogo(),
              Flexible(
                child: pie != null
                    // Con pie fijo: el scroll lleva el aviso ">" de que hay
                    // más contenido abajo.
                    ? IndicadorAbajo(
                        builder: (ctl) => SingleChildScrollView(
                          controller: ctl,
                          padding: const EdgeInsets.only(right: 14),
                          child: child,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: scrollPadding,
                        child: child,
                      ),
              ),
              if (pie != null) ...[const SizedBox(height: 12), pie!],
            ],
          ),
        ),
      ),
    );
  }
}

Widget tarjetaSaldo(String etiqueta, double monto) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          'S/ ${monto.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryGreen,
          ),
        ),
      ],
    ),
  );
}

// Cobra de una vez todo el saldo pendiente con un solo método de pago.
// Devuelve true si el cobro se registró, o [volverAElegirPago] si se tocó
// "Regresar".
class PagarPedidoDialog extends StatefulWidget {
  final Pedido pedido;
  final String titulo;
  final bool permiteVolver;

  const PagarPedidoDialog({
    super.key,
    required this.pedido,
    required this.titulo,
    this.permiteVolver = false,
  });

  @override
  State<PagarPedidoDialog> createState() => _PagarPedidoDialogState();
}

// Un medio de pago y cuánto de la cuenta se paga con él (pago con varios medios).
class _FilaMedio {
  MedioPago medio;
  final TextEditingController monto = TextEditingController();

  _FilaMedio(this.medio);
}

class _PagarPedidoDialogState extends State<PagarPedidoDialog> {
  // Por defecto, efectivo (o el primero activo si no hay uno en efectivo).
  late MedioPago _medio = mediosPagoActivos.firstWhere(
    (m) => m.grupo == 'efectivo',
    orElse: () => mediosPagoActivos.first,
  );
  // Comprobante a emitir al cobrar (solo administración y caja lo eligen).
  ComprobanteEnCobro? _comprobante;
  // La misma persona puede pagar con varios medios y montos (por ejemplo, una
  // parte en efectivo y el resto en Yape). Con esto activado, el pago se reparte
  // en las filas de [_filas].
  bool _dividir = false;
  final List<_FilaMedio> _filas = [];
  // Efectivo con el que paga el cliente (para calcular el vuelto). Solo se pide
  // si se activa "Vuelto".
  final _recibidoCtrl = TextEditingController();
  // El campo de vuelto sale solo si algún pago es en efectivo: el medio elegido
  // o cualquiera de las filas de "Por montos".
  bool get _hayEfectivo => _dividir
      ? _filas.any((f) => f.medio.grupo == 'efectivo')
      : _medio.grupo == 'efectivo';
  // Extras: propina (con su campo) y roturas o alquiler de menaje.
  late final double _propinaInicial = propinaPendienteDePedido(
    widget.pedido.id,
  );
  late final _propinaCtrl = TextEditingController(
    text: _propinaInicial > 0.005 ? _propinaInicial.toStringAsFixed(2) : '',
  );
  bool _conRoturas = false;
  final List<CargoExtra> _cargos = [];
  // Producto de inventario elegido (su id).
  String? _menajeElegido;
  final _costoCargoCtrl = TextEditingController();

  // El menaje sale del inventario: los productos de tipo menaje y, si no hay
  // ninguno marcado así, todos los productos (igual que "Utensilios rotos").
  List<ProductoInventario> get _menaje {
    final todos = productosInventario.where((p) => p.estado).toList();
    final menaje = todos
        .where(
          (p) => (p.tipoProductoNombre ?? '').toLowerCase().contains('menaje'),
        )
        .toList();
    return menaje.isNotEmpty ? menaje : todos;
  }

  double get _totalCargos => _cargos.fold(0.0, (s, c) => s + c.monto);

  // Lo que el cliente entrega en efectivo en las filas de "Por montos".
  double get _efectivoFila => _filas
      .where((f) => f.medio.grupo == 'efectivo')
      .fold(0.0, (s, f) => s + leerMonto(f.monto.text));

  // Por montos: lo que las filas suman de más sobre la cuenta. Ese sobrante no
  // es un pago adicional: es la propina que el cliente ya incluyó (la escrita en
  // Propina), vuelto (solo de lo que entregó en efectivo) o propina que deja.
  double get _sobra {
    if (!_dividir) return 0.0;
    final s = _asignado - _totalOrden;
    return s > 0.01 ? s : 0.0;
  }

  // La parte del sobrante que es la propina escrita: ya viene dentro de las
  // filas, no se cobra otra vez.
  double get _propinaDentro =>
      _sobra < _propinaManual ? _sobra : _propinaManual;

  // Lo que sobra después de esa propina.
  double get _resto => _sobra - _propinaDentro;

  // El resto que no se puede devolver (supera el efectivo entregado): solo
  // puede quedar como propina.
  bool get _restoSoloPropina => _resto > _efectivoFila + 0.005;

  // El resto que sí se puede devolver en efectivo (o dejar como propina).
  double get _excedente =>
      (_resto > 0.005 && !_restoSoloPropina) ? _resto : 0.0;

  // El sobrante tiene salida válida: propina escrita, vuelto o propina.
  bool get _sobraResuelta =>
      _sobra <= 0.005 ||
      _resto <= 0.005 ||
      !_restoSoloPropina ||
      config.propinaHabilitada;

  // Lo que del sobrante se aplica fuera de la cuenta (no se cobra a la cuenta).
  double get _sobraAplicable => _sobraResuelta ? _sobra : 0.0;

  // Lo que se cobra en efectivo: sin recargo, y con la propina y el táper.
  double get _efectivoACobrar {
    final enEfectivo = _dividir
        ? _efectivoFila - _excedente
        : (_medio.grupo == 'efectivo' ? _saldo : 0.0);
    return enEfectivo > 0.005
        ? enEfectivo + _propinaManual + _taper + _totalCargos
        : 0.0;
  }

  // Con un solo medio, lo que escribe el cajero: con cuánto paga el cliente en
  // efectivo. Por montos no hay otra casilla: el efectivo entregado es el de su
  // fila (más los extras que se pagan en efectivo).
  double get _recibido {
    if (!_hayEfectivo) return 0.0;
    if (_dividir) {
      return _efectivoFila > 0.005
          ? _efectivoFila +
                (_propinaManual - _propinaDentro) +
                _taper +
                _totalCargos
          : 0.0;
    }
    return leerMonto(_recibidoCtrl.text);
  }

  // Lo que el cliente entrega de más en efectivo: puede devolverse o, si quiere,
  // dejarse como propina.
  double get _sobraEfectivo {
    if (_dividir) return _excedente;
    final r = _recibido;
    return r > _efectivoACobrar + 0.005 ? r - _efectivoACobrar : 0.0;
  }

  // Por montos: el sobrante que no se puede devolver pasa a propina solo.
  double get _propinaForzada =>
      (_dividir && _restoSoloPropina && config.propinaHabilitada)
      ? _resto
      : 0.0;

  // El cliente deja ese sobrante como propina (solo si la propina está activa).
  bool _vueltoComoPropina = false;
  bool get _sobranteEsPropina =>
      _vueltoComoPropina && config.propinaHabilitada && _sobraEfectivo > 0.005;
  double get _propinaDeVuelto =>
      _propinaForzada + (_sobranteEsPropina ? _sobraEfectivo : 0.0);
  double get _vuelto => _sobranteEsPropina ? 0.0 : _sobraEfectivo;

  // Vacío = pagó justo; si se escribe, tiene que alcanzar para lo de efectivo.
  bool get _recibidoValido =>
      _dividir ||
      _recibidoCtrl.text.trim().isEmpty ||
      _efectivoACobrar <= 0.005 ||
      _recibido >= _efectivoACobrar - 0.005;

  @override
  void dispose() {
    _comprobante?.dispose();
    _recibidoCtrl.dispose();
    _propinaCtrl.dispose();
    _costoCargoCtrl.dispose();
    for (final f in _filas) {
      f.monto.dispose();
    }
    super.dispose();
  }

  // Suma de lo asignado a las cuentas en las filas.
  double get _asignado =>
      _filas.fold(0.0, (s, f) => s + leerMonto(f.monto.text));
  double get _totalOrden => _saldo + _totalCargos;
  double get _faltante => _totalOrden - (_asignado - _sobraAplicable);
  // Puede ser el total de la cuenta o un abono parcial. Solo se pasa de la
  // cuenta si lo que sobra es propina o se puede devolver en efectivo.
  bool get _repartoValido => _asignado > 0.005 && _sobraResuelta;
  bool get _repartoCompleto => _faltante.abs() < 0.01;

  void _alternarDividir(bool v) {
    setState(() {
      _dividir = v;
      for (final f in _filas) {
        f.monto.dispose();
      }
      _filas.clear();
      if (v) {
        _filas.add(
          _FilaMedio(_medio)..monto.text = _totalOrden.toStringAsFixed(2),
        );
      }
    });
  }

  void _agregarFila() {
    final restante = _faltante > 0.005 ? _faltante : 0.0;
    final usados = _filas.map((f) => f.medio.id).toSet();
    final otro = mediosPagoActivos.firstWhere(
      (m) => !usados.contains(m.id),
      orElse: () => mediosPagoActivos.first,
    );
    setState(
      () => _filas.add(
        _FilaMedio(otro)..monto.text = restante.toStringAsFixed(2),
      ),
    );
  }

  void _quitarFila(int i) {
    if (_filas.length <= 1) return;
    setState(() => _filas.removeAt(i).monto.dispose());
  }

  // La cuenta que cobra el servidor (sin la propina ni el táper de la app).
  double get _saldo => saldoCuentaDePedido(widget.pedido.id);
  // Abono a cuenta (pago parcial o total de la cuenta):
  // Con un solo método se paga toda la cuenta más los cargos extra registrados ahora.
  double get _montoCobroUnico => _saldo + _totalCargos;

  // Propina y táper: el cliente los paga además de la cuenta, sin recargo.
  // Con la propina apagada en Configuración no se ofrece al cobrar.
  double get _propinaManual =>
      config.propinaHabilitada ? leerMonto(_propinaCtrl.text) : 0.0;
  // La propina que se cobra: la escrita más el vuelto que el cliente deja.
  double get _propina => _propinaManual + _propinaDeVuelto;
  double get _taper => taperPendienteDePedido(widget.pedido.id);
  // Recargo del método elegido (p. ej. tarjeta): se suma al total del cliente.
  double get _recargo => _dividir
      ? _filas.fold(
          0.0,
          (s, f) => s + f.medio.recargoSobre(leerMonto(f.monto.text)),
        )
      : _medio.recargoSobre(_montoCobroUnico);

  late final List<CategoriaMovimiento> _categoriasIngreso = categoriasDeTipo(
    TipoMovimiento.ingreso,
  );
  CategoriaMovimiento? _categoriaSeleccionada;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (puedeElegirComprobante(widget.pedido)) {
      _comprobante = ComprobanteEnCobro(totalDePedido(widget.pedido.id))
        ..addListener(() {
          if (mounted) setState(() {});
        });
      _comprobante!.asegurarInicializado(
        widget.pedido,
        recargoActual: _recargo,
      );
    }
    _categoriaSeleccionada =
        _categoriasIngreso
            .where((c) => c.nombre.toLowerCase().contains('venta'))
            .firstOrNull ??
        _categoriasIngreso.firstOrNull;
    // Los métodos se vuelven a leer cada vez que se abre el cobro: si el
    // administrador cambió el recargo de la tarjeta, aquí se ve el vigente (el
    // servidor siempre cobra con el que tiene guardado).
    if (productosInventario.isEmpty) {
      CatalogService.instance
          .cargarProductosInventario()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((_) {});
    }
    CatalogService.instance
        .cargarMediosPago()
        .then((_) {
          if (!mounted || mediosPagoActivos.isEmpty) return;
          MedioPago vigente(MedioPago m) =>
              mediosPagoActivos.where((x) => x.id == m.id).firstOrNull ??
              mediosPagoActivos.first;
          setState(() {
            _medio = vigente(_medio);
            for (final f in _filas) {
              f.medio = vigente(f.medio);
            }
          });
        })
        .catchError((_) {});
    if (categoriasMovimiento.isEmpty) {
      MovimientoCajaService.instance
          .cargarCategorias()
          .then((_) {
            if (mounted) {
              setState(() {
                final reloaded = categoriasDeTipo(TipoMovimiento.ingreso);
                _categoriaSeleccionada =
                    reloaded
                        .where((c) => c.nombre.toLowerCase().contains('venta'))
                        .firstOrNull ??
                    reloaded.firstOrNull;
              });
            }
          })
          // Sin conexión no se pueden leer las categorías: el cobro sigue.
          .catchError((_) {});
    }
  }

  Future<void> _pagar() async {
    final saldo = _saldo;
    if (saldo <= 0.01 || _guardando) return;
    if (_dividir && !_repartoValido) return;
    final recargo = _recargo;
    final extras = _propina + _taper + _totalCargos;
    // Lo que se cobra: un pago con el medio elegido o uno por cada fila.
    // Por montos, lo que pasó de la cuenta no se cobra a la cuenta: el vuelto sale
    // de las filas en efectivo y la propina que ya venía dentro, de las últimas
    // filas (así la propina queda en el medio con que se pagó).
    final cobros = <({MedioPago medio, double monto, double propina})>[];
    if (_dividir) {
      final montos = [for (final f in _filas) leerMonto(f.monto.text)];
      var porDevolver = _vuelto;
      for (var i = 0; i < montos.length; i++) {
        if (porDevolver > 0.005 && _filas[i].medio.grupo == 'efectivo') {
          final d = porDevolver < montos[i] ? porDevolver : montos[i];
          porDevolver -= d;
          montos[i] -= d;
        }
      }
      var porPropina = _sobraAplicable - _vuelto;
      final propinas = List<double>.filled(montos.length, 0);
      for (var i = montos.length - 1; i >= 0 && porPropina > 0.005; i--) {
        final d = porPropina < montos[i] ? porPropina : montos[i];
        porPropina -= d;
        montos[i] -= d;
        propinas[i] += d;
      }
      // Una fila que quedó solo en propina no es un pago a la cuenta: su
      // propina va con el primer pago que sí lo es.
      var huerfana = 0.0;
      for (var i = 0; i < montos.length; i++) {
        if (montos[i] <= 0.005 && propinas[i] > 0) {
          huerfana += propinas[i];
          propinas[i] = 0;
        }
      }
      final primero = montos.indexWhere((m) => m > 0.005);
      // La propina escrita que no venía dentro de las filas también va con él.
      final adicional = _propinaManual - _propinaDentro;
      if (primero >= 0) propinas[primero] += huerfana + adicional;
      for (var i = 0; i < montos.length; i++) {
        cobros.add((
          medio: _filas[i].medio,
          monto: montos[i],
          propina: propinas[i],
        ));
      }
    } else {
      cobros.add((medio: _medio, monto: _montoCobroUnico, propina: _propina));
    }
    // El vuelto y lo recibido se anotan en un solo pago en efectivo.
    var efectivoAnotado = false;
    setState(() => _guardando = true);
    // Cada pago lleva su parte de la propina: la pendiente del pedido no se
    // vuelve a mandar con otro pago.
    establecerPropinaPedido(widget.pedido.id, 0);
    var registrados = 0;
    String? ultimoPagoId;
    try {
      // Se registra en el servidor; si lo rechaza, no queda nada cobrado.
      for (final c in cobros) {
        if (c.monto <= 0.005) continue;
        final esEfectivo =
            c.medio.grupo == 'efectivo' ||
            c.medio.medioPago.toLowerCase().contains('efectivo');
        final anotaEfectivo = esEfectivo && !efectivoAnotado;
        if (esEfectivo) efectivoAnotado = true;
        final pago = await PagoService.instance.registrar(
          pedido: widget.pedido,
          medio: c.medio,
          montoAbonado: c.monto,
          propina: c.propina,
          categoriaMovimientoId: _categoriaSeleccionada?.id,
          montoRecibido: anotaEfectivo && _recibido > 0.005 ? _recibido : null,
          vuelto: anotaEfectivo && _vuelto > 0.005 ? _vuelto : null,
          cargosExtra: registrados == 0 && _cargos.isNotEmpty ? _cargos : null,
        );
        registrados++;
        ultimoPagoId = pago.id;
      }
    } catch (e) {
      if (!mounted) return;
      final texto = e is ApiException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      if (registrados > 0) {
        // Quedó cobrada una parte: se vuelve a leer y se cierra para ver el saldo.
        try {
          await PagoService.instance.cargarDePedido(widget.pedido);
        } catch (_) {}
        if (!mounted) return;
        showAppToast(
          context,
          'Se cobró una parte y falló otra: $texto. Revisa lo cobrado antes '
          'de seguir.',
          type: ToastType.error,
          titulo: 'Pago incompleto',
          duration: const Duration(seconds: 6),
        );
        Navigator.of(context).pop();
        return;
      }
      setState(() => _guardando = false);
      establecerPropinaPedido(widget.pedido.id, _propinaManual);
      showAppToast(
        context,
        'No se pudo registrar el cobro: $texto',
        type: ToastType.error,
        titulo: 'Pago no registrado',
      );
      return;
    }
    if (!mounted) return;
    registrarCargosExtra(widget.pedido.id, _cargos);
    if (_vuelto > 0.005) {
      efectivoRecibidoPorPedido[widget.pedido.id] = (
        recibido: _recibido,
        vuelto: _vuelto,
      );
    }
    showAppToast(
      context,
      'Cobro registrado · ${widget.titulo} · '
      'S/ ${(saldo + recargo + extras).toStringAsFixed(2)}'
      '${recargo > 0 ? ' (incluye recargo S/ ${recargo.toStringAsFixed(2)})' : ''}',
      type: ToastType.success,
      titulo: 'Pago registrado',
    );
    final avisoPropina = PagoService.instance.avisoPropina;
    if (avisoPropina != null) {
      PagoService.instance.avisoPropina = null;
      showAppToast(context, avisoPropina, type: ToastType.info);
    }
    // El cobro ya está guardado: ahora se emite el comprobante elegido.
    final eleccion = _comprobante;
    if (eleccion != null) {
      // Con un abono parcial (queda saldo), el comprobante es de ese pago y
      // muestra lo que se pagó ahora; al saldar, es el de toda la cuenta.
      // Si la cuenta ya tenía abonos, el último pago tampoco es "todo el monto":
      // su comprobante es solo de ese pago.
      // Los abonos de otros días no están en memoria: se leen todos los pagos
      // del pedido para saber si ya tenía abonos.
      try {
        await PagoService.instance.cargarDePedido(widget.pedido);
      } catch (_) {}
      final saldoRestante = faltaPorPagarDePedido(widget.pedido.id);
      final abonosPrevios =
          abonosDePedido(widget.pedido.id).length - registrados;
      final parcial = saldoRestante > 0.01 || abonosPrevios > 0;
      await emitirComprobanteTrasCobro(
        context,
        widget.pedido,
        eleccion,
        pagoId: parcial && UuidHelper.isValid(ultimoPagoId ?? '')
            ? ultimoPagoId
            : null,
      );
      if (!mounted) return;
    }
    Navigator.of(context).pop(true);
  }

  void _volver() => Navigator.of(context).pop(volverAElegirPago);

  // Una línea "texto ........ S/ monto" del resumen con recargo.
  Widget _filaMonto(
    String texto,
    double monto, {
    bool mas = false,
    bool fuerte = false,
  }) {
    final estilo = TextStyle(
      fontSize: fuerte ? 14 : 13,
      fontWeight: fuerte ? FontWeight.w800 : FontWeight.w500,
    );
    return Row(
      children: [
        Expanded(child: Text(texto, style: estilo)),
        Text('${mas ? '+' : ''}S/ ${monto.toStringAsFixed(2)}', style: estilo),
      ],
    );
  }

  // Un ícono que oriente según el nombre del método.
  IconData _icono(MedioPago m) {
    final n = m.medioPago.toLowerCase();
    if (n.contains('efectivo')) return LucideIcons.banknote;
    if (n.contains('tarjeta') || n.contains('visa') || n.contains('credito')) {
      return LucideIcons.creditCard;
    }
    if (n.contains('yape') || n.contains('plin') || n.contains('digital')) {
      return LucideIcons.smartphone;
    }
    return LucideIcons.wallet;
  }

  static String _grupoCorto(String grupo) => switch (grupo) {
    'efectivo' => 'Efectivo',
    'digital' => 'Digital',
    'credito' || 'planilla' => 'Crédito',
    _ => 'Tarjeta / otros',
  };

  // Un método de pago como card: icono, nombre y, debajo, su grupo o recargo.
  Widget _tarjetaMedio(MedioPago m) {
    final activo = m.id == _medio.id;
    final color = activo ? AppColors.primaryGreenDark : Colors.grey.shade700;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _medio = m;
          _comprobante?.actualizarRecargo(_recargo);
        });
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: activo
              ? AppColors.primaryGreen.withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
            width: activo ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icono(m), size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              m.medioPago,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: activo ? AppColors.primaryGreenDark : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              m.aplicaComision
                  ? '+${m.porcentajeComision.toStringAsFixed(1)}% recargo'
                  : _grupoCorto(m.grupo),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }

  // Todos los métodos en una cuadrícula que baja de línea según el ancho
  // (2 por fila en celular, más en pantallas anchas).
  Widget _cuadriculaMedios() {
    final medios = [
      for (final e in agruparMediosPago(mediosPagoActivos).entries) ...e.value,
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const espacio = 8.0;
        final columnas = (c.maxWidth / 130).floor().clamp(2, 5);
        final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final m in medios)
              SizedBox(width: ancho, child: _tarjetaMedio(m)),
          ],
        );
      },
    );
  }

  Widget _titulo(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
    ),
  );

  // Encabezado con interruptor: "Vuelto", "Por montos", "Propina".
  Widget _conInterruptor(
    String texto,
    bool valor,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        AppSwitch(value: valor, onChanged: onChanged),
      ],
    );
  }

  Widget _campoSoles(
    TextEditingController ctrl, {
    String hint = 'S/.',
    ValueChanged<String>? onChanged,
  }) {
    // Sin alto fijo: el campo toma el alto que necesita su texto (con 36 px se
    // cortaba a la mitad, sobre todo en celular).
    return CampoTexto(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (v) {
        setState(() {
          if (_sobraEfectivo <= 0.005) _vueltoComoPropina = false;
        });
        onChanged?.call(v);
      },
      decoration: InputDecoration(hintText: hint),
    );
  }

  // Por montos: una fila por medio, con su monto y una "x" para quitarla.
  Widget _filasDeMedios() {
    final falta = _faltante;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _filas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: AppSelect<String>(
                    compacto: true,
                    buscable: true,
                    value: _filas[i].medio.id,
                    hint: 'Buscar medio',
                    items: [
                      for (final m in mediosPagoActivos)
                        AppSelectItem(
                          value: m.id,
                          label: m.aplicaComision
                              ? '${m.medioPago} (+${m.porcentajeComision.toStringAsFixed(1)}%)'
                              : m.medioPago,
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      if (v != null) {
                        _filas[i].medio = mediosPagoActivos.firstWhere(
                          (m) => m.id == v,
                        );
                      }
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: _campoSoles(_filas[i].monto)),
                const SizedBox(width: 8),
                Opacity(
                  opacity: _filas.length > 1 ? 1 : 0.35,
                  child: BotonCerrarCircular(
                    tamano: 30,
                    onPressed: _filas.length > 1 ? () => _quitarFila(i) : () {},
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _agregarFila,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Agregar'),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                _textoPieFilas(falta),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: (_sobra > 0.005 && !_sobraResuelta)
                      ? AppColors.error
                      : ((_sobra > 0.005 || falta.abs() < 0.01)
                            ? AppColors.primaryGreen
                            : const Color(0xFF2563EB)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Qué dice el pie de las filas de "Por montos": si sobra, qué se hace con eso.
  String _textoPieFilas(double falta) {
    String s(double v) => v.toStringAsFixed(2);
    if (_sobra > 0.005) {
      if (!_sobraResuelta) {
        return 'Sobra S/ ${s(_sobra)}: solo se devuelve en efectivo';
      }
      final propina = _propinaDentro + _propinaDeVuelto;
      return [
        if (propina > 0.005) 'Propina S/ ${s(propina)}',
        if (_vuelto > 0.005) 'Vuelto S/ ${s(_vuelto)}',
      ].join(' · ');
    }
    return falta.abs() < 0.01
        ? 'Cuenta completa'
        : 'Abono parcial (restará S/ ${s(falta)})';
  }

  // Cuando el cliente entrega de más en efectivo: dar el vuelto o dejarlo como
  // propina (solo con la propina activa en Configuración).
  Widget _opcionSobrante() {
    final sobra = _sobraEfectivo;
    if (!config.propinaHabilitada || sobra <= 0.005) {
      return const SizedBox.shrink();
    }
    Widget boton(String texto, bool activo, VoidCallback onTap) => Expanded(
      child: SizedBox(
        height: AppSizes.boton,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: activo
                ? AppColors.primaryGreen.withValues(alpha: 0.10)
                : null,
            side: BorderSide(
              color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
              width: activo ? 1.5 : 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              texto,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: activo ? AppColors.primaryGreenDark : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'El cliente entrega S/ ${sobra.toStringAsFixed(2)} de más',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              boton(
                'Dar vuelto',
                !_sobranteEsPropina,
                () => setState(() => _vueltoComoPropina = false),
              ),
              const SizedBox(width: 8),
              boton(
                'Dejar como propina',
                _sobranteEsPropina,
                () => setState(() => _vueltoComoPropina = true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _cambiarPropina(String texto) {
    setState(() {
      establecerPropinaPedido(widget.pedido.id, _propinaManual);
    });
  }

  ProductoInventario? get _productoMenaje =>
      productosInventario.where((p) => p.id == _menajeElegido).firstOrNull;

  String get _nombreMenaje => _productoMenaje?.nombre ?? '';

  bool get _cargoValido =>
      _nombreMenaje.isNotEmpty && leerMonto(_costoCargoCtrl.text) > 0;

  void _agregarCargo() {
    if (!_cargoValido) return;
    setState(() {
      _cargos.add(
        CargoExtra(
          nombre: _nombreMenaje,
          monto: leerMonto(_costoCargoCtrl.text),
        ),
      );
      _menajeElegido = null;
      _costoCargoCtrl.clear();
    });
  }

  // Título gris de cada bloque de Extras.
  Widget _subtitulo(String texto) => Text(
    texto,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade600,
    ),
  );

  // Propina: solo el monto en soles. Si ya se anotó al registrar el pedido, aquí
  // aparece sola y se puede cambiar.
  Widget _columnaPropina() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _subtitulo('Propina'),
        const SizedBox(height: 8),
        _campoSoles(_propinaCtrl, onChanged: _cambiarPropina),
      ],
    );
  }

  Widget _columnaRoturas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _subtitulo('Roturas / alquiler')),
            AppSwitch(
              value: _conRoturas,
              onChanged: (v) => setState(() {
                _conRoturas = v;
                if (!v) {
                  _cargos.clear();
                  _menajeElegido = null;
                  _costoCargoCtrl.clear();
                }
              }),
            ),
          ],
        ),
        if (_conRoturas) ..._camposRoturas(),
      ],
    );
  }

  List<Widget> _camposRoturas() {
    return [
      const SizedBox(height: 8),
      // Buscador, costo y botón de agregar, en la misma fila.
      Row(
        children: [
          Expanded(
            flex: 5,
            child: AppSelect<String>(
              compacto: true,
              buscable: true,
              value: _menajeElegido,
              hint: 'Buscar menaje',
              items: [
                for (final m in _menaje)
                  AppSelectItem(value: m.id, label: m.nombre),
              ],
              onChanged: (v) => setState(() {
                _menajeElegido = v;
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _campoSoles(_costoCargoCtrl)),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Agregar',
            child: FilledButton.icon(
              onPressed: _cargoValido ? _agregarCargo : null,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Agregar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                minimumSize: const Size(0, AppSizes.boton),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
      for (var i = 0; i < _cargos.length; i++)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _cargos[i].nombre,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                'S/ ${_cargos[i].monto.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              BotonCerrarCircular(
                tamano: 28,
                onPressed: () => setState(() => _cargos.removeAt(i)),
              ),
            ],
          ),
        ),
    ];
  }

  // Extras: propina y roturas o alquiler, en una sola columna.
  Widget _extras() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo('Extras'),
        if (config.propinaHabilitada) ...[
          _columnaPropina(),
          const SizedBox(height: 14),
        ],
        _columnaRoturas(),
      ],
    );
  }

  // Lo que queda fijo abajo: tipo de comprobante y los botones. "Regresar" a
  // la izquierda; "Cancelar" y "Pagar" a la derecha.
  Widget _pieFijo(double saldo, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_comprobante != null) ...[
          SelectorComprobante(
            control: _comprobante!,
            pedido: widget.pedido,
            recargoActual: _recargo,
            parte: ParteComprobante.tipo,
          ),
          const SizedBox(height: 12),
        ],
        Builder(
          builder: (context) {
            final puedePagar =
                saldo > 0.01 &&
                !_guardando &&
                (_dividir ? _repartoValido : _totalOrden > 0.005) &&
                _recibidoValido &&
                (_comprobante?.completo ?? true);
            final bloqueo = _comprobante?.motivoBloqueo;
            final pagarBoton = FilledButton.icon(
              onPressed: puedePagar ? _pagar : null,
              icon: const Icon(LucideIcons.banknote, size: 18),
              label: Text(
                (_dividir && !_repartoCompleto)
                    ? 'Pagar abono · S/ ${total.toStringAsFixed(2)}'
                    : 'Pagar · S/ ${total.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(backgroundColor: naranjaPago),
            );
            final pagar = bloqueo == null
                ? pagarBoton
                : Tooltip(
                    message: bloqueo,
                    triggerMode: TooltipTriggerMode.tap,
                    child: pagarBoton,
                  );
            final cancelar = OutlinedButton(
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            );
            final regresar = OutlinedButton.icon(
              onPressed: _volver,
              icon: const Icon(LucideIcons.chevronLeft, size: 16),
              label: const Text('Regresar'),
            );
            // Celular: Pagar a todo el ancho y, debajo, Regresar y Cancelar
            // repartidos por igual.
            if (AppBreakpoints.esMobile(context)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  pagar,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (widget.permiteVolver) ...[
                        Expanded(child: regresar),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: cancelar),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                if (widget.permiteVolver) regresar,
                const Spacer(),
                cancelar,
                const SizedBox(width: 10),
                Flexible(child: pagar),
              ],
            );
          },
        ),
      ],
    );
  }

  // Tarjeta destacada con el total a pagar, como la ficha de resumen: ícono,
  // qué se paga y el monto grande a la derecha.
  Widget _tarjetaTotal(double total, double saldo) {
    return Container(
      padding: EdgeInsets.all(AppBreakpoints.esMobile(context) ? 12 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: AppBreakpoints.esMobile(context) ? 42 : 52,
            height: AppBreakpoints.esMobile(context) ? 42 : 52,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              LucideIcons.receipt,
              size: 24,
              color: AppColors.primaryGreen,
            ),
          ),
          SizedBox(width: AppBreakpoints.esMobile(context) ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total a pagar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Saldo de la cuenta: S/ ${saldo.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'S/ ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saldo = _saldo;
    final propina = _propina;
    final taper = _taper;
    final cargos = _totalCargos;
    final montoBase = _dividir ? _asignado - _sobraAplicable : _saldo;
    final total =
        (_dividir ? _asignado - _sobraAplicable : (_saldo + cargos)) +
        _recargo +
        propina +
        taper;
    return ModalPago(
      titulo: 'Pagar',
      anchoEscritorio:
          _comprobante != null && _comprobante!.tipo != 'ticket_venta'
          ? 600
          : 540,
      subtitulo: 'Pedido #${widget.pedido.numeroPedido} · ${widget.titulo}',
      ficha: true,
      pie: _pieFijo(saldo, total),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tarjetaTotal(total, saldo),
          const SizedBox(height: 20),
          _titulo('Método de pago'),
          if (!_dividir) _cuadriculaMedios(),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          // Efectivo recibido y vuelto, lado a lado: solo si se paga en efectivo.
          // Por montos no hay casilla aparte: el efectivo es el de su fila.
          if (_hayEfectivo && !_dividir) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _titulo('Efectivo recibido'),
                      _campoSoles(_recibidoCtrl, hint: 'S/.'),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _titulo('Vuelto'),
                      Container(
                        height: AppSizes.boton,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(AppRadii.button),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'S/ ${_vuelto.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _opcionSobrante(),
            if (!_recibidoValido)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Falta: el efectivo a cobrar es '
                  'S/ ${_efectivoACobrar.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
          ],
          _conInterruptor('Por montos', _dividir, _alternarDividir),
          if (_dividir) ...[
            const SizedBox(height: 8),
            _filasDeMedios(),
            _opcionSobrante(),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _extras(),
          // Datos del comprobante (cliente, ítems a reportar y desglose): van
          // en la parte con scroll para que el pie fijo no crezca ni deforme el
          // modal.
          if (_comprobante != null && _comprobante!.emite) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            SelectorComprobante(
              control: _comprobante!,
              pedido: widget.pedido,
              recargoActual: _recargo,
              parte: ParteComprobante.detalle,
            ),
          ],
          if (_recargo > 0 || propina > 0 || taper > 0 || cargos > 0) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _filaMonto(
              (_dividir && !_repartoCompleto) ? 'Abono a cuenta' : 'Cuenta',
              montoBase,
            ),
            if (_recargo > 0) ...[
              const SizedBox(height: 4),
              _filaMonto(
                _dividir
                    ? 'Recargo por medios de pago'
                    : 'Recargo ${_medio.medioPago.toLowerCase()} '
                          '(${_medio.porcentajeComision.toStringAsFixed(1)}%)',
                _recargo,
                mas: true,
              ),
            ],
            if (propina > 0) ...[
              const SizedBox(height: 4),
              _filaMonto('Propina (sin recargo)', propina, mas: true),
            ],
            if (taper > 0) ...[
              const SizedBox(height: 4),
              _filaMonto('Táper (sin recargo)', taper, mas: true),
            ],
            if (cargos > 0) ...[
              const SizedBox(height: 4),
              _filaMonto('Roturas / alquiler', cargos, mas: true),
            ],
            const SizedBox(height: 8),
            _filaMonto('Total a cobrar', total, fuerte: true),
          ],
        ],
      ),
    );
  }
}
