import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';

// Logo de WhatsApp de trazo: globo de chat con un teléfono adentro. Lucide no
// trae iconos de marcas, así que se arma con dos de sus iconos.
class IconoWhatsapp extends StatelessWidget {
  final double tamano;
  final Color color;

  const IconoWhatsapp({super.key, this.tamano = 20, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: tamano,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(LucideIcons.messageCircle, size: tamano, color: color),
          Icon(LucideIcons.phone, size: tamano * 0.46, color: color),
        ],
      ),
    );
  }
}

// Un solo botón oscuro con dos mitades: impresora | WhatsApp (trazo blanco).
// La primera abre el ticket para imprimir; la segunda manda la cuenta al cliente.
class BotonImprimirWhatsapp extends StatelessWidget {
  final VoidCallback onImprimir;
  final VoidCallback onWhatsapp;

  const BotonImprimirWhatsapp({
    super.key,
    required this.onImprimir,
    required this.onWhatsapp,
  });

  @override
  Widget build(BuildContext context) {
    Widget mitad(String tooltip, VoidCallback onTap, Widget icono) => Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: Center(child: icono),
        ),
      ),
    );
    return SizedBox(
      height: AppSizes.boton,
      child: Material(
        color: AppColors.navbar,
        borderRadius: BorderRadius.circular(AppRadii.button),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            mitad(
              'Imprimir',
              onImprimir,
              const Icon(LucideIcons.printer, size: 20, color: Colors.white),
            ),
            Container(width: 1, height: 22, color: Colors.white24),
            mitad(
              'Enviar la cuenta por WhatsApp',
              onWhatsapp,
              const IconoWhatsapp(),
            ),
          ],
        ),
      ),
    );
  }
}
