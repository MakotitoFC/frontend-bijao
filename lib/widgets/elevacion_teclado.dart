import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

// Modo de enfoque de los campos donde se escribe.
//
// En celular y tablet (Android, iPhone y iPad; en la web también), al tocar un
// campo —de texto, número o buscador— se abre un editor arriba de la pantalla
// con SOLO ese campo, sobre un fondo oscuro. Así el campo nunca queda tapado
// por el teclado, aunque el navegador no informe la altura del teclado (pasa en
// Safari del iPhone). Lo que se escribe es el mismo texto del campo original:
// al tocar "Listo" (o fuera del editor) se cierra y el campo ya tiene el valor.
//
// Se aplica en toda la app, sin tocar cada campo: basta ponerlo una vez sobre el
// navegador de la aplicación. Los campos de un selector con búsqueda no abren el
// editor (su lista se vería tapada); para esos solo se sube el contenido sobre el
// teclado. En computadora no hace nada: no hay teclado en pantalla.
class ElevacionTeclado extends StatefulWidget {
  final Widget child;

  // Dónde queda un campo que se sube sobre el teclado (selectores con
  // búsqueda): 0 es arriba del todo y 1 abajo.
  final double alineacion;

  const ElevacionTeclado({
    super.key,
    required this.child,
    this.alineacion = 0.3,
  });

  // Solo pantallas táctiles con teclado en pantalla.
  static bool get aplica =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  State<ElevacionTeclado> createState() => _ElevacionTecladoState();
}

// Marca todo lo que está dentro del editor de enfoque: sus propios campos no
// vuelven a abrir otro editor.
class _MarcaEnfoque extends InheritedWidget {
  const _MarcaEnfoque({required super.child});

  @override
  bool updateShouldNotify(_MarcaEnfoque oldWidget) => false;
}

