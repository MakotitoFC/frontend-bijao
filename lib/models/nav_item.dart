import 'package:flutter/widgets.dart';

import 'app_role.dart';
import 'usuario.dart';

// Ítem del sidebar de navegación de escritorio con control de acceso por Rol y Permiso RBAC.
class NavItem {
  final String clave;
  final String label;
  final IconData icono;
  final Set<AppRole> rolesPermitidos;
  final List<NavItem> hijos;
  final String? permisoRequerido;

  const NavItem({
    required this.clave,
    required this.label,
    required this.icono,
    required this.rolesPermitidos,
    this.hijos = const [],
    this.permisoRequerido,
  });

  bool get esGrupo => hijos.isNotEmpty;

  /// Determina si un usuario tiene acceso a este ítem (por permiso específico o por rol).
  bool tieneAcceso(Usuario usuario) {
    if (usuario.esAdmin) return true;
    if (permisoRequerido != null && usuario.tienePermiso(permisoRequerido)) {
      return true;
    }
    if (rolesPermitidos.contains(usuario.rol)) {
      return true;
    }
    // Si es un grupo, tiene acceso si tiene acceso a al menos uno de sus hijos
    if (esGrupo) {
      return hijos.any((h) => h.tieneAcceso(usuario));
    }
    return false;
  }
}
