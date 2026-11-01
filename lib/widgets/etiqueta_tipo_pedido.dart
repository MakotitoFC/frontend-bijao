import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/pedido.dart';

// Color y ícono de cada tipo de pedido, en tonos mate: mesa (amarillo),
// para llevar (verde) y delivery (morado).
(Color, IconData) estiloDeTipoPedido(String tipo) => switch (tipo) {
  'delivery' => (const Color(0xFF7B5C9E), LucideIcons.bike),
  'llevar' => (const Color(0xFF4E8A5F), LucideIcons.packageCheck),
  _ => (const Color(0xFFB8982F), LucideIcons.utensils),
};

// Etiqueta del tipo de pedido (Mesa 2, Para llevar, Delivery): solo trazo de
// su color, sin fondo.
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.3),
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
