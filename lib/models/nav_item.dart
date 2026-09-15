import 'app_role.dart';

// Ítem del sidebar de navegación de escritorio.
class NavItem {
  final String clave;
  final String label;
  final List<List<dynamic>> icono;
  final Set<AppRole> rolesPermitidos;

  const NavItem({
    required this.clave,
    required this.label,
    required this.icono,
    required this.rolesPermitidos,
  });
}
