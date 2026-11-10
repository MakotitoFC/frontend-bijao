import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/inventario/inventario_comun.dart';

// Páginas de lista de Inventario: cabecera y barra fijas arriba, paginador fijo
// abajo y solo se desplazan las filas.
void main() {
  Widget pagina(int n) => MaterialApp(
    home: Scaffold(
      body: PaginaListaFija(
        cabecera: const Text('Productos'),
        barra: const Text('Barra de búsqueda'),
        filas: [
          for (var i = 0; i < n; i++)
            SizedBox(height: 60, child: Text('Fila $i')),
        ],
      ),
    ),
  );

  testWidgets('muestra 8 filas y el paginador fijo al pie', (tester) async {
    tester.view.physicalSize = const Size(900, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(pagina(20));
    expect(find.text('Productos'), findsOneWidget);
    expect(find.text('Barra de búsqueda'), findsOneWidget);
    expect(find.text('Mostrando 1-8 de 20'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    // Al desplazar la lista, la cabecera y el paginador siguen a la vista.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    expect(find.text('Productos'), findsOneWidget);
    expect(find.text('Mostrando 1-8 de 20'), findsOneWidget);

    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pump();
    expect(find.text('Mostrando 9-16 de 20'), findsOneWidget);
    expect(find.text('Fila 8'), findsOneWidget);
    expect(find.text('Fila 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin filas muestra el mensaje y 0 de 0', (tester) async {
    tester.view.physicalSize = const Size(900, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(pagina(0));
    expect(find.text('No hay registros.'), findsOneWidget);
    expect(find.text('Mostrando 0 de 0'), findsOneWidget);
  });
}
