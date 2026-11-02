import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Una mesa dibujada como mesa: el número va en el respaldar de su silla. Libre
// en gris; ocupada en rojo; la elegida en negro y levantada con sombra, como
// una tecla. La mesa actual lleva un pin y no se puede elegir.
class IconoMesa extends StatelessWidget {
  final int numero;
  final bool ocupada;
  final bool actual;
  final bool seleccionada;
  // null = no se puede tocar (por ejemplo, solo se muestra).
  final VoidCallback? onTap;
  // Ancho de la mesa; por defecto 62.
  final double ancho;
  // Color propio de la mesa (por defecto gris, o rojo si está ocupada).
  final Color? colorPropio;

  const IconoMesa({
    super.key,
    this.colorPropio,
    this.ancho = 62,
    required this.numero,
    required this.ocupada,
    required this.actual,
    required this.seleccionada,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base =
        colorPropio ?? (ocupada ? AppColors.error : Colors.grey.shade700);
    final color = seleccionada ? AppColors.navbar : base;
    final mesa = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: ancho,
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
      transform: Matrix4.translationValues(0, seleccionada ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: seleccionada
              ? AppColors.navbar
              : (ocupada
                    ? AppColors.error.withValues(alpha: 0.5)
                    : Colors.grey.shade300),
        ),
        boxShadow: seleccionada
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Respaldar de la silla, con el número.
          Container(
            width: 38,
            height: 17,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(9),
                bottom: Radius.circular(3),
              ),
            ),
            child: Text(
              '$numero',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 3),
          // Tablero de la mesa.
          Container(
            height: 20,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: seleccionada ? 0.14 : 0.12),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: actual
                ? Icon(Icons.place, size: 13, color: color)
                : (ocupada
                      ? Icon(
                          Icons.circle,
                          size: 6,
                          color: color.withValues(alpha: 0.7),
                        )
                      : null),
          ),
        ],
      ),
    );
    return Tooltip(
      message: actual
          ? 'Mesa $numero · mesa actual'
          : (ocupada ? 'Mesa $numero · ocupada' : 'Mesa $numero'),
      child: actual
          ? Opacity(opacity: 0.55, child: mesa)
          : onTap == null
          ? mesa
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: mesa,
            ),
    );
  }
}
