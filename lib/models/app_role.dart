// Refleja los roles principales de la base de datos (ADMINISTRADOR, CAJERO, MOZO, TRABAJADOR)
enum AppRole { administrador, trabajador, mesero, cajero }

extension AppRoleLabel on AppRole {
  String get label {
    switch (this) {
      case AppRole.administrador:
        return 'Administrador';
      case AppRole.trabajador:
        return 'Trabajador';
      case AppRole.mesero:
        return 'Mozo / Mesero';
      case AppRole.cajero:
        return 'Cajero';
    }
  }

  // Valor guardado en la BD
  String get valorBd {
    switch (this) {
      case AppRole.administrador:
        return 'ADMINISTRADOR';
      case AppRole.trabajador:
        return 'TRABAJADOR';
      case AppRole.mesero:
        return 'MOZO';
      case AppRole.cajero:
        return 'CAJERO';
    }
  }

  String get descripcion {
    switch (this) {
      case AppRole.administrador:
        return 'Acceso total y configuración del restaurante';
      case AppRole.trabajador:
        return 'Cocina: visualiza y despacha pedidos';
      case AppRole.mesero:
        return 'Atención de mesas y toma de pedidos';
      case AppRole.cajero:
        return 'Cobro de pedidos y gestión de caja';
    }
  }

  static AppRole fromString(String? val) {
    final v = (val ?? '').trim().toUpperCase();
    if (v.contains('ADMIN')) return AppRole.administrador;
    if (v.contains('MOZO') || v.contains('MESERO')) return AppRole.mesero;
    if (v.contains('CAJA') || v.contains('CAJERO')) return AppRole.cajero;
    if (v.contains('TRABAJ') || v.contains('COCINA')) return AppRole.trabajador;
    return AppRole.mesero;
  }
}
