import 'package:flutter/widgets.dart';

import 'app_role.dart';

// Ítem del sidebar de navegación de escritorio. Si `hijos` no está vacío,
// este ítem es un grupo (ej. "Ventas"): no tiene pantalla propia, solo agrupa
// y despliega sus hijos, que sí navegan cada uno a su propia vista.
class NavItem {
  final String clave;
  final String label;
  final IconData icono;
  final Set<AppRole> rolesPermitidos;
  final List<NavItem> hijos;

  const NavItem({
    required this.clave,
    required this.label,
    required this.icono,
    required this.rolesPermitidos,
    this.hijos = const [],
  });

  bool get esGrupo => hijos.isNotEmpty;
}
