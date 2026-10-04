import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Marca de las cards de productos que son plato del día.
class EstrellaPlatoDelDia extends StatelessWidget {
  final double tamano;

  const EstrellaPlatoDelDia({super.key, this.tamano = 26});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Plato del día',
      child: Container(
        width: tamano,
        height: tamano,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.star_rounded,
          size: tamano * 0.72,
          color: AppColors.platoDelDia,
        ),
      ),
    );
  }
}
