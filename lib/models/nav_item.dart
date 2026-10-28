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
  // Roles a los que el ítem se les oculta aunque tengan el permiso (el
  // administrador siempre lo ve).
  final Set<AppRole> rolesOcultos;

  const NavItem({
    required this.clave,
    required this.label,
    required this.icono,
    required this.rolesPermitidos,
    this.hijos = const [],
    this.permisoRequerido,
    this.rolesOcultos = const {},
  });

  bool get esGrupo => hijos.isNotEmpty;

  /// Determina si un usuario tiene acceso a este ítem (por permiso específico o por rol).
  bool tieneAcceso(Usuario usuario) {
    if (usuario.esAdmin) return true;

    // Si el ítem exige un permiso RBAC específico, ese permiso es la regla de oro:
    // si el usuario lo tiene (asignado directamente o por su rol), entra; si se le revocó, no entra.
    if (permisoRequerido != null) {
      return usuario.tienePermiso(permisoRequerido);
    }

    // Para ítems sin permiso RBAC específico (ej. Inicio):
    if (rolesOcultos.contains(usuario.rol)) return false;
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
