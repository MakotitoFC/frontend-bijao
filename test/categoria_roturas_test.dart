import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/movimientos_caja_store.dart';
import 'package:frontend_bijao/models/movimiento_caja.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/movimiento_caja_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// La categoría "Roturas" de Caja: se usa si existe y, si no se puede crear, los
// movimientos no se pierden (caen en una categoría de ingreso).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    categoriasMovimiento.clear();
  });

  tearDown(categoriasMovimiento.clear);

  test('usa la categoría Roturas si ya existe', () async {
    categoriasMovimiento.add(
      const CategoriaMovimiento(
        id: 'c-rot',
        nombre: 'Roturas',
        tipo: TipoMovimiento.ingreso,
      ),
    );
    final c = await MovimientoCajaService.instance.categoriaAsegurada(
      'roturas',
      TipoMovimiento.ingreso,
    );
    expect(c.id, 'c-rot');
  });

  test(
    'si no existe y no se puede crear, usa una categoría de ingreso',
    () async {
      final c = await MovimientoCajaService.instance.categoriaAsegurada(
        'Roturas',
        TipoMovimiento.ingreso,
      );
      expect(c.tipo, TipoMovimiento.ingreso);
    },
  );
}
