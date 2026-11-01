import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

// Ícono de la campana del header. Es solo el ícono: no cuenta ni abre nada.
class CampanaNotificaciones extends StatelessWidget {
  const CampanaNotificaciones({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Icon(LucideIcons.bell, size: 20, color: Colors.grey.shade600),
      ),
    );
  }
}
