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
import 'whatsapp_cuenta_dialog.dart';

// A partir de este total SUNAT exige los datos del cliente en una boleta.
const montoBoletaConDocumento = 700.0;

String _mensajeError(Object e) => e is ApiException
    ? e.message
    : e.toString().replaceFirst('Exception: ', '');

// Solo administración y caja eligen el comprobante al cobrar.
bool puedeElegirComprobante(Pedido pedido) {
  final u = AuthService.instance.currentUser;
  return UuidHelper.isValid(pedido.id) && u != null && (u.esAdmin || u.esCajero);
}

// Lo que el cajero eligió en el cobro: ninguno, ticket de venta (interno, sin
// SUNAT), boleta (con o sin DNI) o factura (con RUC). El comprobante se emite
// después de registrar el cobro, porque el servidor no factura sin un pago.
class ComprobanteEnCobro extends ChangeNotifier {
  ComprobanteEnCobro(this.total);

  final double total;

  String tipo = 'ninguno';
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
  bool get boletaExigeDni => total >= montoBoletaConDocumento;
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
  Future<Comprobante> emitir(Pedido pedido) {
    final pagoId = pagos
        .where((p) => p.pedidoId == pedido.id && !p.esReembolso)
        .map((p) => p.id)
        .where(UuidHelper.isValid)
        .firstOrNull;
    return FacturacionService.instance.emitir(
      pedidoId: pedido.id,
      tipoDocumento: tipo,
      pagoId: pagoId,
      imprimir: imprimir,
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
                AppSwitch(value: control.conDni, onChanged: control.alternarDni),
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
                    ? 'Por el monto (desde S/ ${montoBoletaConDocumento.toStringAsFixed(0)}) '
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
              for (final t in const [
                ('ninguno', 'Ninguno'),
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
  ComprobanteEnCobro eleccion,
) async {
  if (!eleccion.emite) return;
  while (context.mounted) {
    try {
      final c = await eleccion.emitir(pedido);
      if (!context.mounted) return;
      await showBlurDialog<void>(
        context: context,
        builder: (_) => ComprobanteEmitidoDialog(comprobante: c, pedido: pedido),
      );
      return;
    } catch (e) {
      if (!context.mounted) return;
      final reintentar = await showBlurDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertaApp(
          title: const Text('Comprobante no emitido'),
          content: Text(
            'El cobro quedó registrado, pero no se pudo emitir el comprobante: '
            '${_mensajeError(e)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
      if (reintentar != true) return;
    }
  }
}

// Resultado de la emisión: número, estado y accesos al PDF, la impresora y
// WhatsApp.
class ComprobanteEmitidoDialog extends StatelessWidget {
  final Comprobante comprobante;
  final Pedido pedido;

  const ComprobanteEmitidoDialog({
    super.key,
    required this.comprobante,
    required this.pedido,
  });

  Future<void> _reimprimir(BuildContext context) async {
    try {
      await FacturacionService.instance.reimprimir(comprobante.id);
      if (context.mounted) {
        showAppToast(
          context,
          'Comprobante enviado a la impresora de caja.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, _mensajeError(e), type: ToastType.error);
      }
    }
  }

  Future<void> _whatsapp(BuildContext context) async {
    final c = comprobante;
    final url = c.pdfTicketUrl ?? c.pdfA4Url;
    if (url == null) return;
    final numero = await showBlurDialog<String>(
      context: context,
      builder: (_) => WhatsappCuentaDialog(celularInicial: pedido.clienteCelular),
    );
    if (numero == null || !context.mounted) return;
    final texto =
        'Hola, te enviamos tu ${c.tipoEtiqueta.toLowerCase()} '
        '${c.numeroComprobante} de ${negocio.nombre}. '
        'Total: S/ ${c.total.toStringAsFixed(2)}. Descárgala aquí: $url';
    final abierto = await abrirWhatsapp(numero, texto);
    if (!abierto && context.mounted) {
      showAppToast(
        context,
        'No se pudo abrir WhatsApp.',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = comprobante;
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
                  onPressed: () => _reimprimir(context),
                  icon: const Icon(LucideIcons.printer, size: 16),
                  label: const Text('Reimprimir'),
                ),
                if (c.pdfTicketUrl != null || c.pdfA4Url != null)
                  FilledButton.icon(
                    onPressed: () => _whatsapp(context),
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
