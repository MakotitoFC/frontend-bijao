import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'campo_texto.dart';

// Rectángulo (en pantalla) del modal que contiene a un widget. Los selectores
// lo usan para que su lista de opciones nunca se salga del modal.
class LimiteModal extends InheritedWidget {
  final GlobalKey llave;

  const LimiteModal({super.key, required this.llave, required super.child});

  // Rectángulo global del modal, o null si no hay modal o aún no se dibujó.
  static Rect? rectDe(BuildContext context) {
    final l = context.dependOnInheritedWidgetOfExactType<LimiteModal>();
    final caja = l?.llave.currentContext?.findRenderObject();
    if (caja is! RenderBox || !caja.hasSize) return null;
    return caja.localToGlobal(Offset.zero) & caja.size;
  }

  @override
  bool updateShouldNotify(LimiteModal old) => llave != old.llave;
}

// Botón "x" de los modales: contenedor circular con trazo gris y sin fondo.
class BotonCerrarCircular extends StatelessWidget {
  final VoidCallback? onPressed;
  final double tamano;

  const BotonCerrarCircular({super.key, this.onPressed, this.tamano = 32});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cerrar',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed ?? () => Navigator.of(context).maybePop(),
        child: Container(
          width: tamano,
          height: tamano,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(Icons.close, size: 17, color: Colors.grey.shade700),
        ),
      ),
    );
  }
}

// Línea gris muy suave que separa el encabezado del contenido, con aire arriba
// y abajo.
class SeparadorDialogo extends StatelessWidget {
  final double aire;

  const SeparadorDialogo({super.key, this.aire = 16});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: aire),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.grey.withValues(alpha: 0.18),
      ),
    );
  }
}

// Estructura común de los formularios en ventana: fondo blanco, título de peso
// medio con una "x" en un círculo en la misma fila, una línea gris muy suave
// con aire arriba y abajo, el contenido y los botones al pie.
//
// Se abre con `showBlurDialog`.
class DialogoApp extends StatelessWidget {
  final String titulo;
  final List<Widget> children;
  // Botones del pie, alineados a la derecha (ej. Cancelar, Guardar).
  final List<Widget> acciones;
  final double ancho;
  // false: sin la "x" (para ventanas que no se pueden cerrar sin completarlas).
  final bool mostrarCerrar;

  const DialogoApp({
    super.key,
    required this.titulo,
    required this.children,
    this.acciones = const [],
    this.ancho = 440,
    this.mostrarCerrar = true,
  });

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    final altoMax = MediaQuery.sizeOf(context).height * 0.9;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? anchoPantalla : ancho,
          maxWidth: esMobile ? anchoPantalla : ancho,
          maxHeight: altoMax,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, esMobile ? 26 : 20, 18, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (mostrarCerrar) const BotonCerrarCircular(),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: SeparadorDialogo(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  acciones.isEmpty
                      ? 24 + MediaQuery.viewInsetsOf(context).bottom
                      : 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            if (acciones.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 8,
                    children: acciones,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Campo de texto de los formularios en ventana (atajo de CampoTexto con
// etiqueta, placeholder y mensaje de error).
class CampoDialogo extends StatelessWidget {
  final String etiqueta;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? teclado;
  final bool oculto;
  final int maxLines;
  final String? error;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const CampoDialogo({
    super.key,
    required this.etiqueta,
    this.controller,
    this.hint,
    this.teclado,
    this.oculto = false,
    this.maxLines = 1,
    this.error,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return CampoTexto(
      controller: controller,
      keyboardType: teclado,
      obscureText: oculto,
      maxLines: maxLines,
      autofocus: autofocus,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: etiqueta,
        hintText: hint,
        errorText: error,
      ),
    );
  }
}

// Aviso o confirmación con la forma de AlertDialog (título, contenido y
// botones) pero con el diseño de ventana de la app. En celular sale desde
// abajo, de lado a lado. Se abre con `showBlurDialog`.
class AlertaApp extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  const AlertaApp({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = title;
    return DialogoApp(
      titulo: t is Text ? (t.data ?? '') : '',
      ancho: 420,
      acciones: actions,
      children: [
        DefaultTextStyle.merge(
          style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
          child: content,
        ),
        if (actions.isEmpty) const SizedBox(height: 4),
      ],
    );
  }
}
