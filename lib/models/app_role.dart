// Refleja `usuarios.rol` (CHECK: admin, trabajador, mesero, cajero).
enum AppRole { administrador, trabajador, mesero, cajero }

extension AppRoleLabel on AppRole {
  String get label {
    switch (this) {
      case AppRole.administrador:
        return 'Administrador';
      case AppRole.trabajador:
        return 'Trabajador';
      case AppRole.mesero:
        return 'Mesero';
      case AppRole.cajero:
        return 'Cajero';
    }
  }

  // Valor guardado en `usuarios.rol`.
  String get valorBd {
    switch (this) {
      case AppRole.administrador:
        return 'admin';
      case AppRole.trabajador:
        return 'trabajador';
      case AppRole.mesero:
        return 'mesero';
      case AppRole.cajero:
        return 'cajero';
    }
  }

  // Qué puede hacer cada rol dentro del sistema.
  String get descripcion {
    switch (this) {
      case AppRole.administrador:
        return 'Acceso a todo el sistema';
      case AppRole.trabajador:
        return 'Cocina: ve y prepara los pedidos';
      case AppRole.mesero:
        return 'Toma pedidos y consulta productos';
      case AppRole.cajero:
        return 'Toma pedidos y cobra en pagos';
    }
  }
}
