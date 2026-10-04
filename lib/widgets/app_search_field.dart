import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Buscador común de todas las vistas: mismo alto que tags y selects, esquinas
// de tag, y un ancho que se ajusta al texto de su placeholder.
class AppSearchField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  const AppSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
  });

  static const double _tamanoTexto = 13;
  // Icono + separaciones + algo de espacio para escribir.
  static const double _extra = 14 + 18 + 10 + 18 + 24;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final estilo = base.copyWith(fontSize: _tamanoTexto);
    final medida = TextPainter(
      text: TextSpan(text: hint, style: estilo),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return SizedBox(
      width: medida.width + _extra,
      height: AppSizes.control,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.tag),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search, size: 18, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: estilo.copyWith(color: Colors.black87),
                cursorColor: AppColors.primaryGreen,
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  hintText: hint,
                  hintStyle: estilo.copyWith(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
