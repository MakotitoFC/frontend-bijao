import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSelectItem<T> {
  final T value;
  final String label;

  const AppSelectItem({required this.value, required this.label});
}

// Select reutilizable: panel de opciones flotante sobre el contenido, con
// flecha que rota al abrir.
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

  const AppSelect({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint = 'Selecciona una opción',
    this.flotante = false,
    this.compacto = false,
  });

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>> {
  final _link = LayerLink();
  final _campoKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _abierto = false;

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  String get _etiquetaActual {
    final coincidencias = widget.items.where((i) => i.value == widget.value);
    return coincidencias.isEmpty ? widget.hint : coincidencias.first.label;
  }

  void _alternar() => _abierto ? _cerrar() : _abrir();

  void _abrir() {
    final renderBox = _campoKey.currentContext!.findRenderObject() as RenderBox;
    final ancho = renderBox.size.width;
    final alto = renderBox.size.height;
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
            offset: Offset(0, alto + 6),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(width: ancho, child: _panelOpciones()),
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

  Widget _panelOpciones() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.input),
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
        children: widget.items.map((item) {
          final seleccionado = item.value == widget.value;
          return InkWell(
            onTap: () {
              widget.onChanged(item.value);
              _cerrar();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        }).toList(),
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
    return CompositedTransformTarget(
      link: _link,
      child: Column(
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
          Material(
            key: _campoKey,
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.input),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.input),
              onTap: _alternar,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: widget.compacto ? 9 : 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.input),
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
                          fontSize: widget.compacto ? 13 : 14,
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
                        size: widget.compacto ? 18 : 20,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
