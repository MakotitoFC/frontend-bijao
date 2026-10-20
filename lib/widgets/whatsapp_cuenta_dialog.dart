import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../utils/blur_dialog.dart';
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
  late final _celular = TextEditingController(
    text: widget.celularInicial ?? '',
  );

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
          'Se abre el chat del cliente en WhatsApp con el detalle de la cuenta '
          'ya escrito; solo falta dar "Enviar".',
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

// Flujo completo desde el botón: pide el celular y abre el chat del cliente en
// WhatsApp con el detalle de la cuenta ya escrito en texto (productos, totales,
// recargo y saldo). Solo falta dar "Enviar". No se manda ninguna imagen.
Future<void> enviarCuentaPorWhatsapp(
  BuildContext context, {
  required Pedido pedido,
  required List<PedidoLine> lineas,
  String metodoPago = '',
  double pagado = 0,
  double recargo = 0,
}) async {
  final numero = await showBlurDialog<String>(
    context: context,
    builder: (_) => WhatsappCuentaDialog(celularInicial: pedido.clienteCelular),
  );
  if (numero == null || !context.mounted) return;
  final abierto = await abrirWhatsapp(
    numero,
    textoCuentaWhatsapp(
      pedido: pedido,
      lineas: lineas,
      metodoPago: metodoPago,
      pagado: pagado,
      recargo: recargo,
    ),
  );
  if (!context.mounted) return;
  if (!abierto) {
    showAppToast(
      context,
      'No se pudo abrir WhatsApp. Revisa que esté instalado o que el '
      'navegador permita abrir enlaces.',
      type: ToastType.error,
    );
  }
}

// Estilo del botón verde de WhatsApp, compartido por las pantallas que lo usan.
final ButtonStyle estiloBotonWhatsapp = FilledButton.styleFrom(
  backgroundColor: const Color(0xFF25D366),
  foregroundColor: Colors.white,
);
