import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/configuracion_store.dart';
import '../data/movimientos_caja_store.dart';
import '../data/pagos_store.dart';
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

  const ModalPago({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.anchoEscritorio = 440,
    this.onVolver,
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
              Flexible(child: SingleChildScrollView(child: child)),
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
  late MedioPago _medio = mediosPagoActivos.first;
  // Comprobante a emitir al cobrar (solo administración y caja lo eligen).
  ComprobanteEnCobro? _comprobante;
  // La misma persona puede pagar con varios medios y montos (por ejemplo, una
  // parte en efectivo y el resto en Yape). Con esto activado, el pago se reparte
  // en las filas de [_filas].
  bool _dividir = false;
  final List<_FilaMedio> _filas = [];
  // Efectivo con el que paga el cliente (para calcular el vuelto).
  final _recibidoCtrl = TextEditingController();

  // Lo que se cobra en efectivo: sin recargo, y con la propina y el táper.
  double get _efectivoACobrar {
    final enEfectivo = _dividir
        ? _filas
              .where((f) => f.medio.grupo == 'efectivo')
              .fold(0.0, (s, f) => s + leerMonto(f.monto.text))
        : (_medio.grupo == 'efectivo' ? _saldo : 0.0);
    return enEfectivo > 0.005 ? enEfectivo + _propina + _taper : 0.0;
  }

  double get _recibido => leerMonto(_recibidoCtrl.text);
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
    for (final f in _filas) {
      f.monto.dispose();
    }
    super.dispose();
  }

  // Suma de lo asignado a las cuentas en las filas.
  double get _asignado =>
      _filas.fold(0.0, (s, f) => s + leerMonto(f.monto.text));
  double get _faltante => _saldo - _asignado;
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
  // Propina y táper: el cliente los paga además de la cuenta, sin recargo.
  double get _propina => propinaPendienteDePedido(widget.pedido.id);
  double get _taper => taperPendienteDePedido(widget.pedido.id);
  // Recargo del método elegido (p. ej. tarjeta): se suma al total del cliente.
  double get _recargo => _dividir
      ? _filas.fold(
          0.0,
          (s, f) => s + f.medio.recargoSobre(leerMonto(f.monto.text)),
        )
      : _medio.recargoSobre(_saldo);

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
    }
    _categoriaSeleccionada =
        _categoriasIngreso
            .where((c) => c.nombre.toLowerCase().contains('venta'))
            .firstOrNull ??
        _categoriasIngreso.firstOrNull;
    if (mediosPago.isEmpty) {
      CatalogService.instance
          .cargarMediosPago()
          .then((_) {
            if (mounted) setState(() => _medio = mediosPagoActivos.first);
          })
          .catchError((_) {});
    }
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
    if (_dividir && !_repartoCompleto) return;
    final recargo = _recargo;
    final extras = _propina + _taper;
    // Lo que se cobra: un pago con el medio elegido o uno por cada fila.
    final cobros = _dividir
        ? [
            for (final f in _filas)
              (medio: f.medio, monto: leerMonto(f.monto.text)),
          ]
        : [(medio: _medio, monto: saldo)];
    setState(() => _guardando = true);
    var registrados = 0;
    try {
      // Se registra en el servidor; si lo rechaza, no queda nada cobrado.
      for (final c in cobros) {
        if (c.monto <= 0.005) continue;
        final esEfectivo = c.medio.grupo == 'efectivo' || c.medio.medioPago.toLowerCase().contains('efectivo');
        await PagoService.instance.registrar(
          pedido: widget.pedido,
          medio: c.medio,
          montoAbonado: c.monto,
          categoriaMovimientoId: _categoriaSeleccionada?.id,
          montoRecibido: esEfectivo && _recibido > 0.005 ? _recibido : null,
          vuelto: esEfectivo && _vuelto > 0.005 ? _vuelto : null,
        );
        registrados++;
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
    // El cobro ya está guardado: ahora se emite el comprobante elegido.
    final eleccion = _comprobante;
    if (eleccion != null) {
      await emitirComprobanteTrasCobro(context, widget.pedido, eleccion);
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

  Widget _tileMedio(MedioPago m, double ancho) {
    final activo = m.id == _medio.id;
    return SizedBox(
      width: ancho,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _medio = m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            color: activo
                ? AppColors.primaryGreen.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
              width: activo ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _icono(m),
                size: 20,
                color: activo
                    ? AppColors.primaryGreenDark
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.medioPago,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: activo ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    if (m.aplicaComision)
                      Text(
                        '+${m.porcentajeComision.toStringAsFixed(1)}% recargo',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              if (activo)
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Una fila por medio: el medio, cuánto de la cuenta paga con él y quitar.
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
                    value: _filas[i].medio.id,
                    hint: 'Medio',
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
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: AppSizes.boton,
                    child: CampoTexto(
                      controller: _filas[i].monto,
                      expands: true,
                      maxLines: null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(prefixText: 'S/ '),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar medio',
                  onPressed: _filas.length > 1 ? () => _quitarFila(i) : null,
                  icon: const Icon(LucideIcons.x, size: 18),
                ),
              ],
            ),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: _agregarFila,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Agregar otro medio'),
            ),
            const Spacer(),
            Text(
              falta.abs() < 0.01
                  ? 'Cuenta completa'
                  : (falta > 0
                        ? 'Falta S/ ${falta.toStringAsFixed(2)}'
                        : 'Sobra S/ ${(-falta).toStringAsFixed(2)}'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: falta.abs() < 0.01
                    ? AppColors.primaryGreen
                    : AppColors.error,
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
    final total = saldo + _recargo + propina + taper;
    return ModalPago(
      titulo: 'Pago único',
      subtitulo: 'Pedido #${widget.pedido.numeroPedido} · ${widget.titulo}',
      onVolver: widget.permiteVolver ? _volver : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tarjetaSaldo('Total a pagar', saldo + propina + taper),
          const SizedBox(height: 14),
          AppSelect<CategoriaMovimiento>(
            label: 'Concepto / Categoría del cobro',
            flotante: true,
            buscable: true,
            value: _categoriaSeleccionada,
            hint: 'Selecciona concepto de ingreso',
            items: [
              for (final c in categoriasDeTipo(TipoMovimiento.ingreso))
                AppSelectItem(value: c, label: c.nombre),
            ],
            onChanged: (c) => setState(() => _categoriaSeleccionada = c),
          ),
          const SizedBox(height: 14),
          const Text(
            'Método de pago',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (!_dividir)
            LayoutBuilder(
              builder: (context, c) {
                final ancho = (c.maxWidth - 10) / 2;
                final grupos = agruparMediosPago(mediosPagoActivos);
                // Con un solo grupo no hace falta el título; con varios, el
                // tipo va primero y dentro de él cada medio (cada Yape).
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in grupos.entries) ...[
                      if (grupos.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 6),
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
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final m in e.value) _tileMedio(m, ancho),
                        ],
                      ),
                    ],
                  ],
                );
              },
            )
          else
            _filasDeMedios(),
          const SizedBox(height: 10),
          // La misma persona paga con varios medios y montos.
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pagar con varios medios (montos distintos)',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              AppSwitch(value: _dividir, onChanged: _alternarDividir),
            ],
          ),
          if (_efectivoACobrar > 0.005) ...[
            const SizedBox(height: 14),
            CampoTexto(
              controller: _recibidoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'El cliente paga en efectivo con (S/) · opcional, para el vuelto',
                errorText: _recibidoValido
                    ? null
                    : 'Falta: el efectivo a cobrar es '
                          'S/ ${_efectivoACobrar.toStringAsFixed(2)}',
              ),
            ),
            if (_vuelto > 0.005)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _filaMonto('Vuelto', _vuelto, fuerte: true),
              ),
          ],
          if (_comprobante != null) ...[
            const SizedBox(height: 18),
            SelectorComprobante(
              control: _comprobante!,
              pedido: widget.pedido,
            ),
          ],
          if (_recargo > 0 || propina > 0 || taper > 0)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.naranja.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _filaMonto('Cuenta', saldo),
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
                  const Divider(height: 14),
                  _filaMonto('Total a cobrar', total, fuerte: true),
                ],
              ),
            ),
          const SizedBox(height: 20),
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
                          (!_dividir || _repartoCompleto) &&
                          _recibidoValido &&
                          (_comprobante?.completo ?? true)
                      ? _pagar
                      : null,
                  icon: const Icon(LucideIcons.banknote, size: 18),
                  label: Text(
                    'Pagar · S/ ${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: naranjaPago),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
