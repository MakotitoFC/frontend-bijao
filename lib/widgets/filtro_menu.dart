import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'menu_flotante.dart';

// Filtro tipo botón: color fijo (el de la barra lateral), texto blanco y la
// flecha a la derecha. Abre un menú con las opciones. Es el mismo botón que el
// de medio de pago en Pedidos.
class FiltroMenu extends StatelessWidget {
  // Lo que se lee en el botón.
  final String texto;
  final String? seleccionada;
  final List<OpcionMenu<String>> opciones;
  final ValueChanged<String> onSeleccionar;
  final double ancho;
  final String? tooltip;

  const FiltroMenu({
    super.key,
    required this.texto,
    required this.seleccionada,
    required this.opciones,
    required this.onSeleccionar,
    this.ancho = 160,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: MenuFlotante<String>(
        tooltip: tooltip,
        seleccionada: seleccionada,
        onSeleccionar: onSeleccionar,
        opciones: opciones,
        disparador: (context, abierto) => Container(
          height: AppSizes.boton,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.navbar,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: abierto ? 0.5 : 0,
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
