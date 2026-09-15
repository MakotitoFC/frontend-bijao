// Simulación local de la tabla `rol` mientras no hay backend conectado.
// TODO: reemplazar por el id/nombre real que venga de `rol` (Supabase / servidor local).
enum AppRole { administrador, mesero, cocina }

extension AppRoleLabel on AppRole {
  String get label {
    switch (this) {
      case AppRole.administrador:
        return 'Administrador';
      case AppRole.mesero:
        return 'Mesero';
      case AppRole.cocina:
        return 'Cocina';
    }
  }
}
