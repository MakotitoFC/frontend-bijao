import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Una entrada del submenú: una opción que se puede elegir o una etiqueta de
// sección (agrupa las opciones que le siguen en un desplegable).
class SubmenuEntrada {
  final String? clave;
  final String etiqueta;

  const SubmenuEntrada.item(String this.clave, this.etiqueta);
  const SubmenuEntrada.seccion(this.etiqueta) : clave = null;

  bool get esSeccion => clave == null;
}

// Una pestaña de la barra: una opción suelta o una sección con sus opciones
// (que se eligen en un desplegable).
class _Pestana {
  final String etiqueta;
  final String? clave; // opción suelta
  final List<SubmenuEntrada> opciones; // sección con desplegable

  const _Pestana.suelta(this.etiqueta, String this.clave) : opciones = const [];
  const _Pestana.seccion(this.etiqueta, this.opciones) : clave = null;

  bool get esSeccion => clave == null;
}

// Barra horizontal de subvistas de un módulo (por ejemplo, Ventas), que va
// debajo del header. El fondo de la barra es verde y las letras oscuras; la
// pestaña activa va en negrita y subrayada. Las secciones con varias opciones
// se abren en un desplegable propio (el mismo diseño de los selectores), en
// vez de poner todo en la barra.
class SubmenuSuperior extends StatelessWidget {
  final List<SubmenuEntrada> entradas;
  final String? seleccionada;
  final ValueChanged<String> onSeleccionar;

  const SubmenuSuperior({
    super.key,
    required this.entradas,
    required this.seleccionada,
    required this.onSeleccionar,
  });

  // Barra oscura con letras blancas.
  static const _tinta = Colors.white;

  // Agrupa las entradas: cada etiqueta de sección junto con las opciones que
  // le siguen forma una pestaña con desplegable.
  List<_Pestana> get _pestanas {
    final lista = <_Pestana>[];
    String? seccion;
    var opciones = <SubmenuEntrada>[];
    void cerrar() {
      if (seccion != null && opciones.isNotEmpty) {
        lista.add(_Pestana.seccion(seccion!, opciones));
      }
      seccion = null;
      opciones = [];
    }

    for (final e in entradas) {
      if (e.esSeccion) {
        cerrar();
        seccion = e.etiqueta;
      } else if (seccion != null) {
        opciones.add(e);
      } else {
        lista.add(_Pestana.suelta(e.etiqueta, e.clave!));
      }
    }
    cerrar();
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navbar,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final p in _pestanas)
              p.esSeccion
                  ? _PestanaDesplegable(
                      pestana: p,
                      seleccionada: seleccionada,
                      onSeleccionar: onSeleccionar,
                    )
                  : _Caja(
                      texto: p.etiqueta,
                      activa: p.clave == seleccionada,
                      onTap: () => onSeleccionar(p.clave!),
                    ),
          ],
        ),
      ),
    );
  }
}

// El texto de una pestaña: oscuro sobre el verde; la activa, en negrita y con
// una línea debajo.
class _Caja extends StatelessWidget {
  final String texto;
  final bool activa;
  final bool conFlecha;
  final VoidCallback? onTap;

  const _Caja({
    required this.texto,
    required this.activa,
    this.conFlecha = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = activa
        ? SubmenuSuperior._tinta
        : SubmenuSuperior._tinta.withValues(alpha: 0.72);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: activa ? SubmenuSuperior._tinta : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              texto,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: activa ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
            if (conFlecha) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 18, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

// Pestaña de una sección: al tocarla abre un panel con sus opciones, con el
// mismo diseño del desplegable de los selectores.
class _PestanaDesplegable extends StatefulWidget {
  final _Pestana pestana;
  final String? seleccionada;
  final ValueChanged<String> onSeleccionar;

  const _PestanaDesplegable({
    required this.pestana,
    required this.seleccionada,
    required this.onSeleccionar,
  });

  @override
  State<_PestanaDesplegable> createState() => _PestanaDesplegableState();
}

class _PestanaDesplegableState extends State<_PestanaDesplegable> {
  final _link = LayerLink();
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  void _alternar() => _overlay == null ? _abrir() : _cerrar();

  void _cerrar() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() {});
  }

  void _abrir() {
    _overlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _cerrar,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
                child: _panel(),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
    setState(() {});
  }

  Widget _opcion(SubmenuEntrada o) {
    final elegida = o.clave == widget.seleccionada;
    return InkWell(
      onTap: () {
        widget.onSeleccionar(o.clave!);
        _cerrar();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: elegida
            ? AppColors.primaryGreen.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Text(
          o.etiqueta,
          style: TextStyle(
            fontSize: 14,
            fontWeight: elegida ? FontWeight.w700 : FontWeight.w400,
            color: elegida ? AppColors.primaryGreen : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _panel() {
    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final o in widget.pestana.opciones) _opcion(o)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final elegida = widget.pestana.opciones
        .where((o) => o.clave == widget.seleccionada)
        .firstOrNull;
    return CompositedTransformTarget(
      link: _link,
      child: _Caja(
        texto: elegida == null
            ? widget.pestana.etiqueta
            : '${widget.pestana.etiqueta} · ${elegida.etiqueta}',
        activa: elegida != null,
        conFlecha: true,
        onTap: _alternar,
      ),
    );
  }
}
