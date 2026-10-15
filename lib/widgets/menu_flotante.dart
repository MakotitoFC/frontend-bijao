import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dialogo_app.dart';

// Una opción del menú flotante, con un punto de color opcional.
class OpcionMenu<T> {
  final T valor;
  final String etiqueta;
  final Color? color;

  const OpcionMenu({required this.valor, required this.etiqueta, this.color});
}

// Menú de opciones con el mismo diseño que los selectores (AppSelect): panel
// blanco de esquinas redondeadas que se abre pegado al disparador, debajo y, si
// no hay sitio, encima; nunca se sale de la pantalla ni del modal que lo
// contiene. El disparador lo dibuja quien lo usa (por ejemplo, una píldora de
// color).
class MenuFlotante<T> extends StatefulWidget {
  final List<OpcionMenu<T>> opciones;
  final T? seleccionada;
  final ValueChanged<T> onSeleccionar;
  // Recibe si el menú está abierto, para poder girar una flecha, por ejemplo.
  final Widget Function(BuildContext context, bool abierto) disparador;
  // Ancho mínimo del panel (se alinea al borde derecho del disparador).
  final double anchoMinimo;
  final String? tooltip;

  const MenuFlotante({
    super.key,
    required this.opciones,
    required this.onSeleccionar,
    required this.disparador,
    this.seleccionada,
    this.anchoMinimo = 190,
    this.tooltip,
  });

  @override
  State<MenuFlotante<T>> createState() => _MenuFlotanteState<T>();
}

class _MenuFlotanteState<T> extends State<MenuFlotante<T>> {
  final _enlace = LayerLink();
  final _llave = GlobalKey();
  OverlayEntry? _capa;
  bool _abierto = false;

  static const double _altoOpcion = 40;
  static const double _altoMaximo = 260;

  @override
  void dispose() {
    _capa?.remove();
    super.dispose();
  }

  void _alternar() => _abierto ? _cerrar() : _abrir();

  void _abrir() {
    final caja = _llave.currentContext!.findRenderObject() as RenderBox;
    final origen = caja.localToGlobal(Offset.zero);
    final alto = caja.size.height;
    final ancho = caja.size.width < widget.anchoMinimo
        ? widget.anchoMinimo
        : caja.size.width;

    final pantalla = Offset.zero & MediaQuery.sizeOf(context);
    final limite = LimiteModal.rectDe(context) ?? pantalla;
    const separacion = 6.0;
    const margen = 8.0;
    final espacioAbajo =
        limite.bottom - (origen.dy + alto) - separacion - margen;
    final espacioArriba = origen.dy - limite.top - separacion - margen;
    final necesario = (widget.opciones.length * _altoOpcion + 2).clamp(
      0.0,
      _altoMaximo,
    );
    final abajo = espacioAbajo >= necesario || espacioAbajo >= espacioArriba;
    final disponible = abajo ? espacioAbajo : espacioArriba;
    final altoPanel = disponible.clamp(60.0, _altoMaximo);

    _capa = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _cerrar,
            ),
          ),
          // Alineado al borde derecho del disparador, para no salirse por ese
          // lado cuando el disparador está pegado a la derecha.
          CompositedTransformFollower(
            link: _enlace,
            showWhenUnlinked: false,
            targetAnchor: abajo ? Alignment.bottomRight : Alignment.topRight,
            followerAnchor: abajo ? Alignment.topRight : Alignment.bottomRight,
            offset: Offset(0, abajo ? separacion : -separacion),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(width: ancho, child: _panel(altoPanel)),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_capa!);
    setState(() => _abierto = true);
  }

  void _cerrar() {
    _capa?.remove();
    _capa = null;
    if (mounted) setState(() => _abierto = false);
  }

  Widget _panel(double altoMaximo) {
    return Container(
      constraints: BoxConstraints(maxHeight: altoMaximo),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.tag),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          for (final o in widget.opciones)
            InkWell(
              onTap: () {
                _cerrar();
                widget.onSeleccionar(o.valor);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                color: o.valor == widget.seleccionada
                    ? AppColors.primaryGreen.withValues(alpha: 0.08)
                    : Colors.transparent,
                child: Row(
                  children: [
                    if (o.color != null) ...[
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: o.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        o.etiqueta,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: o.valor == widget.seleccionada
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: o.valor == widget.seleccionada
                              ? AppColors.primaryGreen
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget hijo = InkWell(
      key: _llave,
      borderRadius: BorderRadius.circular(100),
      onTap: _alternar,
      child: widget.disparador(context, _abierto),
    );
    if (widget.tooltip != null) {
      hijo = Tooltip(message: widget.tooltip!, child: hijo);
    }
    return CompositedTransformTarget(link: _enlace, child: hijo);
  }
}
