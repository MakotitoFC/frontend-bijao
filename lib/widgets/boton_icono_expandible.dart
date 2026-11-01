import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Botón de solo icono con contenedor circular: al pasar el cursor por encima se
// expande y muestra su nombre. En pantallas táctiles basta tocarlo.
class BotonIconoExpandible extends StatefulWidget {
  final IconData icono;
  final String etiqueta;
  final VoidCallback? onPressed;
  // Relleno de color (botón principal); sin color es de trazo.
  final Color? color;

  const BotonIconoExpandible({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.onPressed,
    this.color,
  });

  @override
  State<BotonIconoExpandible> createState() => _BotonIconoExpandibleState();
}

class _BotonIconoExpandibleState extends State<BotonIconoExpandible> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final activo = widget.onPressed != null;
    final base = widget.color ?? AppColors.primaryGreen;
    final relleno = widget.color != null;
    final tinta = !activo
        ? Colors.grey.shade400
        : (relleno ? Colors.white : base);
    return MouseRegion(
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      cursor: activo ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: AppSizes.boton,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: relleno && activo ? base : Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.boton / 2),
            border: Border.all(color: !activo ? Colors.grey.shade300 : base),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icono, size: 18, color: tinta),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.centerLeft,
                child: _encima
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          widget.etiqueta,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: tinta,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
