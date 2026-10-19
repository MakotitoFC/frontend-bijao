import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _plato = '01925b6a-9b1d-7234-a123-abcdef012345';
const _sub = '01925b6a-9b1d-7234-a123-abcdef0123aa';
const _cat = '01925b6a-9b1d-7234-a123-abcdef0123bb';

void main() {
  late HttpServer servidor;
  final cuerpos = <Map<String, dynamic>>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    cartasNotifier.value = [];
    cuerpos.clear();
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
    servidor.listen((req) async {
      final texto = await utf8.decoder.bind(req).join();
      if (texto.isNotEmpty) {
        cuerpos.add(jsonDecode(texto) as Map<String, dynamic>);
      }
      // Como el backend: el POST y el PUT devuelven solo las columnas de
      // `carta`, sin la categoría ni el nombre de la subcategoría.
      req.response
        ..statusCode = req.method == 'POST' ? 201 : 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'id': _plato,
            'nombre_plato': 'Arroz chaufa',
            'descripcion': 'Con pollo',
            'subcategoria_id': _sub,
            'estado': 'disponible',
            'precio_cliente': 18,
          }),
        );
      await req.response.close();
    });
  });

  tearDown(() async {
    await servidor.close(force: true);
    cartasNotifier.value = [];
  });

  CartaItem plato() => const CartaItem(
    id: _plato,
    nombrePlato: 'Arroz chaufa',
    descripcion: 'Con pollo',
    categoriaId: _cat,
    categoriaNombre: 'Platos criollos',
    subcategoriaIds: [_sub],
    precioCliente: 18,
  );

  test(
    'al crear un plato se conserva la categoría y la subcategoría',
    () async {
      final creado = await CatalogService.instance.crearPlato(plato());

      // Se envía la subcategoría al backend (la categoría sale de ella).
      expect(cuerpos.single['subcategoria_id'], _sub);

      expect(creado.categoriaId, _cat);
      expect(creado.categoriaNombre, 'Platos criollos');
      expect(creado.subcategoriaIds, [_sub]);
      // Y el plato guardado en pantalla queda en su categoría.
      expect(cartasNotifier.value.single.categoriaId, _cat);
    },
  );

  test('al editar un plato no pierde su categoría', () async {
    cartasNotifier.value = [plato()];
    final editado = await CatalogService.instance.actualizarPlato(
      plato().copyWith(nombrePlato: 'Arroz chaufa especial'),
    );
    expect(editado.categoriaId, _cat);
    expect(editado.categoriaNombre, 'Platos criollos');
    expect(cartasNotifier.value.single.categoriaId, _cat);
  });
}
