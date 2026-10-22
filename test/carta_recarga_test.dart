import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HttpServer servidor;
  final rutas = <String>[];
  var platos = <Map<String, dynamic>>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    cartasNotifier.value = [];
    rutas.clear();
    platos = [];
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
    servidor.listen((req) async {
      rutas.add('${req.method} ${req.uri.path}');
      // Pequeña espera: así dos recargas seguidas se solapan.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(req.uri.path == '/api/carta' ? platos : []));
      await req.response.close();
    });
  });

  tearDown(() async {
    await servidor.close(force: true);
    cartasNotifier.value = [];
  });

  test('recargar trae los platos nuevos que llegaron al servidor', () async {
    expect(cartasNotifier.value, isEmpty);
    platos = [
      {
        'id': '01925b6a-9b1d-7234-a123-abcdef012345',
        'nombre_plato': 'Arroz plato prueba',
        'subcategoria_id': '01925b6a-9b1d-7234-a123-abcdef0123aa',
        'estado': 'disponible',
      },
    ];
    await CatalogService.instance.recargarCarta();
    expect(cartasNotifier.value.map((c) => c.nombrePlato), [
      'Arroz plato prueba',
    ]);
    // Lee categorías, subcategorías, carta y tamaños.
    expect(
      rutas.toSet(),
      containsAll([
        'GET /api/categorias',
        'GET /api/subcategorias',
        'GET /api/carta',
        'GET /api/carta-variantes',
      ]),
    );
  });

  test('un plato que el servidor repite se muestra una sola vez', () async {
    const id = '01925b6a-9b1d-7234-a123-abcdef012345';
    const sub = '01925b6a-9b1d-7234-a123-abcdef0123aa';
    platos = [
      // El mismo plato llega dos veces (una fila por variante con stock).
      {
        'id': id,
        'nombre_plato': 'Arroz',
        'subcategoria_id': sub,
        'estado': 'disponible',
      },
      {
        'id': id,
        'nombre_plato': 'Arroz',
        'subcategoria_id': sub,
        'estado': 'disponible',
      },
      {
        'id': '01925b6a-9b1d-7234-a123-abcdef012399',
        'nombre_plato': 'Sopa',
        'subcategoria_id': sub,
        'estado': 'disponible',
      },
    ];
    await CatalogService.instance.cargarCarta();
    expect(cartasNotifier.value.map((c) => c.nombrePlato), ['Arroz', 'Sopa']);
  });

  test('entre repetidos se prefiere el que no está agotado', () {
    const sub = '01925b6a-9b1d-7234-a123-abcdef0123aa';
    CartaItem plato(String estado) => CartaItem.fromJson({
      'id': 'p1',
      'nombre_plato': 'Arroz',
      'subcategoria_id': sub,
      'estado': estado,
    });
    final unico = quitarPlatosRepetidos([
      plato('agotado'),
      plato('disponible'),
    ]);
    expect(unico, hasLength(1));
    expect(unico.single.agotado, isFalse);
    // Y si el primero ya estaba disponible, no cambia.
    expect(
      quitarPlatosRepetidos([plato('disponible'), plato('agotado')])
          .single
          .agotado,
      isFalse,
    );
  });

  test('si ya hay una recarga en curso no empieza otra, la encola', () async {
    await Future.wait([
      CatalogService.instance.recargarCarta(),
      CatalogService.instance.recargarCarta(),
      CatalogService.instance.recargarCarta(),
    ]);
    // Las llamadas durante una recarga no abren tres lecturas: se junta una sola
    // pasada extra al terminar, para no perder ningún cambio en vivo.
    expect(rutas.where((r) => r == 'GET /api/carta'), hasLength(2));
  });
}
