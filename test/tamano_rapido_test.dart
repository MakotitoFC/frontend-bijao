import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/variantes_store.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/carta_variante.dart';
import 'package:frontend_bijao/widgets/tamano_rapido_dialog.dart';

const _plato = CartaItem(
  id: '01925b6a-9b1d-7234-a123-abcdef012345',
  nombrePlato: 'Ceviche',
  descripcion: '',
  categoriaId: 'c',
);

void main() {
  tearDown(variantes.clear);

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TamanoRapidoDialog(plato: _plato)),
      ),
    );
    await tester.pump();
  }

  testWidgets('pide solo nombre y precio y nombra el plato', (tester) async {
    await abrir(tester);
    expect(find.textContaining('Ceviche'), findsOneWidget);
    expect(find.text('Nombre de la variante *'), findsOneWidget);
    expect(find.text('Precio (S/) *'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('sin nombre ni precio válido no se guarda', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Agregar variante'));
    await tester.pump();
    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(find.text('Precio inválido'), findsOneWidget);
  });

  testWidgets('muestra las variantes que el plato ya tiene', (tester) async {
    variantes.add(
      const CartaVariante(
        id: 'v1',
        cartaId: '01925b6a-9b1d-7234-a123-abcdef012345',
        nombre: 'Pequeño',
        precioCliente: 18,
        precioPersonal: 18,
      ),
    );
    await abrir(tester);
    expect(find.textContaining('Ya tiene: Pequeño S/ 18.00'), findsOneWidget);
  });
}
