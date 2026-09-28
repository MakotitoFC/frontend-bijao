import 'package:flutter/material.dart';

// Separador punteado horizontal (se usa arriba del footer fijo de
// confirmar/imprimir y como borde tipo "cartilla" en el modal de descuentos).
class DottedDivider extends StatelessWidget {
  final Color color;

  const DottedDivider({super.key, this.color = const Color(0xFFD1D5DB)});

  @override
  Widget build(BuildContext context) {
    const dash = 5.0;
    const gap = 4.0;
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, c) {
          final cantidad = (c.maxWidth / (dash + gap)).floor().clamp(1, 1000);
          return Row(
            children: [
              for (var i = 0; i < cantidad; i++) ...[
                Container(width: dash, height: 1, color: color),
                if (i != cantidad - 1) const SizedBox(width: gap),
              ],
            ],
          );
        },
      ),
    );
  }
}
