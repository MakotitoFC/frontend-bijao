import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Barra de desplazamiento solo en pantallas anchas. En celular (APK y web
// angosta) no se ve: ahí se desliza con el dedo y la barra solo estorba.
class BarraDesplazamiento extends StatelessWidget {
  final ScrollController? controller;
  final bool? thumbVisibility;
  final Widget child;

  const BarraDesplazamiento({
    super.key,
    this.controller,
    this.thumbVisibility,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.esMobile(context)) return child;
    return Scrollbar(
      controller: controller,
      thumbVisibility: thumbVisibility,
      child: child,
    );
  }
}
