import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/services/network_discovery_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    ApiClient.instance.setBaseUrl('http://127.0.0.1:6050');
  });

  group('Paso 2 & 3: Integración de Red y Autenticación con Backend Go', () {
    test('1. Ping al servidor local en puerto 6050', () async {
      final isAlive = await NetworkDiscoveryService.pingServer('http://127.0.0.1:6050');
      expect(isAlive, isTrue);
    });

    test('2. Login exitoso con Administrador (admin)', () async {
      final user = await AuthService.instance.login(
        usuario: 'admin',
        password: 'Admin123!',
      );

      expect(user.nombre, equals('admin'));
      expect(user.esAdmin, isTrue);
      expect(user.tienePermiso('CREAR.MESA'), isTrue);
      expect(user.tienePermiso('DELETE.USUARIO'), isTrue);
      expect(ApiClient.instance.hasToken, isTrue);
    });

    test('3. Login exitoso con Mozo (mozo1)', () async {
      final user = await AuthService.instance.login(
        usuario: 'mozo1',
        password: 'Mozo123!',
      );

      expect(user.nombre, equals('mozo1'));
      expect(user.esMozo, isTrue);
      expect(user.tienePermiso('LEER.CARTA'), isTrue);
      expect(user.tienePermiso('CREAR.PEDIDO'), isTrue);
      expect(user.tienePermiso('DELETE.PEDIDO'), isTrue);
      // No debe tener permiso de administración de roles
      expect(user.tienePermiso('DELETE.ROL'), isFalse);
    });

    test('4. Login exitoso con Cajero (caja1)', () async {
      final user = await AuthService.instance.login(
        usuario: 'caja1',
        password: 'Cajero123!',
      );

      expect(user.nombre, equals('caja1'));
      expect(user.esCajero, isTrue);
      expect(user.tienePermiso('CREAR.PAGO'), isTrue);
      expect(user.tienePermiso('LEER.MEDIO_PAGO'), isTrue);
      // No debe tener permiso de eliminar sede
      expect(user.tienePermiso('DELETE.SEDE'), isFalse);
    });

    test('5. Login con contraseña incorrecta es rechazado', () async {
      expect(
        () async => await AuthService.instance.login(
          usuario: 'admin',
          password: 'PasswordIncorrecta999',
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
