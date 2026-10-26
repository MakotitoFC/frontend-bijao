import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/configuracion_store.dart';
import '../data/pagos_store.dart';
import '../models/comprobante.dart';
import '../models/pedido.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
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
import 'emitir_comprobante_dialog.dart';
import 'whatsapp_cuenta_dialog.dart';

// Hasta este total (inclusive) el DNI de la boleta es opcional; por encima,
// SUNAT exige los datos del cliente.
const montoBoletaConDocumento = 700.0;

String _mensajeError(Object e) => e is ApiException
    ? e.message
    : e.toString().replaceFirst('Exception: ', '');

// Solo administración y caja eligen el comprobante al cobrar.
bool puedeElegirComprobante(Pedido pedido) {
  final u = AuthService.instance.currentUser;
  return UuidHelper.isValid(pedido.id) &&
      u != null &&
      (u.esAdmin || u.esCajero);
}

// Lo que el cajero eligió en el cobro: ticket de venta (interno, sin
// SUNAT), boleta (con o sin DNI) o factura (con RUC). El comprobante se emite
// después de registrar el cobro, porque el servidor no factura sin un pago.
class ComprobanteEnCobro extends ChangeNotifier {
  // Siempre se emite un comprobante: el ticket de venta es el de por defecto.
  ComprobanteEnCobro(this.total, {String tipoInicial = 'ticket_venta'})
    : tipo = tipoInicial;

  // Total que cubre el comprobante (en el pago compartido, lo de ese pagador).
  double total;

  String tipo;
  bool conDni = false;
  bool imprimir = true;
  final ruc = TextEditingController();
  final razon = TextEditingController();
  final direccion = TextEditingController();
  final dni = TextEditingController();
  final nombre = TextEditingController();

  bool buscando = false;
  RucInfo? rucInfo;
  String? error;

  bool get emite => tipo != 'ninguno';
  // ¿Hay que imprimir después de la respuesta de SUNAT? (boleta o factura)
  bool get imprimirDespues => imprimir && tipo != 'ticket_venta';
  bool get boletaExigeDni => total > montoBoletaConDocumento;
  bool get dniValido => RegExp(r'^\d{8}$').hasMatch(dni.text.trim());
  bool get rucValido => RegExp(r'^\d{11}$').hasMatch(ruc.text.trim());

