import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'campo_texto.dart';

// Buscador común de todas las vistas: un solo campo con lupa, del mismo alto
// que tags y selects, con el borde y el placeholder del resto de campos y un
// ancho que se ajusta al texto de su placeholder.
class AppSearchField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  // false: ocupa todo el ancho disponible en vez del que pide su placeholder.
  final bool ajustarAlTexto;

  const AppSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.ajustarAlTexto = true,
  });

  // Lupa + márgenes + algo de espacio para escribir.
  static const double _extra = 14 + 22 + 12 + 24;

  static OutlineInputBorder _borde(Color color, [double ancho = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.tag),
        borderSide: BorderSide(color: color, width: ancho),
      );

  @override
  Widget build(BuildContext context) {
    const estiloHint = TextStyle(fontSize: CampoTexto.tamanoPlaceholder);
    final medida = TextPainter(
      text: TextSpan(text: hint, style: estiloHint),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return SizedBox(
      width: ajustarAlTexto ? medida.width + _extra + 20 : double.infinity,
      height: AppSizes.control,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: AppColors.primaryGreen,
        style: const TextStyle(fontSize: CampoTexto.tamanoTexto),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: CampoTexto.tamanoPlaceholder,
            color: Colors.grey.shade500,
          ),
          prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 18,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          border: _borde(Colors.grey.shade300),
          enabledBorder: _borde(Colors.grey.shade300),
          focusedBorder: _borde(AppColors.primaryGreen, 1.4),
        ),
      ),
    );
  }
}
