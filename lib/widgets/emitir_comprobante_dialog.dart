import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/configuracion_store.dart';
import '../data/pagos_store.dart';
import '../models/comprobante.dart';
import '../models/pedido.dart';
import '../services/api_client.dart';
import '../services/facturacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/abrir_enlace.dart';
import '../utils/blur_dialog.dart';
import '../utils/uuid_helper.dart';
import '../utils/whatsapp_cuenta.dart';
import 'app_switch.dart';
import 'app_tag.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';
import 'whatsapp_cuenta_dialog.dart';

// A partir de este total SUNAT exige los datos del cliente en una boleta.
const montoBoletaConDocumento = 700.0;

String _mensajeError(Object e) => e is ApiException
    ? e.message
    : e.toString().replaceFirst('Exception: ', '');

// Emite el comprobante de un pedido: Ticket de venta (interno, sin SUNAT),
// Boleta (con o sin DNI) o Factura (con RUC). Al emitir muestra el resultado
// con los PDF y las opciones de reimprimir y mandar por WhatsApp.
class EmitirComprobanteDialog extends StatefulWidget {
  final Pedido pedido;

  const EmitirComprobanteDialog({super.key, required this.pedido});

  @override
  State<EmitirComprobanteDialog> createState() =>
      _EmitirComprobanteDialogState();
}

class _EmitirComprobanteDialogState extends State<EmitirComprobanteDialog> {
  String _tipo = 'ticket_venta';
  bool _conDni = false;
  bool _imprimir = true;
  final _ruc = TextEditingController();
  final _razon = TextEditingController();
  final _direccion = TextEditingController();
  final _dni = TextEditingController();
  final _nombre = TextEditingController();

  bool _buscando = false;
  bool _emitiendo = false;
  RucInfo? _rucInfo;
  String? _error;
  Comprobante? _emitido;

  late final double _total = totalDePedido(widget.pedido.id);

