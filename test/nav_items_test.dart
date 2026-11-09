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

  test('Configuración no se ve para mozo ni cajero, con permisos', () {
    final config = navItems.firstWhere((i) => i.clave == 'configuracion');
    const permisos = {'LEER.SEDE', 'LEER.PEDIDO'};
    for (final rol in [AppRole.mesero, AppRole.cajero]) {
      expect(config.tieneAcceso(_usuario(rol, permisos: permisos)), false);
    }
    expect(config.tieneAcceso(_usuario(AppRole.administrador)), true);
  });

  test('Cocina está oculta del menú para todos los roles', () {
    expect(navItems.any((i) => i.clave == 'cocina'), false);
    for (final rol in AppRole.values) {
      final visibles = navItems.where((i) => i.tieneAcceso(_usuario(rol)));
      expect(visibles.any((i) => i.label == 'Cocina'), false, reason: '$rol');
    }
  });

  test('Mesas sigue visible para el administrador, no para el cajero', () {
    expect(mesas.tieneAcceso(_usuario(AppRole.administrador)), true);
    expect(mesas.tieneAcceso(_usuario(AppRole.cajero)), false);
  });
}
