import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/utils/blur_dialog.dart';
import 'package:frontend_bijao/widgets/producto_opciones_dialog.dart';
import 'package:frontend_bijao/widgets/texto_adaptable.dart';
import 'package:shared_preferences/shared_preferences.dart';

// El texto usa su versión larga si cabe, la corta si no, y se achica antes de
// cortarse con "…". (Las pruebas dibujan con una letra ancha: es el peor caso.)
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
  });

  Future<void> pintar(WidgetTester tester, double ancho) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: ancho,
            child: const TextoAdaptable(
              textos: ['PARA LLEVAR', 'LLEVAR'],
              style: TextStyle(fontSize: 10),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('con espacio usa el texto largo', (tester) async {
    await pintar(tester, 300);
    expect(find.text('PARA LLEVAR'), findsOneWidget);
    expect(find.text('LLEVAR'), findsNothing);
  });

  testWidgets('si el largo no cabe, usa el corto', (tester) async {
    await pintar(tester, 80);
    expect(find.text('PARA LLEVAR'), findsNothing);
    expect(find.text('LLEVAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('si ni el corto cabe, se achica sin desbordar', (tester) async {
    await pintar(tester, 30);
    expect(find.text('LLEVAR'), findsOneWidget);
    expect(find.byType(FittedBox), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('modal del producto en celular: los botones de entrega no '
      'desbordan', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBlurDialog<ProductoConfigurado>(
                context: context,
                builder: (_) => const ProductoOpcionesDialog(
                  item: CartaItem(
                    id: 'c1',
                    nombrePlato: 'Gaseosa 2 LT',
                    descripcion: '',
                    categoriaId: 'k',
                    precioCliente: 8,
                    stock: 10,
                  ),
                  esAdmin: false,
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
    // Con tan poco ancho el botón usa "LLEVAR" en vez de cortarse con "…".
    expect(find.text('PARA LLEVAR'), findsNothing);
    expect(find.text('LLEVAR'), findsOneWidget);
  });

  testWidgets(
    'con ajustarAncho el icono y el texto quedan juntos y centrados',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.restaurant, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: TextoAdaptable(
                        ajustarAncho: true,
                        textos: ['EN MESA', 'MESA'],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final icono = tester.getRect(find.byIcon(Icons.restaurant));
      final texto = tester.getRect(find.text('EN MESA'));
      // Pegados (solo el espacio de 6 px) y el conjunto en el centro de los 300 px.
      expect(texto.left - icono.right, lessThan(8));
      final centro = (icono.left + texto.right) / 2;
      expect(
        (centro - tester.getCenter(find.byType(SizedBox).first).dx).abs(),
        lessThan(2),
      );
    },
  );
}
