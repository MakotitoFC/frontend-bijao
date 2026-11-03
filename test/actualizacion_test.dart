import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/services/actualizacion_service.dart';

void main() {
  test('lee la versión del servidor, con o sin el bloque android', () {
    final a = VersionApp.desdeJson({
      'android': {
        'version_code': 3,
        'version_name': '1.0.2',
        'url': '/api/v1/app/apk',
        'obligatoria': true,
        'notas': 'Mejoras',
      },
    });
    expect(a?.codigo, 3);
    expect(a?.nombre, '1.0.2');
    expect(a?.obligatoria, true);
    final b = VersionApp.desdeJson({'version_code': '4', 'url': '/x.apk'});
    expect(b?.codigo, 4);
    expect(b?.obligatoria, false);
  });

  test('datos incompletos no generan aviso', () {
    expect(VersionApp.desdeJson(null), isNull);
    expect(VersionApp.desdeJson({'version_code': 3}), isNull);
    expect(VersionApp.desdeJson({'url': '/x.apk'}), isNull);
  });

  test('solo avisa si la versión del servidor es mayor', () {
    const v = VersionApp(codigo: 3, nombre: '', url: '/x.apk');
    expect(ActualizacionService.hayVersionNueva(2, v), true);
    expect(ActualizacionService.hayVersionNueva(3, v), false);
    expect(ActualizacionService.hayVersionNueva(4, v), false);
    expect(ActualizacionService.hayVersionNueva(2, null), false);
  });

  test('buscar devuelve la versión nueva y calla si hay error', () async {
    final nueva = await ActualizacionService.instance.buscar(
      instalada: () async => 2,
      consultar: () async => {'version_code': 3, 'url': '/x.apk'},
    );
    expect(nueva?.codigo, 3);
    final igual = await ActualizacionService.instance.buscar(
      instalada: () async => 3,
      consultar: () async => {'version_code': 3, 'url': '/x.apk'},
    );
    expect(igual, isNull);
    final falla = await ActualizacionService.instance.buscar(
      instalada: () async => 2,
      consultar: () async => throw Exception('sin servidor'),
    );
    expect(falla, isNull);
  });

  test('la ruta relativa se completa con la dirección del servidor', () {
    const v = VersionApp(codigo: 3, nombre: '', url: '/api/v1/app/apk');
    expect(ActualizacionService.urlDescarga(v).path, '/api/v1/app/apk');
    const w = VersionApp(codigo: 3, nombre: '', url: 'http://10.0.0.5/a.apk');
    expect(ActualizacionService.urlDescarga(w).host, '10.0.0.5');
  });
}
