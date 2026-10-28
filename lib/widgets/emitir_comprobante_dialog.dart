import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/configuracion_store.dart';
import '../utils/datos_sede.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/comprobante.dart';
import '../models/pedido.dart';
import '../services/api_client.dart';
import '../services/facturacion_service.dart';
import '../services/pago_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../utils/monto_letras.dart';
import 'app_toast.dart';
import 'comprobante_en_cobro.dart';
import 'dialogo_app.dart';

typedef EmisionHecha = ({Comprobante comprobante, bool imprimirDespues});

class EmitirComprobanteDialog extends StatefulWidget {
  final Pedido pedido;

  const EmitirComprobanteDialog({super.key, required this.pedido});

  @override
  State<EmitirComprobanteDialog> createState() =>
      _EmitirComprobanteDialogState();
}

class _EmitirComprobanteDialogState extends State<EmitirComprobanteDialog> {
  late final ComprobanteEnCobro _eleccion =
      ComprobanteEnCobro(
        totalDePedido(widget.pedido.id),
        tipoInicial: 'ticket_venta',
      )..addListener(() {
        if (mounted) setState(() {});
      });

  bool _emitiendo = false;
  String? _error;
  int _tabIndex = 0; // 0: Formulario, 1: Vista Previa Fiscal en Vivo

  List<Comprobante> _comprobantes = [];
  bool _cargandoComprobantes = true;

  @override
  void initState() {
    super.initState();
    _cargarComprobantes();
  }

