import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

// Botón circular de actualizar datos: el mismo en Inventario y en Impresoras.
class BotonActualizar extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;

  const BotonActualizar({
    super.key,
    required this.onTap,
    this.tooltip = 'Actualizar datos',
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(
            LucideIcons.refreshCw,
            size: 16,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
