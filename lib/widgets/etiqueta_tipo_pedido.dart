import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/pedido.dart';
import '../theme/app_theme.dart';

// Color y ícono de cada tipo de pedido: mesa (verde), para llevar (azul) y
// delivery (violeta).
(Color, IconData) estiloDeTipoPedido(String tipo) => switch (tipo) {
  'delivery' => (const Color(0xFF7C3AED), LucideIcons.bike),
  'llevar' => (AppColors.info, LucideIcons.packageCheck),
  _ => (AppColors.primaryGreenDark, LucideIcons.utensils),
};

// Etiqueta del tipo de pedido (Mesa 2, Para llevar, Delivery) con su color.
class EtiquetaTipoPedido extends StatelessWidget {
  final Pedido pedido;
  final double tamano;

  const EtiquetaTipoPedido({super.key, required this.pedido, this.tamano = 16});

  @override
  Widget build(BuildContext context) {
    final (color, icono) = estiloDeTipoPedido(pedido.tipoPedido);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tamano * 0.6,
        vertical: tamano * 0.3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: tamano + 1, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              pedido.ubicacion,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: tamano,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
