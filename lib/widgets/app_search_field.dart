import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Buscador común de todas las vistas: un solo campo con lupa, de tamaño medio
// (46 px de alto y texto de 14) en celular, tablet y escritorio, con el borde y
// el placeholder del resto de campos. En escritorio y tablet el ancho se ajusta
// al texto de su placeholder; en el celular ocupa todo el ancho.
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

  // Alto y texto del buscador, iguales en los tres dispositivos.
  static const double _alto = 46;
  // Esquinas más redondeadas que las del resto de campos.
  static const double _radio = 16;
  static const double _tamanoTexto = 14;

  // Lupa + márgenes + algo de espacio para escribir.
  static const double _extra = 14 + 24 + 12 + 24;

  static OutlineInputBorder _borde(Color color, [double ancho = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radio),
        borderSide: BorderSide(color: color, width: ancho),
      );

  @override
  Widget build(BuildContext context) {
    const estiloHint = TextStyle(fontSize: _tamanoTexto);
    final medida = TextPainter(
      text: TextSpan(text: hint, style: estiloHint),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    // En el celular el buscador ocupa todo el ancho y es más alto, para verlo
    // y tocarlo con comodidad.
    final movil = AppBreakpoints.esMobile(context);
    return SizedBox(
      width: (ajustarAlTexto && !movil)
          ? medida.width + _extra + 20
          : double.infinity,
      height: _alto,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: AppColors.primaryGreen,
        style: const TextStyle(fontSize: _tamanoTexto),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: _tamanoTexto,
            color: Colors.grey.shade500,
          ),
          prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade500),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 13,
          ),
          border: _borde(Colors.grey.shade300),
          enabledBorder: _borde(Colors.grey.shade300),
          focusedBorder: _borde(AppColors.primaryGreen, 1.4),
        ),
      ),
    );
  }
}
