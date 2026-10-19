import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _plato = '01925b6a-9b1d-7234-a123-abcdef012345';

CartaItem _item() => const CartaItem(
  id: _plato,
  nombrePlato: 'Ají de gallina',
  descripcion: '',
  categoriaId: 'c',
);

void main() {
  late HttpServer servidor;
  final rutas = <String>[];
  Map<String, dynamic> respuesta = {};

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    cartasNotifier.value = [_item()];
    rutas.clear();
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
    servidor.listen((req) async {
      await req.drain<void>();
      rutas.add('${req.method} ${req.uri.path}');
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(respuesta));
      await req.response.close();
    });
  });

  tearDown(() async {
    await servidor.close(force: true);
    cartasNotifier.value = [];
  });

  test('la foto se sube y se asocia al plato en una sola petición', () async {
    respuesta = {
      'url': '/uploads/carta/abc.jpg',
      'plato_actualizado': true,
      'carta_id': _plato,
    };
    final r = await CatalogService.instance.subirImagenPlato(_item(), [
      1,
      2,
      3,
    ], 'foto.jpg');

    // Una sola llamada, a la ruta del plato; ya no hay un PUT después.
    expect(rutas, ['POST /api/v1/carta/$_plato/foto']);
    expect(r.plato.urlImagen, '/uploads/carta/abc.jpg');
    expect(r.advertencia, isNull);
    // La carta en pantalla ya tiene la foto.
    expect(cartasNotifier.value.single.urlImagen, '/uploads/carta/abc.jpg');
  });

  test(
    'si el servidor no asoció la foto al plato, se avisa del error',
    () async {
      respuesta = {'url': '/uploads/carta/abc.jpg'}; // sin plato_actualizado
      await expectLater(
        CatalogService.instance.subirImagenPlato(_item(), [1], 'foto.jpg'),
        throwsA(
          predicate((e) => e.toString().contains('no la asoció al plato')),
        ),
      );
      // No se da por guardada: la carta no cambia.
      expect(cartasNotifier.value.single.urlImagen, isNull);
    },
  );

  test('la advertencia de "solo en el servidor" llega a quien llama', () async {
    respuesta = {
      'url': '/uploads/carta/abc.jpg',
      'plato_actualizado': true,
      'warning': 'No se pudo persistir en la nube (R2/Supabase): timeout',
    };
    final r = await CatalogService.instance.subirImagenPlato(_item(), [
      1,
    ], 'foto.jpg');
    expect(r.advertencia, contains('No se pudo persistir en la nube'));
    expect(r.plato.urlImagen, '/uploads/carta/abc.jpg');
  });
}
