import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('la configuración se guarda y se recupera al reiniciar', () async {
    SharedPreferences.setMockInitialValues({});
    final a = Configuracion()..propinaSugerida = 12;
    await a.guardar();

    final b = Configuracion(); // "app reiniciada"
    await b.cargar();
    expect(b.propinaSugerida, 12);
  });
}