  @override
  void dispose() {
    for (final c in [_ruc, _razon, _direccion, _dni, _nombre]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _boletaExigeDni => _total >= montoBoletaConDocumento;
  bool get _dniValido => RegExp(r'^\d{8}$').hasMatch(_dni.text.trim());
  bool get _rucValido => RegExp(r'^\d{11}$').hasMatch(_ruc.text.trim());

  bool get _completo {
    switch (_tipo) {
      case 'factura':
        return _rucValido &&
            _razon.text.trim().isNotEmpty &&
            (_rucInfo?.puedeFacturarse ?? true);
      case 'boleta':
        if (!_conDni) return !_boletaExigeDni;
        return _dniValido && _nombre.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  Future<void> _buscarRuc() async {
    if (!_rucValido || _buscando) return;
    setState(() {
      _buscando = true;
      _error = null;
    });
    try {
      final info = await FacturacionService.instance.consultarRuc(_ruc.text);
      if (!mounted) return;
      setState(() {
        _rucInfo = info;
        _razon.text = info.razonSocial;
        _direccion.text = info.direccionFiscal;
        if (!info.puedeFacturarse) {
          _error =
              'El RUC figura ${info.estado} / ${info.condicion}: SUNAT no '
              'acepta facturas a ese contribuyente.';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = _mensajeError(e));
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _emitir() async {
    if (!_completo || _emitiendo) return;
    setState(() {
      _emitiendo = true;
      _error = null;
    });
    try {
      final pagoId = pagos
          .where((p) => p.pedidoId == widget.pedido.id && !p.esReembolso)
          .map((p) => p.id)
          .where(UuidHelper.isValid)
          .firstOrNull;
      final c = await FacturacionService.instance.emitir(
        pedidoId: widget.pedido.id,
        tipoDocumento: _tipo,
        pagoId: pagoId,
        imprimir: _imprimir,
        clienteTipoDoc: switch (_tipo) {
          'factura' => '6',
          'boleta' => _conDni ? '1' : '0',
          _ => null,
        },
        clienteNumDoc: switch (_tipo) {
          'factura' => _ruc.text.trim(),
          'boleta' => _conDni ? _dni.text.trim() : '00000000',
          _ => null,
        },
        clienteDenominacion: switch (_tipo) {
          'factura' => _razon.text.trim(),
          'boleta' => _conDni ? _nombre.text.trim() : 'CLIENTES VARIOS',
          _ => null,
        },
        clienteDireccion: _tipo == 'factura' ? _direccion.text.trim() : null,
      );
      if (mounted) setState(() => _emitido = c);
    } catch (e) {
      if (mounted) setState(() => _error = _mensajeError(e));
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
          'Comprobante enviado a la impresora de caja.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, _mensajeError(e), type: ToastType.error);
      }
    }
  }

  Future<void> _whatsapp(Comprobante c) async {
    final url = c.pdfTicketUrl ?? c.pdfA4Url;
    if (url == null) return;
    final numero = await showBlurDialog<String>(
      context: context,
      builder: (_) =>
          WhatsappCuentaDialog(celularInicial: widget.pedido.clienteCelular),
    );
    if (numero == null || !mounted) return;
    final texto =
        'Hola, te enviamos tu ${c.tipoEtiqueta.toLowerCase()} '
        '${c.numeroComprobante} de ${negocio.nombre}. '
        'Total: S/ ${c.total.toStringAsFixed(2)}. Descárgala aquí: $url';
    final abierto = await abrirWhatsapp(numero, texto);
    if (!abierto && mounted) {
      showAppToast(
        context,
        'No se pudo abrir WhatsApp.',
        type: ToastType.error,
      );
    }
  }

  Widget _campo(
    TextEditingController c,
    String etiqueta, {
    bool lectura = false,
    TextInputType? teclado,
    List<TextInputFormatter>? formato,
    int? largo,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: CampoTexto(
      controller: c,
      readOnly: lectura,
      keyboardType: teclado,
      inputFormatters: formato,
      maxLength: largo,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: etiqueta, counterText: ''),
    ),
  );

  Widget _formulario() {
    final solo = <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];
    switch (_tipo) {
      case 'factura':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _campo(
                    _ruc,
                    'RUC (11 dígitos)',
                    teclado: TextInputType.number,
                    formato: solo,
                    largo: 11,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filled(
                    tooltip: 'Buscar en SUNAT',
                    onPressed: _rucValido && !_buscando ? _buscarRuc : null,
                    icon: _buscando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.search, size: 18),
                  ),
                ),
              ],
            ),
            _campo(_razon, 'Razón social'),
            _campo(_direccion, 'Dirección fiscal'),
          ],
        );
      case 'boleta':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '¿El cliente quiere su DNI en la boleta?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                AppSwitch(
                  value: _conDni,
                  onChanged: (v) => setState(() => _conDni = v),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_conDni) ...[
              _campo(
                _dni,
                'DNI (8 dígitos)',
                teclado: TextInputType.number,
                formato: solo,
                largo: 8,
              ),
              _campo(_nombre, 'Nombre del cliente'),
            ] else
              Text(
                _boletaExigeDni
                    ? 'Por el monto (desde S/ ${montoBoletaConDocumento.toStringAsFixed(0)}) '
                          'SUNAT exige el DNI del cliente.'
                    : 'Sin DNI sale a nombre de CLIENTES VARIOS.',
                style: TextStyle(
                  fontSize: 12,
                  color: _boletaExigeDni
                      ? AppColors.error
                      : Colors.grey.shade600,
                ),
              ),
          ],
        );
      default:
        return Text(
          'Constancia interna de consumo: no se envía a SUNAT ni pide datos '
          'del cliente.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        );
    }
  }

  Widget _resultado(Comprobante c) {
    final ok = c.estadoSunat == 'ACEPTADO' || c.esInterno;
    final color = ok
        ? AppColors.primaryGreen
        : (c.rechazado ? AppColors.error : AppColors.naranja);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                c.numeroComprobante,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${c.tipoEtiqueta} · ${c.estadoEtiqueta} · '
                'S/ ${c.total.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
              if (c.pendiente)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'SUNAT aún no confirma. Revisa su estado en Caja.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (c.pdfTicketUrl != null)
              OutlinedButton.icon(
                onPressed: () => abrirEnlace(c.pdfTicketUrl!),
                icon: const Icon(LucideIcons.fileText, size: 16),
                label: const Text('PDF ticket'),
              ),
            if (c.pdfA4Url != null)
              OutlinedButton.icon(
                onPressed: () => abrirEnlace(c.pdfA4Url!),
                icon: const Icon(LucideIcons.fileText, size: 16),
                label: const Text('PDF A4'),
              ),
            OutlinedButton.icon(
              onPressed: () => _reimprimir(c),
              icon: const Icon(LucideIcons.printer, size: 16),
              label: const Text('Reimprimir'),
            ),
            if (c.pdfTicketUrl != null || c.pdfA4Url != null)
              FilledButton.icon(
                onPressed: () => _whatsapp(c),
                icon: const Icon(LucideIcons.messageCircle, size: 16),
                label: const Text('Enviar por WhatsApp'),
                style: estiloBotonWhatsapp,
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final emitido = _emitido;
    if (emitido != null) {
      return DialogoApp(
        titulo: 'Comprobante emitido',
        ancho: 460,
        acciones: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(emitido),
            child: const Text('Listo'),
          ),
        ],
        children: [_resultado(emitido)],
      );
    }
    return DialogoApp(
      titulo: 'Emitir comprobante · Pedido #${widget.pedido.numeroPedido}',
      ancho: 460,
      acciones: [
        OutlinedButton(
          onPressed: _emitiendo ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _completo && !_emitiendo ? _emitir : null,
          child: _emitiendo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Emitir comprobante'),
        ),
      ],
      children: [
        Text(
          'Total del pedido: S/ ${_total.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          runSpacing: 8,
          children: [
            for (final t in const [
              ('ticket_venta', 'Ticket de venta'),
              ('boleta', 'Boleta'),
              ('factura', 'Factura'),
            ])
              AppTag(
                etiqueta: t.$2,
                activo: _tipo == t.$1,
                onTap: _emitiendo
                    ? null
                    : () => setState(() {
                        _tipo = t.$1;
                        _error = null;
                      }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _formulario(),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Imprimir en la ticketera de caja',
                style: TextStyle(fontSize: 13),
              ),
            ),
            AppSwitch(
              value: _imprimir,
              onChanged: (v) => setState(() => _imprimir = v),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