class _ElevacionTecladoState extends State<ElevacionTeclado>
    with WidgetsBindingObserver {
  Timer? _espera;
  double _tecladoAntes = 0;
  OverlayEntry? _enfoque;
  // Al cerrar el editor el foco puede volver al campo original: se ignora un
  // momento para que no se abra otra vez.
  DateTime _silencioHasta = DateTime.fromMillisecondsSinceEpoch(0);

  // Espacio que debe quedar libre entre un campo subido y el teclado.
  static const double _margenInferior = 80;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_alCambiarElFoco);
  }

  @override
  void dispose() {
    _espera?.cancel();
    _enfoque?.remove();
    _enfoque = null;
    FocusManager.instance.removeListener(_alCambiarElFoco);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  double get _teclado {
    final vista = View.maybeOf(context);
    if (vista == null) return 0;
    return vista.viewInsets.bottom / vista.devicePixelRatio;
  }

  // Sale el teclado con un campo que no usa el editor: se espera a que termine
  // de subir y se eleva el campo activo.
  @override
  void didChangeMetrics() {
    if (!ElevacionTeclado.aplica || _enfoque != null) return;
    final ahora = _teclado;
    final aparecio = ahora > 80 && ahora > _tecladoAntes + 40;
    _tecladoAntes = ahora;
    if (aparecio) _programar(const Duration(milliseconds: 320));
  }

  void _alCambiarElFoco() {
    if (!ElevacionTeclado.aplica || !mounted) return;
    if (DateTime.now().isBefore(_silencioHasta)) return;
    final contexto = FocusManager.instance.primaryFocus?.context;
    if (contexto == null || !contexto.mounted) return;
    final campo = contexto.findAncestorStateOfType<EditableTextState>();
    if (campo == null) return;
    // El campo del propio editor de enfoque.
    if (contexto.getInheritedWidgetOfExactType<_MarcaEnfoque>() != null) return;
    if (_enfoque == null && _admiteEditor(contexto, campo)) {
      // Se abre después de este cuadro: no se puede insertar durante el cambio
      // de foco.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _abrirEnfoque(contexto, campo),
      );
      return;
    }
    if (_enfoque == null && _teclado >= 80) {
      _programar(const Duration(milliseconds: 120));
    }
  }

  // Los campos de solo lectura y los de un selector con búsqueda no abren el
  // editor.
  bool _admiteEditor(BuildContext contexto, EditableTextState campo) {
    if (campo.widget.readOnly) return false;
    var enSelector = false;
    contexto.visitAncestorElements((e) {
      if (e.widget.runtimeType.toString().startsWith('AppSelect')) {
        enSelector = true;
        return false;
      }
      return true;
    });
    return !enSelector;
  }

  void _abrirEnfoque(BuildContext contexto, EditableTextState campo) {
    if (!mounted || _enfoque != null || !contexto.mounted) return;
    // El foco ya pasó a otra cosa mientras tanto.
    if (FocusManager.instance.primaryFocus?.context != contexto) return;
    final overlay = Overlay.maybeOf(contexto, rootOverlay: true);
    if (overlay == null) return;
    final w = campo.widget;
    final decoracion = contexto
        .findAncestorWidgetOfExactType<InputDecorator>()
        ?.decoration;
    final etiqueta =
        decoracion?.labelText ?? decoracion?.hintText ?? decoracion?.helperText;
    _enfoque = OverlayEntry(
      builder: (_) => _EditorEnfoque(
        etiqueta: etiqueta,
        controller: w.controller,
        keyboardType: w.keyboardType,
        textInputAction: w.textInputAction,
        textCapitalization: w.textCapitalization,
        inputFormatters: w.inputFormatters,
        obscureText: w.obscureText,
        maxLines: w.maxLines,
        minLines: w.minLines,
        onChanged: w.onChanged,
        onSubmitted: w.onSubmitted,
        onCerrando: _alCerrarseEnfoque,
        onCerrar: _cerrarEnfoque,
      ),
    );
    overlay.insert(_enfoque!);
  }

  // El editor empieza a cerrarse (la animación de salida corre): ya no tiene
  // foco, para que no vuelva solo al campo de antes ni se abra otro editor.
  void _alCerrarseEnfoque() {
    _silencioHasta = DateTime.now().add(const Duration(milliseconds: 900));
    FocusManager.instance.primaryFocus?.unfocus();
  }

  // Terminó la animación de salida: se quita el editor.
  void _cerrarEnfoque() {
    _silencioHasta = DateTime.now().add(const Duration(milliseconds: 300));
    _enfoque?.remove();
    _enfoque = null;
  }

  void _programar(Duration espera) {
    _espera?.cancel();
    _espera = Timer(espera, _elevar);
  }

  // Sube el contenido que se desplaza para dejar el campo activo sobre el
  // teclado (solo en los campos que no usan el editor de enfoque).
  void _elevar() {
    if (!mounted || _enfoque != null) return;
    final contexto = FocusManager.instance.primaryFocus?.context;
    if (contexto == null || !contexto.mounted) return;
    if (contexto.findAncestorWidgetOfExactType<EditableText>() == null) return;
    // Un campo que ya se ve cómodo, por encima del teclado, no se mueve.
    final caja = contexto.findRenderObject();
    final vista = View.maybeOf(context);
    if (caja is RenderBox && caja.attached && vista != null) {
      final arriba = caja.localToGlobal(Offset.zero).dy;
      final abajo = arriba + caja.size.height;
      final altoVisible =
          vista.physicalSize.height / vista.devicePixelRatio - _teclado;
      if (arriba >= 0 && abajo <= altoVisible - _margenInferior) return;
    }
    Scrollable.ensureVisible(
      contexto,
      alignment: widget.alineacion,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// El editor de enfoque: fondo oscuro y una tarjeta arriba con solo el campo que
// se está escribiendo. Usa el mismo controlador que el campo original, así que
// el texto es el mismo; los avisos de cambio (filtros, validaciones, totales)
// se reenvían al campo original.
class _EditorEnfoque extends StatefulWidget {
  final String? etiqueta;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onCerrando;
  final VoidCallback onCerrar;

  const _EditorEnfoque({
    required this.etiqueta,
    required this.controller,
    required this.keyboardType,
    required this.textInputAction,
    required this.textCapitalization,
    required this.inputFormatters,
    required this.obscureText,
    required this.maxLines,
    required this.minLines,
    required this.onChanged,
    required this.onSubmitted,
    required this.onCerrando,
    required this.onCerrar,
  });

  @override
  State<_EditorEnfoque> createState() => _EditorEnfoqueState();
}

class _EditorEnfoqueState extends State<_EditorEnfoque>
    with SingleTickerProviderStateMixin {
  // Entrada y salida suaves: el fondo se oscurece y la tarjeta baja un poco
  // mientras aparece; al cerrar, hace lo mismo al revés.
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _curva = CurvedAnimation(
    parent: _ctl,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _desliza = Tween<Offset>(
    begin: const Offset(0, -0.14),
    end: Offset.zero,
  ).animate(_curva);
  late final Animation<double> _escala = Tween<double>(
    begin: 0.97,
    end: 1,
  ).animate(_curva);
  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    // El cursor al final del texto que ya había.
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  // Cierra con la animación de salida; el padre quita el editor al terminar.
  Future<void> _cerrar() async {
    if (_cerrando) return;
    _cerrando = true;
    widget.onCerrando();
    await _ctl.reverse();
    if (mounted) widget.onCerrar();
  }

  @override
  Widget build(BuildContext context) {
    final etiqueta = widget.etiqueta?.trim() ?? '';
    final varias = !widget.obscureText && (widget.maxLines ?? 2) != 1;
    return _MarcaEnfoque(
      child: Positioned.fill(
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Fondo oscuro que aparece poco a poco.
              Positioned.fill(
                child: FadeTransition(
                  opacity: _curva,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.82),
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _cerrar,
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: FadeTransition(
                            opacity: _curva,
                            child: SlideTransition(
                              position: _desliza,
                              child: ScaleTransition(
                                scale: _escala,
                                alignment: Alignment.topCenter,
                                // Tocar la tarjeta no cierra el editor.
                                child: GestureDetector(
                                  onTap: () {},
                                  child: _tarjeta(etiqueta, varias),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(String etiqueta, bool varias) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  etiqueta.isEmpty ? 'Escribe aquí' : etiqueta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _cerrar,
                child: const Text(
                  'Listo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: widget.controller,
            autofocus: true,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            inputFormatters: widget.inputFormatters,
            obscureText: widget.obscureText,
            maxLines: widget.obscureText
                ? 1
                : (widget.maxLines ?? 5).clamp(1, 5),
            minLines: varias ? (widget.minLines ?? 1).clamp(1, 5) : null,
            onChanged: widget.onChanged,
            onSubmitted: (v) {
              widget.onSubmitted?.call(v);
              _cerrar();
            },
          ),
        ],
      ),
    );
  }
}
