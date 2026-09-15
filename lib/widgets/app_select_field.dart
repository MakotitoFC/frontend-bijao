import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_theme.dart';

// Select personalizado: campo redondeado con ícono de flecha hacia abajo.
// Al tocarlo, despliega un menú anclado justo debajo del campo (no un
// modal/bottom sheet) con las opciones (ícono + texto), marcando la
// seleccionada con un check.
class AppSelectField<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final List<List<dynamic>>? Function(T item)? itemIcon;
  final ValueChanged<T> onChanged;
  final List<List<dynamic>>? leadingIcon;
  final String? errorText;

  const AppSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.itemIcon,
    this.leadingIcon,
    this.errorText,
  });

  @override
  State<AppSelectField<T>> createState() => _AppSelectFieldState<T>();
}

class _AppSelectFieldState<T> extends State<AppSelectField<T>> {
  final GlobalKey _fieldKey = GlobalKey();
  bool _abierto = false;

  Future<void> _abrirOpciones() async {
    final button = _fieldKey.currentContext!.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(
          Offset(0, button.size.height + 4),
          ancestor: overlay,
        ),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    setState(() => _abierto = true);
    final seleccionado = await showMenu<T>(
      context: context,
      position: position,
      constraints: BoxConstraints(
        minWidth: button.size.width,
        maxWidth: button.size.width,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
      ),
      items: widget.items.map((item) {
        final esSeleccionado = item == widget.value;
        final icono = widget.itemIcon?.call(item);
        return PopupMenuItem<T>(
          value: item,
          child: Row(
            children: [
              if (icono != null) ...[
                HugeIcon(icon: icono, color: AppColors.primaryGreen, size: 20),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  widget.itemLabel(item),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (esSeleccionado)
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  color: AppColors.primaryGreen,
                  size: 18,
                ),
            ],
          ),
        );
      }).toList(),
    );
    if (mounted) setState(() => _abierto = false);
    if (seleccionado != null) widget.onChanged(seleccionado);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: _fieldKey,
      borderRadius: BorderRadius.circular(AppRadii.input),
      onTap: _abrirOpciones,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: widget.errorText,
          prefixIcon: widget.leadingIcon == null
              ? null
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: HugeIcon(
                    icon: widget.leadingIcon!,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                ),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: AnimatedRotation(
              turns: _abierto ? 0.5 : 0,
              duration: const Duration(milliseconds: 150),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                color: Colors.grey.shade500,
                size: 18,
              ),
            ),
          ),
        ),
        child: Text(
          widget.value == null ? '' : widget.itemLabel(widget.value as T),
          style: Theme.of(context).textTheme.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
