import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/comprobante_en_cobro.dart';

Map<String, dynamic> _i(String n, int c, double pu) => {
  'nombre': n,
  'cantidad': c,
  'precio_unitario': pu,
  'subtotal': c * pu,
};

void main() {
  test('productos iguales se juntan y el total no cambia', () {
    final entrada = [
      _i('AGUA', 1, 4),
      _i('Táper - Grande', 1, 2),
      _i('Táper - Pequeño', 1, 1),
      _i('ANIS', 1, 4),
      _i('Táper - Grande', 1, 2),
      _i('Táper - Pequeño', 1, 1),
      _i('ARROZ A LA CUBANA', 1, 12),
      _i('Táper - Grande', 1, 2),
      _i('Táper - Pequeño', 1, 1),
    ];
    final sal = agruparItemsIguales(entrada);
    expect(sal.length, 5);
    final grande = sal.firstWhere((x) => x['nombre'] == 'Táper - Grande');
    expect(grande['cantidad'], 3);
    expect(grande['subtotal'], 6);
    double suma(List<Map<String, dynamic>> l) =>
        l.fold(0.0, (s, x) => s + (x['subtotal'] as num));
    expect(suma(sal), suma(entrada));
    expect(suma(sal), 29);
  });

  test('otro precio y los cargos sueltos no se juntan', () {
    final sal = agruparItemsIguales([
      _i('AGUA', 1, 4),
      _i('AGUA', 1, 5),
      _i('ROTURA: Plato', 1, 5),
      _i('ROTURA: Plato', 1, 5),
    ]);
    expect(sal.length, 4);
  });
}
