import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/nav_items.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/usuario.dart';

Usuario _usuario(AppRole rol, {Set<String> permisos = const {}}) => Usuario(
  id: 'u',
  nombre: 'x',
  email: 'x@x.com',
  rol: rol,
  sedeId: 's',
  permisos: permisos,
);

void main() {
  final mesas = navItems.firstWhere((i) => i.clave == 'mesas');

  test('Mesas no se ve para el mozo, ni teniendo el permiso LEER.MESA', () {
    expect(
      mesas.tieneAcceso(_usuario(AppRole.mesero, permisos: {'LEER.MESA'})),
      false,
    );
    expect(mesas.tieneAcceso(_usuario(AppRole.mesero)), false);
  });

  test(
    'Configuración y Cocina no se ven para mozo ni cajero, con permisos',
    () {
      final config = navItems.firstWhere((i) => i.clave == 'configuracion');
      final cocina = navItems.firstWhere((i) => i.clave == 'cocina');
      const permisos = {'LEER.SEDE', 'LEER.PEDIDO'};
      for (final rol in [AppRole.mesero, AppRole.cajero]) {
        expect(config.tieneAcceso(_usuario(rol, permisos: permisos)), false);
        expect(cocina.tieneAcceso(_usuario(rol, permisos: permisos)), false);
      }
      expect(config.tieneAcceso(_usuario(AppRole.administrador)), true);
      expect(cocina.tieneAcceso(_usuario(AppRole.trabajador)), true);
    },
  );

  test('Mesas sigue visible para el administrador, no para el cajero', () {
    expect(mesas.tieneAcceso(_usuario(AppRole.administrador)), true);
    expect(mesas.tieneAcceso(_usuario(AppRole.cajero)), false);
  });
}
