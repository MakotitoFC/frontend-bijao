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
import 'app_tag.dart';
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

  const ModalPago({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.anchoEscritorio = 440,
    this.onVolver,
    this.pie,
  });

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
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
                    : SingleChildScrollView(child: child),
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
  late bool _conPropina = _propina > 0.005;
  late final _propinaCtrl = TextEditingController(
    text: _propina > 0.005 ? _propina.toStringAsFixed(2) : '',
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

  // Lo que se cobra en efectivo: sin recargo, y con la propina y el táper.
  double get _efectivoACobrar {
    final enEfectivo = _dividir
        ? _filas
              .where((f) => f.medio.grupo == 'efectivo')
              .fold(0.0, (s, f) => s + leerMonto(f.monto.text))
        : (_medio.grupo == 'efectivo' ? _montoCobroUnico : 0.0);
    return enEfectivo > 0.005
        ? enEfectivo + _propina + _taper + _totalCargos
        : 0.0;
  }

  // Lo que escribe el cajero: con cuánto paga el cliente en efectivo.
  double get _recibido => _hayEfectivo ? leerMonto(_recibidoCtrl.text) : 0.0;
  double get _vuelto {
    final r = _recibido;
    return r > _efectivoACobrar + 0.005 ? r - _efectivoACobrar : 0.0;
  }

  // Vacío = pagó justo; si se escribe, tiene que alcanzar para lo de efectivo.
  bool get _recibidoValido =>
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
  double get _faltante => _saldo - _asignado;
  // Puede ser el total de la cuenta o un abono parcial (siempre que no sobrepase el saldo)
  bool get _repartoValido => _asignado > 0.005 && _asignado <= _saldo + 0.01;
  bool get _repartoCompleto => _faltante.abs() < 0.01;

  void _alternarDividir(bool v) {
    setState(() {
      _dividir = v;
      for (final f in _filas) {
        f.monto.dispose();
      }
      _filas.clear();
      if (v) {
        _filas.add(_FilaMedio(_medio)..monto.text = _saldo.toStringAsFixed(2));
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
  // Con un solo método se paga toda la cuenta; el pago parcial se hace en
  // "Por montos" (las filas pueden sumar menos que el saldo).
  double get _montoCobroUnico => _saldo;

  // Propina y táper: el cliente los paga además de la cuenta, sin recargo.
  double get _propina => propinaPendienteDePedido(widget.pedido.id);
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
    final cobros = _dividir
        ? [
            for (final f in _filas)
              (medio: f.medio, monto: leerMonto(f.monto.text)),
          ]
        : [(medio: _medio, monto: _montoCobroUnico)];
    setState(() => _guardando = true);
    var registrados = 0;
    String? ultimoPagoId;
    try {
      // Se registra en el servidor; si lo rechaza, no queda nada cobrado.
      for (final c in cobros) {
        if (c.monto <= 0.005) continue;
        final esEfectivo =
            c.medio.grupo == 'efectivo' ||
            c.medio.medioPago.toLowerCase().contains('efectivo');
        final pago = await PagoService.instance.registrar(
          pedido: widget.pedido,
          medio: c.medio,
          montoAbonado: c.monto,
          categoriaMovimientoId: _categoriaSeleccionada?.id,
          montoRecibido: esEfectivo && _recibido > 0.005 ? _recibido : null,
          vuelto: esEfectivo && _vuelto > 0.005 ? _vuelto : null,
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
      final parcial = faltaPorPagarDePedido(widget.pedido.id) > 0.01;
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

  // Un método de pago como etiqueta de solo trazo (sin tarjeta).
  Widget _etiquetaMedio(MedioPago m) {
    return AppTag(
      etiqueta: m.aplicaComision
          ? '${m.medioPago} (+${m.porcentajeComision.toStringAsFixed(1)}%)'
          : m.medioPago,
      icono: _icono(m),
      activo: m.id == _medio.id,
      color: AppColors.primaryGreen,
      onTap: () {
        setState(() {
          _medio = m;
          _comprobante?.actualizarRecargo(_recargo);
        });
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
    return SizedBox(
      height: AppSizes.boton,
      child: CampoTexto(
        controller: ctrl,
        expands: true,
        maxLines: null,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        onChanged: (v) {
          setState(() {});
          onChanged?.call(v);
        },
        decoration: InputDecoration(hintText: hint),
      ),
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
            Text(
              falta.abs() < 0.01
                  ? 'Cuenta completa'
                  : (falta > 0
                        ? 'Abono parcial (restará S/ ${falta.toStringAsFixed(2)})'
                        : 'Sobra S/ ${(-falta).toStringAsFixed(2)}'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: falta.abs() < 0.01
                    ? AppColors.primaryGreen
                    : (falta > 0 ? const Color(0xFF2563EB) : AppColors.error),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _cambiarPropina(String texto) {
    establecerPropinaPedido(widget.pedido.id, leerMonto(texto));
  }

  void _alternarPropina(bool v) {
    setState(() {
      _conPropina = v;
      if (!v) {
        _propinaCtrl.clear();
        establecerPropinaPedido(widget.pedido.id, 0);
      }
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

  Widget _columnaPropina() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _subtitulo('Propina')),
            AppSwitch(value: _conPropina, onChanged: _alternarPropina),
          ],
        ),
        if (_conPropina) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _campoSoles(_propinaCtrl, onChanged: _cambiarPropina),
              ),
              const SizedBox(width: 8),
              BotonCerrarCircular(
                tamano: 30,
                onPressed: () => _alternarPropina(false),
              ),
            ],
          ),
        ],
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
        _columnaPropina(),
        const SizedBox(height: 14),
        _columnaRoturas(),
      ],
    );
  }

  // Lo que queda fijo abajo: tipo de comprobante y botón Pagar.
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
        Row(
          children: [
            if (widget.permiteVolver) ...[
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _volver,
                  icon: const Icon(LucideIcons.chevronLeft, size: 16),
                  label: const Text('Regresar'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed:
                    saldo > 0.01 &&
                        !_guardando &&
                        (_dividir ? _repartoValido : _saldo > 0.005) &&
                        _recibidoValido &&
                        (_comprobante?.completo ?? true)
                    ? _pagar
                    : null,
                icon: const Icon(LucideIcons.banknote, size: 18),
                label: Text(
                  (_dividir && !_repartoCompleto)
                      ? 'Pagar abono · S/ ${total.toStringAsFixed(2)}'
                      : 'Pagar · S/ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(backgroundColor: naranjaPago),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final saldo = _saldo;
    final propina = _propina;
    final taper = _taper;
    final cargos = _totalCargos;
    final montoBase = _dividir ? _asignado : _montoCobroUnico;
    final total = montoBase + _recargo + propina + taper + cargos;
    return ModalPago(
      titulo: 'Pagar',
      anchoEscritorio:
          _comprobante != null && _comprobante!.tipo != 'ticket_venta'
          ? 600
          : 540,
      subtitulo: 'Pedido #${widget.pedido.numeroPedido} · ${widget.titulo}',
      onVolver: widget.permiteVolver ? _volver : null,
      pie: _pieFijo(saldo, total),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Total a pagar: texto grande, sin tarjeta.
          Text(
            'Total a pagar',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            'S/ ${(total).toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          _titulo('Método de pago'),
          if (!_dividir)
            Builder(
              builder: (context) {
                final grupos = agruparMediosPago(mediosPagoActivos);
                // Con un solo grupo no hace falta el título; con varios, el
                // tipo va primero y dentro de él cada medio (cada Yape).
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in grupos.entries) ...[
                      if (grupos.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 6),
                          child: Text(
                            etiquetaGrupoMedioPago(e.key),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      Wrap(
                        runSpacing: 8,
                        children: [for (final m in e.value) _etiquetaMedio(m)],
                      ),
                    ],
                  ],
                );
              },
            ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          // Campo permanente: sin interruptor y siempre a la vista.
          ...[
            _subtitulo('Vuelto'),
            const SizedBox(height: 8),
            _campoSoles(_recibidoCtrl, hint: 'S/. con cuánto paga el cliente'),
            if (!_recibidoValido)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Falta: el efectivo a cobrar es '
                  'S/ ${_efectivoACobrar.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ),
            if (_vuelto > 0.005)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _filaMonto('Vuelto', _vuelto, fuerte: true),
              ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
          ],
          _conInterruptor('Por montos', _dividir, _alternarDividir),
          if (_dividir) ...[const SizedBox(height: 8), _filasDeMedios()],
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
