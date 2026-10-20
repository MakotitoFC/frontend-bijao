import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../utils/blur_dialog.dart';
import '../utils/boleta_imagen.dart';
import '../utils/datos_sede.dart';
import '../utils/ticket_texto.dart';
import '../utils/whatsapp_cuenta.dart';
import 'app_toast.dart';
import 'boton_imprimir_whatsapp.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';

// Pide el celular del cliente (ya viene escrito si el pedido lo tiene) y abre
// WhatsApp con la cuenta lista para enviar. Devuelve el número listo para
// `wa.me` o null si se cancela.
class WhatsappCuentaDialog extends StatefulWidget {
  final String? celularInicial;

  const WhatsappCuentaDialog({super.key, this.celularInicial});

  @override
  State<WhatsappCuentaDialog> createState() => _WhatsappCuentaDialogState();
}

class _WhatsappCuentaDialogState extends State<WhatsappCuentaDialog> {
  late final _celular = TextEditingController(text: widget.celularInicial ?? '');

  @override
  void dispose() {
    _celular.dispose();
    super.dispose();
  }

  String? get _numero => numeroWhatsapp(_celular.text);

  void _enviar() {
    final n = _numero;
    if (n != null) Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    final vacio = _celular.text.trim().isEmpty;
    return DialogoApp(
      titulo: 'Enviar cuenta por WhatsApp',
      ancho: 400,
      acciones: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _numero == null ? null : _enviar,
          icon: const IconoWhatsapp(tamano: 18),
          label: const Text('Abrir WhatsApp'),
          style: estiloBotonWhatsapp,
        ),
      ],
      children: [
        Text(
          'Se guarda la boleta como imagen y se abre el chat del cliente en '
          'WhatsApp. Allí adjunta la imagen con el clip y envíala.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        CampoTexto(
          controller: _celular,
          autofocus: true,
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _enviar(),
          decoration: InputDecoration(
            labelText: 'Celular del cliente',
            hintText: '987654321',
            prefixText: '+51 ',
            errorText: vacio || _numero != null
                ? null
                : 'Escribe un celular válido (9 dígitos).',
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// Flujo completo desde el botón: pide el celular, convierte la boleta en una
// imagen y la guarda en el equipo, y abre el chat del cliente en WhatsApp. Un
// enlace de WhatsApp no puede adjuntar archivos, así que la imagen se adjunta
// desde el clip del chat. Si no se pudo generar la imagen, se manda la cuenta
// como texto.
Future<void> enviarCuentaPorWhatsapp(
  BuildContext context, {
  required Pedido pedido,
  required List<PedidoLine> lineas,
  required String mozo,
  String metodoPago = '',
  double pagado = 0,
  double recargo = 0,
}) async {
  final numero = await showBlurDialog<String>(
    context: context,
    builder: (_) => WhatsappCuentaDialog(celularInicial: pedido.clienteCelular),
  );
  if (numero == null || !context.mounted) return;

  final ticket = ticketBoleta(
    pedido: pedido,
    lineas: lineas,
    mozo: mozo,
    sede: datosDeLaSede(),
    metodoPago: metodoPago,
    pagado: pagado,
    recargo: recargo,
  );
  final png = await boletaComoPng(context, ticket);
  if (!context.mounted) return;

  var guardada = false;
  if (png != null) {
    try {
      // En la web baja directo a Descargas; en el celular y en Windows pregunta
      // dónde guardarla. Allí devuelve null aunque haya guardado, por eso no se
      // toma como cancelación.
      await FilePicker.saveFile(
        fileName: 'boleta-${pedido.numeroPedido}.png',
        bytes: png,
        mimeType: 'image/png',
        dialogTitle: 'Guardar la boleta',
      );
      guardada = true;
    } catch (_) {
      guardada = false;
    }
  }

  final mensaje = guardada
      ? mensajeBoletaWhatsapp(
          pedido: pedido,
          lineas: lineas,
          recargo: recargo,
        )
      : textoCuentaWhatsapp(
          pedido: pedido,
          lineas: lineas,
          metodoPago: metodoPago,
          pagado: pagado,
          recargo: recargo,
        );
  final abierto = await abrirWhatsapp(numero, mensaje);
  if (!context.mounted) return;
  if (!abierto) {
    showAppToast(
      context,
      'No se pudo abrir WhatsApp. Revisa que esté instalado o que el '
      'navegador permita abrir enlaces.',
      type: ToastType.error,
    );
  } else if (guardada) {
    showAppToast(
      context,
      'Boleta guardada como imagen. En el chat, adjúntala con el clip.',
      type: ToastType.success,
      duration: const Duration(seconds: 6),
    );
  } else {
    showAppToast(
      context,
      'No se pudo generar la imagen de la boleta: se envía la cuenta como texto.',
      type: ToastType.warning,
    );
  }
}

// Estilo del botón verde de WhatsApp, compartido por las pantallas que lo usan.
final ButtonStyle estiloBotonWhatsapp = FilledButton.styleFrom(
  backgroundColor: const Color(0xFF25D366),
  foregroundColor: Colors.white,
);