  // ¿Están los datos que pide el tipo elegido?
  bool get completo {
    switch (tipo) {
      case 'factura':
        return rucValido &&
            razon.text.trim().isNotEmpty &&
            (rucInfo?.puedeFacturarse ?? true);
      case 'boleta':
        if (!conDni) return !boletaExigeDni;
        return dniValido && nombre.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  void elegir(String nuevo) {
    tipo = nuevo;
    error = null;
    notifyListeners();
  }

  void cambio() => notifyListeners();

  void alternarDni(bool v) {
    conDni = v;
    notifyListeners();
  }

  void alternarImprimir(bool v) {
    imprimir = v;
    notifyListeners();
  }

  Future<void> buscarRuc() async {
    if (!rucValido || buscando) return;
    buscando = true;
    error = null;
    notifyListeners();
    try {
      final info = await FacturacionService.instance.consultarRuc(ruc.text);
      rucInfo = info;
      razon.text = info.razonSocial;
      direccion.text = info.direccionFiscal;
      if (!info.puedeFacturarse) {
        error =
            'El RUC figura ${info.estado} / ${info.condicion}: SUNAT no '
            'acepta facturas a ese contribuyente.';
      }
    } catch (e) {
      error = _mensajeError(e);
    } finally {
      buscando = false;
      notifyListeners();
    }
  }

  // Emite el comprobante elegido para [pedido]. Se llama con el cobro ya
  // registrado: se vincula al primer pago del pedido.
  // [pagoId] fija el pago al que se vincula (en el pago compartido, el de cada
  // pagador); sin él se usa el primero del pedido.
  Future<Comprobante> emitir(Pedido pedido, {String? pagoId}) {
    pagoId ??= pagos
        .where((p) => p.pedidoId == pedido.id && !p.esReembolso)
        .map((p) => p.id)
        .where(UuidHelper.isValid)
        .firstOrNull;
    return FacturacionService.instance.emitir(
      pedidoId: pedido.id,
      tipoDocumento: tipo,
      pagoId: pagoId,
      // Boleta y factura se imprimen cuando SUNAT ya respondió (ver
      // `ComprobanteEmitidoDialog`), para que el papel lleve los datos
      // confirmados. El ticket interno no espera a SUNAT.
      imprimir: tipo == 'ticket_venta' && imprimir,
      clienteTipoDoc: switch (tipo) {
        'factura' => '6',
        'boleta' => conDni ? '1' : '0',
        _ => null,
      },
      clienteNumDoc: switch (tipo) {
        'factura' => ruc.text.trim(),
        'boleta' => conDni ? dni.text.trim() : '00000000',
        _ => null,
      },
      clienteDenominacion: switch (tipo) {
        'factura' => razon.text.trim(),
        'boleta' => conDni ? nombre.text.trim() : 'CLIENTES VARIOS',
        _ => null,
      },
      clienteDireccion: tipo == 'factura' ? direccion.text.trim() : null,
    );
  }

  @override
  void dispose() {
    for (final c in [ruc, razon, direccion, dni, nombre]) {
      c.dispose();
    }
    super.dispose();
  }
}

// Sección "Comprobante" del diálogo de cobro.
class SelectorComprobante extends StatelessWidget {
  final ComprobanteEnCobro control;

  const SelectorComprobante({super.key, required this.control});

  Widget _campo(
    TextEditingController c,
    String etiqueta, {
    TextInputType? teclado,
    List<TextInputFormatter>? formato,
    int? largo,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: CampoTexto(
      controller: c,
      keyboardType: teclado,
      inputFormatters: formato,
      maxLength: largo,
      onChanged: (_) => control.cambio(),
      decoration: InputDecoration(labelText: etiqueta, counterText: ''),
    ),
  );

  Widget _formulario() {
    final solo = <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];
    switch (control.tipo) {
      case 'factura':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // La lupa va alineada con la caja del campo (no con su etiqueta).
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: CampoTexto(
                    controller: control.ruc,
                    keyboardType: TextInputType.number,
                    inputFormatters: solo,
                    maxLength: 11,
                    onChanged: (_) => control.cambio(),
                    decoration: const InputDecoration(
                      labelText: 'RUC (11 dígitos)',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: AppSizes.boton,
                  height: AppSizes.boton,
                  child: IconButton.filled(
                    tooltip: 'Buscar en SUNAT',
                    onPressed: control.rucValido && !control.buscando
                        ? control.buscarRuc
                        : null,
                    icon: control.buscando
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
            const SizedBox(height: 12),
            _campo(control.razon, 'Razón social'),
            _campo(control.direccion, 'Dirección fiscal'),
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
                  value: control.conDni,
                  onChanged: control.alternarDni,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (control.conDni) ...[
              _campo(
                control.dni,
                'DNI (8 dígitos)',
                teclado: TextInputType.number,
                formato: solo,
                largo: 8,
              ),
              _campo(control.nombre, 'Nombre del cliente'),
            ] else
              Text(
                control.boletaExigeDni
                    ? 'Por el monto (más de S/ ${montoBoletaConDocumento.toStringAsFixed(0)}) '
                          'SUNAT exige el DNI del cliente.'
                    : 'Sin DNI sale a nombre de CLIENTES VARIOS.',
                style: TextStyle(
                  fontSize: 12,
                  color: control.boletaExigeDni
                      ? AppColors.error
                      : Colors.grey.shade600,
                ),
              ),
          ],
        );
      case 'ticket_venta':
        return Text(
          'Constancia interna de consumo: no se envía a SUNAT ni pide datos '
          'del cliente.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: control,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Comprobante',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final t in [
                ('ticket_venta', 'Ticket de venta'),
                ('boleta', 'Boleta'),
                ('factura', 'Factura'),
              ])
                AppTag(
                  etiqueta: t.$2,
                  activo: control.tipo == t.$1,
                  onTap: () => control.elegir(t.$1),
                ),
            ],
          ),
          if (control.emite) ...[
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
                  value: control.imprimir,
                  onChanged: control.alternarImprimir,
                ),
              ],
            ),
          ],
          if (control.error != null) ...[
            const SizedBox(height: 8),
            Text(
              control.error!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

// Emite lo elegido una vez registrado el cobro. Si el servidor lo rechaza el
// cobro ya quedó guardado: se avisa y se deja reintentar.
Future<void> emitirComprobanteTrasCobro(
  BuildContext context,
  Pedido pedido,
  ComprobanteEnCobro eleccion, {
  String? pagoId,
}) async {
  if (!eleccion.emite) return;
  while (context.mounted) {
    try {
      final c = await eleccion.emitir(pedido, pagoId: pagoId);
      if (!context.mounted) return;
      await showBlurDialog<void>(
        context: context,
        builder: (_) => ComprobanteEmitidoDialog(
          comprobante: c,
          pedido: pedido,
          imprimirAlConfirmar: eleccion.imprimirDespues,
        ),
      );
      return;
    } catch (e) {
      if (!context.mounted) return;
      final accion = await showBlurDialog<String>(
        context: context,
        builder: (dialogContext) => AlertaApp(
          title: const Text('Comprobante no emitido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El cobro quedó registrado, pero no se pudo emitir el comprobante:\n'
                '${_mensajeError(e)}',
              ),
              const SizedBox(height: 12),
              const Text(
                'Puedes reintentar el envío o abrir el formulario para revisar y editar los datos manualmente.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('cerrar'),
              child: const Text('Cerrar'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop('manual'),
              child: const Text('Editar / Manual'),
            ),
            // El cajero no reintenta desde aquí: avisa al administrador.
            if (!(AuthService.instance.currentUser?.esCajero ?? false))
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop('reintentar'),
                child: const Text('Reintentar'),
              ),
          ],
        ),
      );
      if (accion == 'manual') {
        if (!context.mounted) return;
        final res = await showBlurDialog<EmisionHecha>(
          context: context,
          builder: (_) => EmitirComprobanteDialog(pedido: pedido),
        );
        if (res != null && context.mounted) {
          await showBlurDialog<void>(
            context: context,
            builder: (_) => ComprobanteEmitidoDialog(
              comprobante: res.comprobante,
              pedido: pedido,
              imprimirAlConfirmar: res.imprimirDespues,
            ),
          );
        }
        return;
      }
      if (accion != 'reintentar') return;
    }
  }
}

// Llamadas al servidor del resultado de la emisión. Se pueden reemplazar en las
// pruebas para simular la respuesta de SUNAT sin red.
@visibleForTesting
Future<Comprobante> Function(String id) consultarEstadoComprobante = (id) =>
    FacturacionService.instance.consultarEstado(id);
@visibleForTesting
Future<void> Function(String id) imprimirComprobante = (id) =>
    FacturacionService.instance.reimprimir(id);
@visibleForTesting
Duration esperaEntreConsultas = const Duration(seconds: 2);

// Resultado de la emisión: número, estado y accesos al PDF, la impresora y
// WhatsApp. SUNAT tarda unos segundos en responder: si el comprobante quedó
// pendiente se consulta su estado cada pocos segundos y, cuando llega la
// respuesta, se imprime (si se pidió) con los datos ya confirmados.
class ComprobanteEmitidoDialog extends StatefulWidget {
  final Comprobante comprobante;
  final Pedido pedido;
  // Imprimir apenas SUNAT confirme (boleta y factura).
  final bool imprimirAlConfirmar;

  const ComprobanteEmitidoDialog({
    super.key,
    required this.comprobante,
    required this.pedido,
    this.imprimirAlConfirmar = false,
  });

  @override
  State<ComprobanteEmitidoDialog> createState() =>
      _ComprobanteEmitidoDialogState();
}

class _ComprobanteEmitidoDialogState extends State<ComprobanteEmitidoDialog> {
  static const _maxIntentos = 10;

  late Comprobante _c = widget.comprobante;
  Timer? _timer;
  bool _esperando = false;
  bool _impreso = false;
  int _intentos = 0;

  @override
  void initState() {
    super.initState();
    if (_c.pendiente) {
      _esperar();
    } else {
      _imprimirSiCorresponde();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _esperar() {
    _timer?.cancel();
    _intentos = 0;
    setState(() => _esperando = true);
    _timer = Timer.periodic(esperaEntreConsultas, (_) async {
      _intentos++;
      try {
        final nuevo = await consultarEstadoComprobante(_c.id);
        if (!mounted) return;
        setState(() => _c = nuevo);
      } catch (_) {
        // Un fallo puntual de red no corta la espera.
      }
      if (!mounted) return;
      if (!_c.pendiente) {
        _timer?.cancel();
        setState(() => _esperando = false);
        _imprimirSiCorresponde();
      } else if (_intentos >= _maxIntentos) {
        _timer?.cancel();
        setState(() => _esperando = false);
      }
    });
  }

  // Imprime una sola vez, y solo si SUNAT no lo rechazó.
  Future<void> _imprimirSiCorresponde() async {
    if (!widget.imprimirAlConfirmar || _impreso) return;
    if (_c.rechazado || _c.anulado || _c.pendiente) return;
    _impreso = true;
    await _reimprimir(_c);
  }

  Future<void> _reimprimir(Comprobante c) async {
    try {
      await imprimirComprobante(c.id);
      if (mounted) {
        showAppToast(
          context,
          'Comprobante enviado a la impresora de caja.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      _impreso = false;
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

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ok = c.estadoSunat == 'ACEPTADO' || c.esInterno;
    final color = ok
        ? AppColors.primaryGreen
        : (c.rechazado ? AppColors.error : AppColors.naranja);
    return DialogoApp(
      titulo: 'Comprobante emitido',
      ancho: 460,
      acciones: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Listo'),
        ),
      ],
      children: [
        Column(
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
                  if (_esperando)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Esperando la respuesta de SUNAT…',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (c.pendiente)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        children: [
                          Text(
                            widget.imprimirAlConfirmar
                                ? 'SUNAT aún no responde. El comprobante quedó '
                                      'guardado y se imprimirá cuando llegue la '
                                      'respuesta.'
                                : 'SUNAT aún no confirma. Revisa su estado en '
                                      'Caja.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                          TextButton(
                            onPressed: _esperar,
                            child: const Text('Consultar de nuevo'),
                          ),
                        ],
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
                  onPressed: c.pendiente ? null : () => _reimprimir(c),
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
        ),
      ],
    );
  }
}
