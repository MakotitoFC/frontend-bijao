import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/mesas_store.dart';
import '../utils/datos_sede.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/comprobante.dart';
import '../models/pedido.dart';
import '../services/api_client.dart';
import '../services/facturacion_service.dart';
import '../services/pago_service.dart';
import '../services/pedido_mozo_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../utils/monto_letras.dart';
import '../utils/abrir_enlace.dart';
import '../utils/whatsapp_cuenta.dart';
import 'app_toast.dart';
import 'comprobante_en_cobro.dart';
import 'dialogo_app.dart';
import 'whatsapp_cuenta_dialog.dart';

typedef EmisionHecha = ({Comprobante comprobante, bool imprimirDespues});

class EmitirComprobanteDialog extends StatefulWidget {
  final Pedido pedido;

  const EmitirComprobanteDialog({super.key, required this.pedido});

  @override
  State<EmitirComprobanteDialog> createState() =>
      _EmitirComprobanteDialogState();
}

class _EmitirComprobanteDialogState extends State<EmitirComprobanteDialog> {
  late final ComprobanteEnCobro _eleccion = ComprobanteEnCobro(
    totalDePedido(widget.pedido.id),
    tipoInicial: 'ticket_venta',
  );

  bool _emitiendo = false;
  String? _error;
  int _tabIndex = 0; // 0: Formulario e Ítems, 1: Vista Previa Fiscal en Vivo

  List<Comprobante> _comprobantes = [];
  bool _cargandoComprobantes = true;

