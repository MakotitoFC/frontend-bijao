import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('la configuración se guarda y se recupera al reiniciar', () async {
    SharedPreferences.setMockInitialValues({});
    final a = Configuracion()
      ..descuentoEmpleadoHabilitado = true
      ..descuentoEmpleadoPorcentaje = 10
      ..cargoDeliveryHabilitado = true
      ..cargoDeliveryMonto = 4.5
      ..propinaSugerida = 12;
    await a.guardar();

    final b = Configuracion(); // "app reiniciada"
    expect(b.descuentoEmpleadoHabilitado, false);
    await b.cargar();
    expect(b.descuentoEmpleadoHabilitado, true);
    expect(b.descuentoEmpleadoPorcentaje, 10);
    expect(b.cargoDeliveryHabilitado, true);
    expect(b.cargoDeliveryMonto, 4.5);
    expect(b.propinaSugerida, 12);
  });
}
