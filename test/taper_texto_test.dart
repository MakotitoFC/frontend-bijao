import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/taper.dart';
import 'package:frontend_bijao/services/catalog_service.dart';
import 'package:frontend_bijao/utils/taper_texto.dart';

CartaItem _plato(Map<String, dynamic> extra) => CartaItem.fromJson({
  'id': 'c1',
  'nombre_plato': 'Ceviche',
  'descripcion': '',
  'estado': 'disponible',
  'precio_cliente': 20,
  ...extra,
});

void main() {
  tearDown(() => CatalogService.instance.tapers.clear());

  test('sin táper no hay texto', () {
    expect(textoTaperDePlato(_plato({})), isNull);
  });

  test('con táper en el catálogo: nombre y precio', () {
    CatalogService.instance.tapers.add(
      const Taper(id: 't1', nombre: 'Táper grande', precio: 2),
    );
    expect(
      textoTaperDePlato(_plato({'taper_id': 't1'})),
      'Táper grande · S/ 2.00',
    );
  });

  test('catálogo sin cargar: usa el nombre que trae el plato', () {
    expect(
      textoTaperDePlato(_plato({'taper_id': 't1', 'taper_nombre': 'Táper'})),
      'Táper',
    );
  });

  test('varios tápers: la cantidad', () {
    expect(
      textoTaperDePlato(
        _plato({
          'taper_ids': ['t1', 't2'],
        }),
      ),
      '2 tápers',
    );
  });
}
