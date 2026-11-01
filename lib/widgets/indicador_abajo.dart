import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

// Barra de desplazamiento por defecto (siempre visible) y, abajo, un círculo con ">"
// hacia abajo mientras haya más contenido; al tocarlo baja.
class IndicadorAbajo extends StatefulWidget {
  // Controlador del scroll de [builder]; si no se da, se crea uno propio.
  final ScrollController? controller;
  final Widget Function(ScrollController controller) builder;
  final bool conFlecha;

  const IndicadorAbajo({
    super.key,
    this.controller,
    required this.builder,
    this.conFlecha = true,
  });

  @override
  State<IndicadorAbajo> createState() => IndicadorAbajoState();
}

class IndicadorAbajoState extends State<IndicadorAbajo> {
  static const double _holgura = 24;

  late final ScrollController _propio = ScrollController();
  ScrollController get _ctl => widget.controller ?? _propio;

  @override
  void initState() {
    super.initState();
    _ctl.addListener(_redibujar);
    WidgetsBinding.instance.addPostFrameCallback((_) => _redibujar());
  }

  @override
  void dispose() {
    _ctl.removeListener(_redibujar);
    _propio.dispose();
    super.dispose();
  }

  void _redibujar() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ctl = _ctl;
    final m = ctl.hasClients && ctl.position.hasContentDimensions
        ? ctl.position
        : null;
    // Diferencias de unos píxeles (márgenes) no cuentan como "hay que bajar".
    final scrollable = m != null && m.maxScrollExtent > _holgura;
    final hayMas = scrollable && m.pixels < m.maxScrollExtent - 1;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _redibujar());
        return false;
      },
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Sin la barra automática de escritorio: solo se ve la nuestra.
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
              // Se desplaza con el dedo, el lápiz, el mouse o el panel táctil.
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
                PointerDeviceKind.invertedStylus,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.unknown,
              },
            ),
            child: Scrollbar(
              controller: ctl,
              thumbVisibility: scrollable,
              child: widget.builder(ctl),
            ),
          ),
          if (hayMas && widget.conFlecha)
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Center(
                child: Tooltip(
                  message: 'Hay más abajo',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => ctl.animateTo(
                      m.maxScrollExtent,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