  Future<void> _cargarComprobantes() async {
    setState(() => _cargandoComprobantes = true);
    try {
      final lista = await FacturacionService.instance.listar(
        pedidoId: widget.pedido.id,
      );
      if (mounted) {
        setState(() {
          _comprobantes = lista;
          _cargandoComprobantes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoComprobantes = false);
    }
  }

  Comprobante? get _comprobanteFiscalActivo => _comprobantes
      .where((c) => c.esFiscal && c.estadoSunat != 'ANULADO')
      .firstOrNull;

  Comprobante? get _ticketVentaActivo => _comprobantes
      .where(
        (c) => c.tipoDocumento == 'ticket_venta' && c.estadoSunat != 'ANULADO',
      )
      .firstOrNull;

  @override
  void dispose() {
    _eleccion.dispose();
    super.dispose();
  }

  bool get _tieneCobro =>
      pagos.any((p) => p.pedidoId == widget.pedido.id && !p.esReembolso);
  bool get _bloqueadoPorCobro =>
      _eleccion.tipo != 'ticket_venta' && !_tieneCobro;

  bool get _bloqueadoPorFiscalExistente =>
      _eleccion.tipo != 'ticket_venta' && _comprobanteFiscalActivo != null;

  bool get _puedeEmitir =>
      !_emitiendo &&
      !_bloqueadoPorCobro &&
      !_bloqueadoPorFiscalExistente &&
      _eleccion.completo;

  Future<void> _emitir() async {
    if (!_puedeEmitir) return;
    setState(() {
      _emitiendo = true;
      _error = null;
    });
    try {
      final c = await _eleccion.emitir(widget.pedido);
      if (mounted) {
        Navigator.of(context).pop<EmisionHecha>((
          comprobante: c,
          imprimirDespues: _eleccion.imprimirDespues,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _emitiendo = false;
        _error = e is ApiException
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _reimprimir(Comprobante c) async {
    try {
      await FacturacionService.instance.reimprimir(c.id);
      if (mounted) {
        showAppToast(
          context,
          '${c.tipoEtiqueta} ${c.numeroComprobante} enviada a la ticketera de caja.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'No se pudo reimprimir: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _abrirDialogoAnulacion(Comprobante c) async {
    final anulado = await showBlurDialog<bool>(
      context: context,
      builder: (_) => _AnularComprobanteDialog(comprobante: c),
    );
    if (anulado == true) {
      await _cargarComprobantes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fiscal = _comprobanteFiscalActivo;
    final ticket = _ticketVentaActivo;

    return DialogoApp(
      titulo: 'Emitir comprobante · Pedido #${widget.pedido.numeroPedido}',
      ancho: 520,
      acciones: [
        OutlinedButton(
          onPressed: _emitiendo ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _puedeEmitir ? _emitir : null,
          child: _emitiendo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _eleccion.tipo == 'ticket_venta'
                      ? 'Emitir ticket de venta'
                      : 'Emitir comprobante',
                ),
        ),
      ],
      children: [
        if (_cargandoComprobantes) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 10),
        ],
        // 1. Alerta si ya existe un comprobante fiscal emitido
        if (fiscal != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.fileCheck2,
                      size: 18,
                      color: Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Comprobante emitido: ${fiscal.tipoEtiqueta.toUpperCase()} ${fiscal.numeroComprobante}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: fiscal.estadoSunat == 'ACEPTADO'
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        fiscal.estadoSunat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: fiscal.estadoSunat == 'ACEPTADO'
                              ? Colors.green.shade800
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Cliente: ${fiscal.clienteDenominacion.isEmpty ? "CLIENTES VARIOS" : fiscal.clienteDenominacion} · Total: S/ ${fiscal.total.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _reimprimir(fiscal),
                      icon: const Icon(LucideIcons.printer, size: 15),
                      label: Text('Reimprimir ${fiscal.tipoEtiqueta}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _abrirDialogoAnulacion(fiscal),
                      icon: const Icon(
                        LucideIcons.ban,
                        size: 15,
                        color: AppColors.error,
                      ),
                      label: const Text(
                        'Anular comprobante',
                        style: TextStyle(color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 2. Si ya hay un ticket de venta interno emitido
        if (ticket != null && fiscal == null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.receipt,
                  size: 16,
                  color: Colors.blue.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ticket emitido: ${ticket.numeroComprobante}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _reimprimir(ticket),
                  icon: const Icon(LucideIcons.printer, size: 14),
                  label: const Text('Reimprimir Ticket'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Pestañas: Formulario vs Vista Previa Fiscal en Vivo
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(LucideIcons.settings2, size: 15),
              label: Text('Opciones'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(LucideIcons.eye, size: 15),
              label: Text('Vista previa en vivo'),
            ),
          ],
          selected: {_tabIndex},
          onSelectionChanged: (s) => setState(() => _tabIndex = s.first),
        ),
        const SizedBox(height: 14),

        if (_tabIndex == 0) ...[
          Text(
            'Total del pedido: S/ ${_eleccion.total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SelectorComprobante(control: _eleccion, pedido: widget.pedido),
          if (_bloqueadoPorCobro)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Para emitir una boleta o factura el pedido debe tener un cobro '
                'registrado. Cóbralo primero, o emite un ticket de venta.',
                style: TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
          if (_bloqueadoPorFiscalExistente)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'El pedido ya cuenta con ${fiscal!.tipoEtiqueta} activa (${fiscal.numeroComprobante}). '
                'Para emitir uno nuevo, primero debes anular el actual arriba. '
                '(El ticket de venta sí se puede emitir o reimprimir sin anular).',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
        ] else ...[
          // Vista previa en vivo del comprobante fiscal
          _VistaPreviaComprobanteFiscal(
            pedido: widget.pedido,
            control: _eleccion,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// WIDGET DE VISTA PREVIA FISCAL EN VIVO (ESTILO TICKET TÉRMICO)
// ---------------------------------------------------------------------------
class _VistaPreviaComprobanteFiscal extends StatelessWidget {
  final Pedido pedido;
  final ComprobanteEnCobro control;

  const _VistaPreviaComprobanteFiscal({
    required this.pedido,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
    final sede = datosDeLaSede();
    final recargo = recargoCobradoDePedido(pedido.id);
    final delivery = pedido.costoDelivery;
    final lineas = detallesPorPedido[pedido.id] ?? const [];

    // Calcular montos en base a opciones activas
    final baseLineas = lineas.fold(
      0.0,
      (s, l) => s + l.precioTotalLinea + l.descuentoAplicado,
    );
    final descLineas = lineas.fold(0.0, (s, l) => s + l.descuentoAplicado);
    final subtotalPlatos = baseLineas - descLineas;

    double totalCalc = subtotalPlatos;
    if (control.incluirRecargo && recargo > 0) totalCalc += recargo;
    if (control.incluirDelivery && delivery > 0) totalCalc += delivery;

    final igv = (totalCalc * (18.0 / 118.0));
    final opGravada = totalCalc - igv;

    final tituloDoc = switch (control.tipo) {
      'factura' => 'FACTURA ELECTRÓNICA',
      'boleta' => 'BOLETA DE VENTA ELECTRÓNICA',
      _ => 'TICKET DE VENTA',
    };

    final serieEstimada = switch (control.tipo) {
      'factura' => 'FA01-0000000X',
      'boleta' => 'BA01-0000000X',
      _ => 'T001-0000000X',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'VISTA PREVIA DE IMPRESIÓN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.grey,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Papel 80mm',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.black87,
                height: 1.25,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    negocio.nombre.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'RUC: ${sede.ruc.isNotEmpty ? sede.ruc : "20608543211"}',
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    sede.direccion.isNotEmpty
                        ? sede.direccion
                        : 'CAL. LOS BRILLANTES 421B',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tituloDoc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    serieEstimada,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(thickness: 1, height: 14),
                  Text(
                    'Fecha/Hora: ${DateTime.now().toString().substring(0, 19)}',
                  ),
                  if (control.tipo == 'factura') ...[
                    Text(
                      'RUC: ${control.ruc.text.isEmpty ? "—" : control.ruc.text}',
                    ),
                    Text(
                      'Razón Social: ${control.razon.text.isEmpty ? "—" : control.razon.text}',
                    ),
                    Text(
                      'Dirección: ${control.direccion.text.isEmpty ? "—" : control.direccion.text}',
                    ),
                  ] else if (control.tipo == 'boleta') ...[
                    Text(
                      'DNI: ${control.conDni && control.dni.text.isNotEmpty ? control.dni.text : "—"}',
                    ),
                    Text(
                      'Cliente: ${control.conDni ? (control.nombre.text.trim().isNotEmpty ? control.nombre.text : (control.dni.text.trim().isEmpty ? "CLIENTES VARIOS" : (control.buscando ? "buscando en RENIEC…" : "(falta el nombre del cliente)"))) : "CLIENTES VARIOS"}',
                    ),
                  ] else ...[
                    Text(
                      'Cliente: ${pedido.clienteNombre ?? "CLIENTES VARIOS"}',
                    ),
                  ],
                  Text('Moneda: SOLES (S/)'),
                  const Divider(thickness: 1, height: 14),

                  // Detalle de ítems
                  if (control.soloConsumo) ...[
                    _filaItem('1 NIU', 'Por consumo', totalCalc),
                  ] else ...[
                    for (final l in lineas.where((x) => esLineaDeProducto(x) || esLineaTupper(x) || esLineaTaper(x)))
                      _filaItem(
                        '${l.cantidad} NIU',
                        l.esLibre
                            ? (l.nombreLibre ?? l.nombrePlato)
                            : l.nombrePlato,
                        l.precioTotalLinea,
                      ),
                    if (control.incluirRecargo && recargo > 0)
                      _filaItem(
                        '1 NIU',
                        'Recargo por pago con tarjeta',
                        recargo,
                      ),
                    if (control.incluirDelivery && delivery > 0)
                      _filaItem('1 NIU', 'Servicio de Delivery', delivery),
                  ],

                  const Divider(thickness: 1, height: 14),
                  if (control.tipo != 'ticket_venta') ...[
                    _filaTotal('OP. GRAVADA:', opGravada),
                    _filaTotal('I.G.V. (18%):', igv),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'IMPORTE TOTAL:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'S/ ${totalCalc.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SON: ${montoEnLetras(totalCalc)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Divider(thickness: 1, height: 14),
                  const Text(
                    'Representación impresa del comprobante electrónico',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const Text(
                    'Consulte su documento en: https://apisunat.pe',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaItem(String cant, String desc, double subtotal) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 44, child: Text(cant)),
        Expanded(child: Text(desc)),
        Text('S/ ${subtotal.toStringAsFixed(2)}'),
      ],
    ),
  );

  Widget _filaTotal(String label, double val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text('S/ ${val.toStringAsFixed(2)}')],
    ),
  );
}

// ---------------------------------------------------------------------------
// MODAL DE ANULACIÓN CON DOBLE FACTOR Y CONFIRMACIÓN CONSCIENTE
// ---------------------------------------------------------------------------
class _AnularComprobanteDialog extends StatefulWidget {
  final Comprobante comprobante;

  const _AnularComprobanteDialog({required this.comprobante});

  @override
  State<_AnularComprobanteDialog> createState() =>
      _AnularComprobanteDialogState();
}

class _AnularComprobanteDialogState extends State<_AnularComprobanteDialog> {
  final _motivoController = TextEditingController(
    text: 'Error en emisión / cambio de comprobante',
  );
  bool _confirmadoDobleFactor = false;
  bool _anulando = false;
  String? _error;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _anular() async {
    final motivo = _motivoController.text.trim();
    if (motivo.isEmpty || !_confirmadoDobleFactor || _anulando) return;

    setState(() {
      _anulando = true;
      _error = null;
    });

    try {
      await FacturacionService.instance.anular(
        widget.comprobante.id,
        motivo: motivo,
      );
      if (mounted) {
        showAppToast(
          context,
          'Comprobante ${widget.comprobante.numeroComprobante} anulado ante SUNAT exitosamente.',
          type: ToastType.success,
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _anulando = false;
          _error = e is ApiException
              ? e.message
              : e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comprobante;

    return DialogoApp(
      titulo: 'Anular ${c.tipoEtiqueta} ante SUNAT',
      ancho: 480,
      acciones: [
        OutlinedButton(
          onPressed: _anulando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed:
              (_confirmadoDobleFactor &&
                  _motivoController.text.trim().isNotEmpty &&
                  !_anulando)
              ? _anular
              : null,
          icon: _anulando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(LucideIcons.ban, size: 16),
          label: const Text('Confirmar anulación ante SUNAT'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
        ),
      ],
      children: [
        // Banner de advertencia explícita
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.alertTriangle,
                size: 22,
                color: Colors.red.shade700,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operación Fiscal Irreversible',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Estás a punto de anular la ${c.tipoEtiqueta.toUpperCase()} ${c.numeroComprobante} por S/ ${c.total.toStringAsFixed(2)}. '
                      'Esta acción comunicará la baja directamente a SUNAT y liberará el pedido para emitir un nuevo comprobante correcto.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Motivos rápidos
        const Text(
          'Motivo de anulación:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in [
              'Error en datos del cliente',
              'Cambio de boleta por factura',
              'Error en montos o platos',
              'Anulación de operación',
            ])
              ActionChip(
                label: Text(m, style: const TextStyle(fontSize: 11)),
                onPressed: () {
                  setState(() => _motivoController.text = m);
                },
              ),
          ],
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _motivoController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Descripción del motivo',
            hintText: 'Ingresa el motivo que se enviará a SUNAT',
          ),
        ),
        const SizedBox(height: 14),

        // Doble factor / Checkbox consciente
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _confirmadoDobleFactor,
                onChanged: (v) =>
                    setState(() => _confirmadoDobleFactor = v ?? false),
              ),
              const Expanded(
                child: Text(
                  'Entiendo que esta anulación se transmitirá formalmente a SUNAT y es irreversible.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}

// Flujo completo de emitir el comprobante de un pedido ya cobrado
Future<void> emitirComprobanteDePedido(BuildContext context, Pedido p) async {
  try {
    await PagoService.instance.cargarDePedido(p);
  } catch (_) {}
  if (!context.mounted) return;
  final hecha = await showBlurDialog<EmisionHecha>(
    context: context,
    builder: (_) => EmitirComprobanteDialog(pedido: p),
  );
  if (hecha == null || !context.mounted) return;
  await showBlurDialog<void>(
    context: context,
    builder: (_) => ComprobanteEmitidoDialog(
      comprobante: hecha.comprobante,
      pedido: p,
      imprimirAlConfirmar: hecha.imprimirDespues,
    ),
  );
}
