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
  // Más bajo y del ancho de su texto también en el celular.
  final bool compacto;

  const AppSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.ajustarAlTexto = true,
    this.compacto = false,
  });

  // Alto y texto del buscador, iguales en los tres dispositivos.
  static const double _alto = 46;
  // Esquinas más redondeadas que las del resto de campos.
  static const double _radio = 16;
  static const double _tamanoTexto = 14;
  static const double _altoCompacto = 38;
  static const double _tamanoTextoCompacto = 13;

  // Con un placeholder corto ('Buscar...') el campo sigue siendo cómodo para
  // escribir un nombre o un número.
  static const double _anchoMinimo = 260;

  // Lupa + márgenes + algo de espacio para escribir.
  static const double _extra = 14 + 24 + 12 + 24;

  static OutlineInputBorder _borde(Color color, [double ancho = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radio),
        borderSide: BorderSide(color: color, width: ancho),
      );

  @override
  Widget build(BuildContext context) {
    final tamano = compacto ? _tamanoTextoCompacto : _tamanoTexto;
    final estiloHint = TextStyle(fontSize: tamano);
    final medida = TextPainter(
      text: TextSpan(text: hint, style: estiloHint),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    // En el celular el buscador ocupa todo el ancho y es más alto, para verlo
    // y tocarlo con comodidad.
    final movil = AppBreakpoints.esMobile(context) && !compacto;
    return SizedBox(
      width: (ajustarAlTexto && !movil)
          ? (medida.width + _extra + 20 < _anchoMinimo
                ? _anchoMinimo
                : medida.width + _extra + 20)
          : double.infinity,
      height: compacto ? _altoCompacto : _alto,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: AppColors.primaryGreen,
        style: TextStyle(fontSize: tamano),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          hintText: hint,
          hintStyle: TextStyle(fontSize: tamano, color: Colors.grey.shade500),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: compacto ? 8 : 0),
            child: Icon(Icons.search, size: 20, color: Colors.grey.shade500),
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: compacto ? 48 : 40,
            minHeight: 20,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: compacto ? 16 : 12,
            vertical: compacto ? 10 : 13,
          ),
          border: _borde(Colors.grey.shade300),
          enabledBorder: _borde(Colors.grey.shade300),
          focusedBorder: _borde(AppColors.primaryGreen, 1.4),
        ),
      ),
    );
  }
}
