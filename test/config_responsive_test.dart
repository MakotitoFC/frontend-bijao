import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/plantillas_impresion_editor.dart';
import 'package:frontend_bijao/widgets/reglas_cocina_config.dart';
import 'package:frontend_bijao/widgets/sede_fiscal_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Páginas de Configuración con el tema real, en celular (320 y 375), tablet y
// escritorio y con la
// letra del sistema al 100 % y al 140 %: sin desbordes. Primero celular.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
  });

  final paginas = <String, Widget Function()>{
    'Sede y Facturación': () => const SedeFiscalConfig(),
    'Impresión en cocina': () => const ReglasCocinaConfig(),
    'Plantillas de impresión': () => const PlantillasImpresionEditor(),
  };

  for (final e in paginas.entries) {
    for (final tam in const [
      Size(320, 640),
      Size(375, 812),
      Size(768, 1024),
      Size(1400, 900),
    ]) {
      for (final letra in [1.0, 1.4]) {
        testWidgets(
          '${e.key} en ${tam.width.round()} px con letra al ${(letra * 100).round()} %',
          (tester) async {
            tester.view.physicalSize = tam;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(letra)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: e.value(),
                  ),
                ),
              ),
            );
            for (var i = 0; i < 4; i++) {
              await tester.pump(const Duration(milliseconds: 300));
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
