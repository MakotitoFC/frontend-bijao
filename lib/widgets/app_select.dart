import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dialogo_app.dart';

class AppSelectItem<T> {
  final T value;
  final String label;

  const AppSelectItem({required this.value, required this.label});
}

// Select reutilizable. Al abrirse, las opciones salen en un panel flotante
// pegado al selector: debajo de él, y si no hay espacio, encima. Nunca lo tapa ni
// se sale del modal que lo contiene. La flecha rota al abrir.
class AppSelect<T> extends StatefulWidget {
  final String? label;
  final T? value;
  final List<AppSelectItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;
  // Etiqueta flotando sobre el borde, como un TextField.
  final bool flotante;
  // Campo más bajo, para barras de filtros.
  final bool compacto;
  // Muestra un campo para escribir y filtrar las opciones (listas largas).
  final bool buscable;

  const AppSelect({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint = 'Selecciona una opción',
    this.flotante = false,
    this.compacto = false,
    this.buscable = false,
  });

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>> {
  final _link = LayerLink();
  final _campoKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _abierto = false;
  final _buscador = TextEditingController();
  final _consulta = ValueNotifier<String>('');

  @override
  void dispose() {
    _overlayEntry?.remove();
    _buscador.dispose();
    _consulta.dispose();
    super.dispose();
  }

  // Minúsculas y sin tildes, para que "cafe" encuentre "Café".
  static String _normalizar(String t) {
    const de = 'áàäâéèëêíìïîóòöôúùüûñ';
    const a = 'aaaaeeeeiiiioooouuuun';
    final b = StringBuffer();
    for (final c in t.toLowerCase().split('')) {
      final i = de.indexOf(c);
      b.write(i >= 0 ? a[i] : c);
    }
    return b.toString();
  }

  List<AppSelectItem<T>> _filtradas(String consulta) {
    final q = _normalizar(consulta.trim());
    if (q.isEmpty) return widget.items;
    return widget.items.where((i) => _normalizar(i.label).contains(q)).toList();
  }

  String get _etiquetaActual {
    final coincidencias = widget.items.where((i) => i.value == widget.value);
    return coincidencias.isEmpty ? widget.hint : coincidencias.first.label;
  }

  void _alternar() => _abierto ? _cerrar() : _abrir();

  // Alto aproximado de una opción, para decidir si cabe debajo.
  static const double _altoOpcion = 40;
  static const double _altoMaximo = 260;

  void _abrir() {
    final caja = _campoKey.currentContext!.findRenderObject() as RenderBox;
    final origen = caja.localToGlobal(Offset.zero);
    final ancho = caja.size.width;
    final alto = caja.size.height;

    // Zona permitida: el modal que contiene al selector o, si no hay, la
    // pantalla.
    final pantalla = Offset.zero & MediaQuery.sizeOf(context);
    final limite = LimiteModal.rectDe(context) ?? pantalla;
    const separacion = 6.0;
    const margen = 8.0;
    final espacioAbajo =
        limite.bottom - (origen.dy + alto) - separacion - margen;
    final espacioArriba = origen.dy - limite.top - separacion - margen;
    final necesario =
        (widget.items.length * _altoOpcion + 2 + (widget.buscable ? 52 : 0))
            .clamp(0.0, _altoMaximo);
    // Debajo si cabe (o si hay más sitio que arriba); si no, encima.
    final abajo = espacioAbajo >= necesario || espacioAbajo >= espacioArriba;
    final disponible = abajo ? espacioAbajo : espacioArriba;
    final altoPanel = disponible.clamp(
      widget.buscable ? 120.0 : 60.0,
      _altoMaximo,
    );
    _buscador.clear();
    _consulta.value = '';

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
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
            targetAnchor: abajo ? Alignment.bottomLeft : Alignment.topLeft,
            followerAnchor: abajo ? Alignment.topLeft : Alignment.bottomLeft,
            offset: Offset(0, abajo ? separacion : -separacion),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(width: ancho, child: _panelOpciones(altoPanel)),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    setState(() => _abierto = true);
  }

  void _cerrar() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _abierto = false);
  }

  Widget _opcion(AppSelectItem<T> item) {
    final seleccionado = item.value == widget.value;
    return InkWell(
      onTap: () {
        widget.onChanged(item.value);
        _cerrar();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: seleccionado
            ? AppColors.primaryGreen.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Text(
          item.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w400,
            color: seleccionado ? AppColors.primaryGreen : Colors.black87,
          ),
        ),
      ),
    );
  }

  // Campo de búsqueda del panel: filtra mientras se escribe y, con Enter,
  // elige la primera coincidencia.
  Widget _campoBusqueda() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: SizedBox(
        height: 38,
        child: TextField(
          controller: _buscador,
          autofocus: true,
          style: const TextStyle(fontSize: 13.5),
          onChanged: (v) => _consulta.value = v,
          onSubmitted: (v) {
            final lista = _filtradas(v);
            if (lista.isEmpty) return;
            widget.onChanged(lista.first.value);
            _cerrar();
          },
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Escribe para buscar...',
            prefixIcon: const Icon(Icons.search, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tag),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelOpciones(double altoMaximo) {
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
      child: widget.buscable
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _campoBusqueda(),
                Flexible(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _consulta,
                    builder: (context, consulta, _) {
                      final lista = _filtradas(consulta);
                      if (lista.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Sin resultados',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        );
                      }
                      return ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [for (final i in lista) _opcion(i)],
                      );
                    },
                  ),
                ),
              ],
            )
          : ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [for (final i in widget.items) _opcion(i)],
            ),
    );
  }

  Widget _campoFlotante(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyLarge;
    return CompositedTransformTarget(
      link: _link,
      child: Material(
        key: _campoKey,
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.input),
          onTap: _alternar,
          child: InputDecorator(
            isFocused: _abierto,
            isEmpty: widget.value == null,
            decoration: InputDecoration(labelText: widget.label),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _etiquetaActual,
                    overflow: TextOverflow.ellipsis,
                    style: estilo,
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  turns: _abierto ? 0.5 : 0,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flotante) return _campoFlotante(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        CompositedTransformTarget(
          link: _link,
          child: Material(
            key: _campoKey,
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.tag),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.tag),
              onTap: _alternar,
              child: Container(
                height: AppSizes.control,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.tag),
                  border: Border.all(
                    color: _abierto
                        ? AppColors.primaryGreen
                        : Colors.grey.shade400,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _etiquetaActual,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: widget.value == null ? 12.5 : 13.5,
                          color: widget.value == null
                              ? Colors.grey.shade500
                              : Colors.black87,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      turns: _abierto ? 0.5 : 0,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
