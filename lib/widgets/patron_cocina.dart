import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Fondo decorativo: íconos de cocina (platos, ollas, cubiertos, bebidas…)
// repartidos en filas desfasadas y ligeramente girados.
class PatronCocina extends StatelessWidget {
  final Color color;
  final double tamanoIcono;
  final double separacion;

  const PatronCocina({
    super.key,
    required this.color,
    this.tamanoIcono = 30,
    this.separacion = 92,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _PatronPainter(color, tamanoIcono, separacion),
      ),
    );
  }
}

class _PatronPainter extends CustomPainter {
  final Color color;
  final double tamanoIcono;
  final double separacion;

  _PatronPainter(this.color, this.tamanoIcono, this.separacion);

  static const _iconos = <IconData>[
    LucideIcons.utensils,
    LucideIcons.chefHat,
    LucideIcons.cookingPot,
    LucideIcons.soup,
    LucideIcons.cupSoda,
    LucideIcons.salad,
    LucideIcons.utensilsCrossed,
    LucideIcons.beef,
    LucideIcons.fish,
    LucideIcons.egg,
    LucideIcons.coffee,
    LucideIcons.flame,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    var fila = 0;
    for (
      var y = separacion / 2;
      y < size.height + separacion;
      y += separacion * 0.82
    ) {
      final desfase = fila.isEven ? 0.0 : separacion / 2;
      var columna = 0;
      for (var x = desfase; x < size.width + separacion; x += separacion) {
        final mitad = tamanoIcono * 0.75;
        // Solo íconos completos: nada se corta en los bordes de la sección.
        if (x - mitad < 0 ||
            x + mitad > size.width ||
            y - mitad < 0 ||
            y + mitad > size.height) {
          columna++;
          continue;
        }
        final icono = _iconos[(fila * 5 + columna * 3) % _iconos.length];
        final angulo = (((fila * 7 + columna * 3) % 5) - 2) * 0.22;
        final pincel = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icono.codePoint),
            style: TextStyle(
              fontSize: tamanoIcono,
              fontFamily: icono.fontFamily,
              package: icono.fontPackage,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angulo * math.pi / 2);
        pincel.paint(canvas, Offset(-pincel.width / 2, -pincel.height / 2));
        canvas.restore();
        columna++;
      }
      fila++;
    }
  }

  @override
  bool shouldRepaint(covariant _PatronPainter old) =>
      old.color != color ||
      old.tamanoIcono != tamanoIcono ||
      old.separacion != separacion;
}
