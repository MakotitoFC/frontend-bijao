import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/data/categorias_store.dart';
import 'package:frontend_bijao/data/subcategorias_store.dart';
import 'package:frontend_bijao/data/variantes_store.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/carta_variante.dart';
import 'package:frontend_bijao/models/categoria_comida.dart';
import 'package:frontend_bijao/models/subcategoria.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _plato = '01925b6a-9b1d-7234-a123-abcdef012345';
const _sub = '01925b6a-9b1d-7234-a123-abcdef0123aa';
const _cat = '01925b6a-9b1d-7234-a123-abcdef0123bb';
const _varExistente = '01925b6a-9b1d-7234-a123-abcdef0123cc';

CartaItem _item() => const CartaItem(
  id: _plato,
  nombrePlato: 'Ceviche',
  descripcion: '',
  categoriaId: _cat,
  categoriaNombre: 'Marina',
  subcategoriaIds: [_sub],
);

void main() {
  late HttpServer servidor;
  final cuerpos = <Map<String, dynamic>>[];
  final rutas = <String>[];
  // Lo que devuelve el servidor en POST/PUT /api/carta.
  Map<String, dynamic> respuesta = {};

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    cartasNotifier.value = [];
    variantes.clear();
    categorias
      ..clear()
      ..add(const CategoriaComida(id: _cat, categoria: 'Marina'));
    subcategorias
      ..clear()
      ..add(
        const Subcategoria(
          id: _sub,
          subcategoria: 'Pescados',
          categoriaComidaId: _cat,
        ),
      );
    cuerpos.clear();
    rutas.clear();
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
    servidor.listen((req) async {
      final texto = await utf8.decoder.bind(req).join();
      rutas.add('${req.method} ${req.uri.path}');
      if (texto.isNotEmpty) {
        cuerpos.add(jsonDecode(texto) as Map<String, dynamic>);
      }
      req.response
        ..statusCode = req.method == 'POST' ? 201 : 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(respuesta));
      await req.response.close();
    });
  });

  tearDown(() async {
    await servidor.close(force: true);
    cartasNotifier.value = [];
    variantes.clear();
    categorias.clear();
    subcategorias.clear();
  });

  test('crear un plato envía sus tamaños en la misma petición', () async {
    respuesta = {
      'id': _plato,
      'nombre_plato': 'Ceviche',
      'descripcion': '',
      'subcategoria_id': _sub,
      'estado': 'disponible',
      'variantes': [
        {
          'id': _varExistente,
          'carta_id': _plato,
          'nombre': 'Pequeño',
          'precio_cliente': 18,
          'precio_personal': 18,
          'estado': true,
        },
        {
          'id': '01925b6a-9b1d-7234-a123-abcdef0123dd',
          'carta_id': _plato,
          'nombre': 'Grande',
          'precio_cliente': 28,
          'precio_personal': 28,
          'estado': true,
        },
      ],
    };
    await CatalogService.instance.crearPlato(
      _item(),
      variantes: const [
        CartaVariante(
          id: '',
          cartaId: _plato,
          nombre: 'Pequeño',
          precioCliente: 18,
          precioPersonal: 18,
        ),
        CartaVariante(
          id: '',
          cartaId: _plato,
          nombre: 'Grande',
          precioCliente: 28,
          precioPersonal: 28,
        ),
      ],
    );

    // Una sola petición, con los dos tamaños y sin id (son nuevos).
    expect(rutas, ['POST /api/carta']);
    final enviados = cuerpos.single['variantes'] as List;
    expect(enviados, hasLength(2));
    expect((enviados.first as Map).containsKey('id'), isFalse);
    expect((enviados.first as Map)['nombre'], 'Pequeño');
    expect((enviados.last as Map)['precio_cliente'], 28);
    // Los tamaños que devuelve el servidor quedan en la lista de la app.
    expect(variantesDeCarta(_plato).map((v) => v.nombre), [
      'Pequeño',
      'Grande',
    ]);
  });

  test('sin tamaños no se envía la clave `variantes`', () async {
    respuesta = {
      'id': _plato,
      'nombre_plato': 'Ceviche',
      'subcategoria_id': _sub,
      'estado': 'disponible',
    };
    await CatalogService.instance.crearPlato(_item());
    expect(cuerpos.single.containsKey('variantes'), isFalse);
  });

  test('editar manda el id del tamaño que ya existía y lo desactiva', () async {
    respuesta = {
      'id': _plato,
      'nombre_plato': 'Ceviche',
      'subcategoria_id': _sub,
      'estado': 'disponible',
    };
    await CatalogService.instance.actualizarPlato(
      _item(),
      variantes: const [
        CartaVariante(
          id: _varExistente,
          cartaId: _plato,
          nombre: 'Pequeño',
          precioCliente: 18,
          precioPersonal: 18,
          estado: false,
        ),
      ],
    );
    final v = (cuerpos.single['variantes'] as List).single as Map;
    expect(v['id'], _varExistente);
    expect(v['estado'], false);
  });

  test('al cargar la carta, los tamaños vienen dentro de cada plato', () async {
    respuesta = {};
    // GET /api/carta devuelve una lista.
    await servidor.close(force: true);
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
    servidor.listen((req) async {
      req.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode([
            {
              'id': _plato,
              'nombre_plato': 'Ceviche',
              'subcategoria_id': _sub,
              'categoria_comida_id': _cat,
              'estado': 'disponible',
              'variantes': [
                {
                  'id': _varExistente,
                  'nombre': 'Personal',
                  'precio_cliente': 25,
                  'precio_personal': 25,
                  'estado': true,
                },
              ],
            },
          ]),
        );
      await req.response.close();
    });
    await CatalogService.instance.cargarCarta();
    final v = variantesDeCarta(_plato).single;
    expect(v.nombre, 'Personal');
    expect(v.cartaId, _plato);
    expect(v.precioCliente, 25);
  });
}