  @override
  void initState() {
    super.initState();
    _eleccion.addListener(() {
      if (mounted) setState(() {});
    });
    _cargarComprobantes();
    _eleccion.asegurarInicializado(widget.pedido);
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
      .where((c) => c.esFiscal && c.estadoSunat != 'ANULADO' && c.estadoSunat != 'RECHAZADO')
      .firstOrNull;

  Comprobante? get _comprobanteRechazado => _comprobantes
      .where((c) => c.esFiscal && c.estadoSunat == 'RECHAZADO')
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
      _eleccion.tipo != 'ticket_venta' &&
      _comprobanteFiscalActivo != null &&
      _comprobanteFiscalActivo!.estadoSunat != 'ERROR_CONEXION';

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

  Future<void> _reintentarEnvio(Comprobante c) async {
    setState(() {
      _emitiendo = true;
      _error = null;
    });
    try {
      final res = await FacturacionService.instance.reintentar(c.id);
      if (mounted) {
        showAppToast(
          context,
          'Comprobante ${res.numeroComprobante} reintentado exitosamente (${res.estadoSunat})',
          type: ToastType.success,
        );
        await _cargarComprobantes();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _emitiendo = false);
    }
  }

  Future<void> _consultarEstado(Comprobante c) async {
    setState(() {
      _emitiendo = true;
      _error = null;
    });
    try {
      final res = await FacturacionService.instance.consultarEstado(c.id);
      if (mounted) {
        showAppToast(
          context,
          'Estado SUNAT: ${res.estadoSunat} - ${res.mensaje ?? ""}',
          type: ToastType.info,
        );
        await _cargarComprobantes();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _emitiendo = false);
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

  Future<void> _whatsapp(Comprobante c) async {
    final urlTicket = c.urlPublicaTicket;
    final urlA4 = c.urlPublicaA4;
    final urlXml = c.urlPublicaXml;
    if (urlTicket == null && urlA4 == null && urlXml == null) return;

    final numero = await showBlurDialog<String>(
      context: context,
      builder: (_) =>
          WhatsappCuentaDialog(celularInicial: widget.pedido.clienteCelular),
    );
    if (numero == null || !mounted) return;

    // Con el nombre del cliente: el del pedido o, si no, el del comprobante.
    final nombreCliente = nombreClienteWhatsapp(
      widget.pedido.clienteNombre,
      c.clienteDenominacion,
    );
    final negocio = nombreDelNegocio().isEmpty ? 'nuestro restaurante' : nombreDelNegocio();
    final buf = StringBuffer()
      ..writeln('Hola${nombreCliente.isEmpty ? '' : ' $nombreCliente'}, te enviamos tu ${c.tipoEtiqueta.toLowerCase()} ${c.numeroComprobante} de $negocio.')
      ..writeln('Total: S/ ${c.total.toStringAsFixed(2)}')
      ..writeln();

    if (urlA4 != null) {
      buf.writeln('📄 PDF A4: $urlA4');
    }
    if (urlTicket != null) {
      buf.writeln('🧾 PDF Ticket: $urlTicket');
    }
    if (urlXml != null) {
      buf.writeln('📦 XML: $urlXml');
    }

    final abierto = await abrirWhatsapp(numero, buf.toString().trim());
    if (!abierto && mounted) {
      showAppToast(
        context,
        'No se pudo abrir WhatsApp.',
        type: ToastType.error,
      );
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
    final rechazado = _comprobanteRechazado;

    return DialogoApp(
      titulo: 'Emitir comprobante · Pedido #${widget.pedido.numeroPedido}',
      ancho: 680,
      acciones: [
        OutlinedButton(
          onPressed: _emitiendo ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        Tooltip(
          message: _eleccion.motivoBloqueo ?? '',
          triggerMode: TooltipTriggerMode.tap,
          child: FilledButton(
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
              color: fiscal.estadoSunat == 'ERROR_CONEXION'
                  ? Colors.red.shade50
                  : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: fiscal.estadoSunat == 'ERROR_CONEXION'
                    ? Colors.red.shade300
                    : Colors.amber.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      fiscal.estadoSunat == 'ERROR_CONEXION'
                          ? LucideIcons.alertTriangle
                          : LucideIcons.fileCheck2,
                      size: 18,
                      color: fiscal.estadoSunat == 'ERROR_CONEXION'
                          ? Colors.red.shade900
                          : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Comprobante emitido: ${fiscal.tipoEtiqueta.toUpperCase()} ${fiscal.numeroComprobante}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: fiscal.estadoSunat == 'ERROR_CONEXION'
                              ? Colors.red.shade900
                              : Colors.amber.shade900,
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
                            : (fiscal.estadoSunat == 'ERROR_CONEXION'
                                  ? Colors.red.shade100
                                  : Colors.orange.shade100),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        fiscal.estadoSunat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: fiscal.estadoSunat == 'ACEPTADO'
                              ? Colors.green.shade800
                              : (fiscal.estadoSunat == 'ERROR_CONEXION'
                                    ? Colors.red.shade900
                                    : Colors.orange.shade900),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (fiscal.estadoSunat == 'ERROR_CONEXION') ...[
                  Text(
                    '⚠️ Hubo un corte de red o timeout esperando respuesta de SUNAT. '
                    'Para evitar saltos de correlativo, consulta el estado o reintenta el envío con el mismo número.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Cliente: ${fiscal.clienteDenominacion.isEmpty ? "CLIENTES VARIOS" : fiscal.clienteDenominacion} · Total: S/ ${fiscal.total.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (fiscal.estadoSunat == 'ERROR_CONEXION') ...[
                      FilledButton.icon(
                        onPressed: _emitiendo
                            ? null
                            : () => _reintentarEnvio(fiscal),
                        icon: const Icon(LucideIcons.refreshCw, size: 15),
                        label: const Text('Reintentar Envío a SUNAT'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _emitiendo
                            ? null
                            : () => _consultarEstado(fiscal),
                        icon: const Icon(LucideIcons.search, size: 15),
                        label: const Text('Consultar Estado'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                    if (fiscal.ticketUrl != null)
                      OutlinedButton.icon(
                        onPressed: () => abrirEnlace(fiscal.ticketUrl!),
                        icon: const Icon(LucideIcons.fileText, size: 15),
                        label: const Text('PDF ticket'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    if (fiscal.a4Url != null)
                      OutlinedButton.icon(
                        onPressed: () => abrirEnlace(fiscal.a4Url!),
                        icon: const Icon(LucideIcons.fileText, size: 15),
                        label: const Text('PDF A4'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    if (fiscal.xmlDescargaUrl != null)
                      OutlinedButton.icon(
                        onPressed: () => abrirEnlace(fiscal.xmlDescargaUrl!),
                        icon: const Icon(LucideIcons.code, size: 15),
                        label: const Text('XML'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
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
                    if (fiscal.ticketUrl != null || fiscal.a4Url != null || fiscal.xmlDescargaUrl != null)
                      FilledButton.icon(
                        onPressed: () => _whatsapp(fiscal),
                        icon: const Icon(LucideIcons.messageCircle, size: 15),
                        label: const Text('WhatsApp'),
                        style: estiloBotonWhatsapp.copyWith(
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
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

        // 1.5. Aviso si el comprobante anterior fue rechazado por SUNAT
        if (rechazado != null && fiscal == null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.xCircle,
                  size: 18,
                  color: Colors.red.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comprobante anterior rechazado por SUNAT: ${rechazado.tipoEtiqueta.toUpperCase()} ${rechazado.numeroComprobante}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rechazado.mensaje?.isNotEmpty == true
                            ? rechazado.mensaje!
                            : 'Rechazado por validación SUNAT',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.red.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Puedes corregir los datos o ítems y emitir un nuevo comprobante.',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
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
            itemsEditables: _eleccion.itemsEditables,
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
  final List<ItemFacturacionEditable>? itemsEditables;

  const _VistaPreviaComprobanteFiscal({
    required this.pedido,
    required this.control,
    this.itemsEditables,
  });

  @override
  Widget build(BuildContext context) {
    final sede = datosDeLaSede();
    final recargo = recargoCobradoDePedido(pedido.id);
    final delivery = pedido.costoDelivery;
    final lineas = detallesPorPedido[pedido.id] ?? const [];
    final horaAtencion =
        '${pedido.fechaPedido.hour.toString().padLeft(2, '0')}:${pedido.fechaPedido.minute.toString().padLeft(2, '0')}:${pedido.fechaPedido.second.toString().padLeft(2, '0')}';
    final mesaObj = mesas
        .where((m) => m.numero == pedido.mesaNumero)
        .firstOrNull;
    final zonaStr = (mesaObj != null && mesaObj.zona.trim().isNotEmpty)
        ? mesaObj.zona.trim().toUpperCase()
        : 'SALÓN';

    // Los productos y tápers reales (sin la línea virtual de delivery)
    final productos = lineas
        .where(
          (x) => esLineaDeProducto(x) || esLineaTupper(x) || esLineaTaper(x),
        )
        .toList();
    final subtotalProductos = productos.fold(
      0.0,
      (s, l) => s + l.precioTotalLinea,
    );
    final cargoDelivery = delivery > 0 ? delivery : pedido.costoDelivery;
    final conDelivery =
        (control.tipo == 'ticket_venta' || control.incluirDelivery) &&
        cargoDelivery > 0;
    final conRecargo =
        (control.tipo == 'ticket_venta' || control.incluirRecargo) &&
        recargo > 0;

    final igvPorc =
        FacturacionService.instance.cachedConfig?.igvPorcentaje ?? 18.0;
    final igvLabel = (igvPorc % 1 == 0) ? '${igvPorc.toInt()}%' : '$igvPorc%';
    final serieCodigo =
        FacturacionService.instance.cachedConfig?.codigoSerie ?? '001';
    final serieSufijo = serieCodigo.padLeft(3, '0');
    final bool usaEditables =
        itemsEditables != null && itemsEditables!.isNotEmpty;

    double totalCalc;
    if (usaEditables) {
      totalCalc = itemsEditables!.fold(0.0, (s, it) => s + it.subtotal);
    } else {
      totalCalc = control.soloConsumo
          ? (subtotalProductos +
                (conDelivery ? cargoDelivery : 0) +
                (conRecargo ? recargo : 0))
          : subtotalProductos;
      if (!control.soloConsumo) {
        if (conDelivery) totalCalc += cargoDelivery;
        if (conRecargo) totalCalc += recargo;
      }
    }

    final igv = (totalCalc * (igvPorc / (100.0 + igvPorc)));
    final opGravada = totalCalc - igv;

    final tituloDoc = switch (control.tipo) {
      'factura' => 'FACTURA ELECTRÓNICA',
      'boleta' => 'BOLETA ELECTRÓNICA',
      _ => 'TICKET DE VENTA',
    };

    final serieEstimada = switch (control.tipo) {
      'factura' => 'F$serieSufijo-0000000X',
      'boleta' => 'B$serieSufijo-0000000X',
      _ => 'T$serieSufijo-0000000X',
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
                    sede.nombre.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('RUC: ${sede.ruc}', textAlign: TextAlign.center),
                  Text(sede.direccion, textAlign: TextAlign.center),
                  if (sede.telefono.isNotEmpty)
                    Text('Tel: ${sede.telefono}', textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  const Divider(thickness: 1, height: 10),
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
                    'Fecha:   ${DateTime.now().toString().substring(0, 10)} ${DateTime.now().toString().substring(11, 19)}',
                  ),
                  Text('Hora atención:   $horaAtencion'),
                  Text(
                    'Hora impresión:  ${DateTime.now().toString().substring(11, 19)}',
                  ),
                  if (pedido.tipoPedido == 'mesa' && pedido.mesaNumero > 0)
                    Text('Mesa:    ${pedido.mesaNumero} ($zonaStr)'),
                  if (pedido.mozoNombre != null &&
                      pedido.mozoNombre!.trim().isNotEmpty)
                    Text('Mozo:    ${pedido.mozoNombre!.trim()}'),
                  if (pedido.tipoPedido == 'delivery')
                    const Text('TIPO:    >> DELIVERY <<')
                  else if (pedido.tipoPedido == 'llevar')
                    const Text('TIPO:    >> PARA LLEVAR (RECOJO EN LOCAL) <<')
                  else if (pedido.tipoPedido == 'mesa')
                    const Text('TIPO:    MESA (CONSUMO EN SALON)'),
                  const Divider(thickness: 1, height: 14),
                  if (control.tipo == 'factura') ...[
                    Text(
                      'RUC:      ${control.ruc.text.isEmpty ? "—" : control.ruc.text}',
                    ),
                    Text(
                      'CLIENTE:  ${control.razon.text.isEmpty ? "—" : control.razon.text}',
                    ),
                    if (control.direccion.text.isNotEmpty)
                      Text('DIR:      ${control.direccion.text}'),
                  ] else if (control.tipo == 'boleta') ...[
                    if (control.conDni && control.dni.text.isNotEmpty)
                      Text('DNI:      ${control.dni.text}'),
                    Text(
                      'CLIENTE:  ${control.conDni ? (control.nombre.text.trim().isNotEmpty ? control.nombre.text : "CLIENTES VARIOS") : "CLIENTES VARIOS"}',
                    ),
                  ] else ...[
                    Text(
                      'CLIENTE:  ${pedido.clienteNombre ?? "CLIENTES VARIOS"}',
                    ),
                    if (pedido.direccionDelivery != null &&
                        pedido.direccionDelivery!.isNotEmpty)
                      Text('DIR:      ${pedido.direccionDelivery}'),
                  ],
                  const Text('MONEDA:   SOLES (S/)'),
                  const Divider(thickness: 1, height: 14),

                  // Detalle de ítems
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CANT DESCRIPCION',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'TOTAL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(thickness: 1, height: 10),
                  if (usaEditables) ...[
                    for (final it in itemsEditables!)
                      _filaItem(
                        '${it.cant} NIU',
                        it.nombre.text.trim().isEmpty
                            ? 'Plato'
                            : it.nombre.text.trim(),
                        it.subtotal,
                      ),
                  ] else if (control.soloConsumo) ...[
                    _filaItem('1 NIU', 'Por consumo', totalCalc),
                  ] else ...[
                    for (final l in productos)
                      _filaItem(
                        '${l.cantidad} NIU',
                        l.esLibre
                            ? (l.nombreLibre ?? l.nombrePlato)
                            : l.nombrePlato,
                        l.precioTotalLinea,
                      ),
                    if (conDelivery)
                      _filaItem('1 NIU', 'Servicio Delivery', cargoDelivery),
                    if (conRecargo)
                      _filaItem(
                        '1 NIU',
                        'Recargo por pago con tarjeta',
                        recargo,
                      ),
                  ],

                  const Divider(thickness: 1, height: 14),
                  if (control.tipo != 'ticket_venta') ...[
                    _filaTotal('OP. GRAVADA:', opGravada),
                    _filaTotal('I.G.V. ($igvLabel):', igv),
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

                  // Medios de pago y vuelto
                  if (pagosPorMedioDe(pedido.id) case final pagosLista
                      when pagosLista.isNotEmpty) ...[
                    const Divider(thickness: 1, height: 14),
                    const Text(
                      'MEDIO(S) DE PAGO:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final p in pagosLista)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('  - ${p.medio.toUpperCase()}:'),
                          Text('S/ ${p.monto.toStringAsFixed(2)}'),
                        ],
                      ),
                    if (efectivoRecibidoPorPedido[pedido.id] case final e?
                        when e.recibido > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('  EFECTIVO RECIBIDO:'),
                          Text('S/ ${e.recibido.toStringAsFixed(2)}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('  VUELTO:'),
                          Text('S/ ${e.vuelto.toStringAsFixed(2)}'),
                        ],
                      ),
                    ],
                  ],

                  const Divider(thickness: 1, height: 14),
                  if (control.tipo == 'ticket_venta') ...[
                    const Text(
                      'Documento interno no fiscal',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const Text(
                      '¡Gracias por su preferencia!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ] else ...[
                    Text(
                      'Representación impresa de la ${control.tipo == 'factura' ? 'FACTURA ELECTRÓNICA' : 'BOLETA ELECTRÓNICA'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const Text(
                      'Consulte su documento en: https://apisunat.pe',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const Text(
                      'Autorizado con Resolución N° 034-005-0005315/SUNAT',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
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
    if ((detallesPorPedido[p.id] ?? const []).isEmpty) {
      await PedidoMozoService.instance.obtener(p.id);
    }
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
