import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSelectItem<T> {
  final T value;
  final String label;

  const AppSelectItem({required this.value, required this.label});
}

// Select reutilizable: el campo muestra una flecha que rota 180° al abrir
// (mismo patrón que el botón de contraer/expandir del navbar) y las opciones
// se despliegan en un panel flotante justo debajo, por ENCIMA del contenido
// de la pantalla (no lo empuja hacia abajo), usando un OverlayEntry anclado
// con CompositedTransformFollower para que siga al campo si la pantalla
// hace scroll.
class AppSelect<T> extends StatefulWidget {
  final String? label;
  final T? value;
  final List<AppSelectItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;

  const AppSelect({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint = 'Selecciona una opción',
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

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
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
                          fontSize: 14,
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
                        size: 20,
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
