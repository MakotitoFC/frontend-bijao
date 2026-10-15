import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

// Campo de texto de toda la app: etiqueta pequeña arriba, borde gris suave,
// placeholder en letra menor y borde verde al enfocar. Reemplaza a TextField y
// TextFormField: acepta los mismos parámetros y toma la etiqueta de
// `decoration.labelText` (que aquí se muestra encima del campo, no flotando).
class CampoTexto extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final TextStyle? style;
  final bool obscureText;
  final bool autofocus;
  final bool readOnly;
  final bool? enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool expands;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final GestureTapCallback? onTap;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Color? cursorColor;

  const CampoTexto({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.style,
    this.obscureText = false,
    this.autofocus = false,
    this.readOnly = false,
    this.enabled,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.expands = false,
    this.inputFormatters,
    this.onChanged,
    this.onTap,
    this.onFieldSubmitted,
    this.onSubmitted,
    this.validator,
    this.cursorColor,
  });

  static const double tamanoEtiqueta = 12;
  static const double tamanoTexto = 13.5;
  static const double tamanoPlaceholder = 12.5;

  static OutlineInputBorder _borde(Color color, [double ancho = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.tag),
        borderSide: BorderSide(color: color, width: ancho),
      );

  // Decoración común: se conserva lo que el campo trae (placeholder, iconos,
  // ayuda, error) y se unifica el aspecto.
  static InputDecoration decoracionBase(InputDecoration? d) {
    final base = d ?? const InputDecoration();
    // Un campo que va dentro de un contenedor con borde propio (sin borde).
    if (base.border == InputBorder.none) {
      return InputDecoration(
        isDense: true,
        filled: false,
        hintText: base.hintText,
        hintStyle: TextStyle(
          fontSize: tamanoPlaceholder,
          color: Colors.grey.shade500,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: base.contentPadding ?? EdgeInsets.zero,
      );
    }
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      hintText: base.hintText,
      hintStyle: TextStyle(
        fontSize: tamanoPlaceholder,
        color: Colors.grey.shade500,
      ),
      helperText: base.helperText,
      helperMaxLines: base.helperMaxLines,
      helperStyle: base.helperStyle,
      errorText: base.errorText,
      counterText: base.counterText,
      prefixIcon: base.prefixIcon,
      prefixIconConstraints:
          base.prefixIconConstraints ??
          (base.prefixIcon != null
              ? const BoxConstraints(minWidth: 40, minHeight: 20)
              : null),
      prefixText: base.prefixText,
      suffixIcon: base.suffixIcon,
      suffixText: base.suffixText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: _borde(Colors.grey.shade300),
      enabledBorder: _borde(Colors.grey.shade300),
      disabledBorder: _borde(Colors.grey.shade200),
      focusedBorder: _borde(AppColors.primaryGreen, 1.4),
      errorBorder: _borde(AppColors.error),
      focusedErrorBorder: _borde(AppColors.error, 1.4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final etiqueta = decoration?.labelText;
    final campo = TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      focusNode: focusNode,
      decoration: decoracionBase(decoration),
      keyboardType: keyboardType,
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      style: style ?? const TextStyle(fontSize: tamanoTexto),
      obscureText: obscureText,
      autofocus: autofocus,
      readOnly: readOnly,
      enabled: enabled,
      maxLines: expands ? null : maxLines,
      minLines: expands ? null : minLines,
      maxLength: maxLength,
      expands: expands,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onTap: onTap,
      onFieldSubmitted: onFieldSubmitted ?? onSubmitted,
      validator: validator,
      cursorColor: cursorColor,
    );
    if (etiqueta == null) return campo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: expands ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: tamanoEtiqueta,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        if (expands) Expanded(child: campo) else campo,
      ],
    );
  }
}

// Campo que muestra un valor y se toca para elegirlo (por ejemplo, una fecha):
// mismo aspecto que CampoTexto, con la etiqueta encima.
class CampoValor extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final VoidCallback? onTap;
  final Widget? sufijo;

  const CampoValor({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.onTap,
    this.sufijo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: CampoTexto.tamanoEtiqueta,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.tag),
          child: InputDecorator(
            decoration: CampoTexto.decoracionBase(
              InputDecoration(suffixIcon: sufijo),
            ),
            child: Text(
              valor,
              style: const TextStyle(fontSize: CampoTexto.tamanoTexto),
            ),
          ),
        ),
      ],
    );
  }
}
