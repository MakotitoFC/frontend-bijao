import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/taper.dart';
import 'package:frontend_bijao/widgets/taper_catalogo_dialog.dart';

const _grande = Taper(id: 't-1', nombre: 'Táper grande', precio: 2);
const _mediano = Taper(id: 't-2', nombre: 'Táper mediano', precio: 1.5);

void main() {
  test(
    'la fila de táper lleva su id del catálogo y el precio del catálogo',
    () {
      final l = lineaDeTaper(_grande, 3);
      expect(l.cartaId, cartaIdTaper);
      expect(l.taperId, 't-1');
      expect(l.nombrePlato, 'Táper grande');
      expect(l.cantidad, 3);
      expect(l.precioUnitario, 2);
      expect(l.precioTotalLinea, 6);
      expect(l.tipoEntrega, 'llevar');
      // Es una fila normal del pedido: no se confunde con un ajuste de la app.
      expect(esLineaTaper(l), isTrue);
      expect(esLineaTupper(l), isFalse);
      expect(esLineaDeProducto(l), isTrue);
    },
  );

  testWidgets('elige cantidades del catálogo y devuelve solo las mayores a 0', (
    tester,
  ) async {
    List<TaperElegido>? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultado = await showDialog<List<TaperElegido>>(
                  context: context,
                  builder: (_) =>
                      const TaperCatalogoDialog(tapers: [_grande, _mediano]),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Táper grande'), findsOneWidget);
    expect(find.text('Táper mediano'), findsOneWidget);
    // Sin cantidades no deja agregar.
    FilledButton boton() =>
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton().onPressed, isNull);

    final mas = find.byTooltip('Agregar uno');
    await tester.tap(mas.first);
    await tester.tap(mas.first);
    await tester.tap(mas.last);
    await tester.pump();
    expect(find.text('Agregar · S/ 5.50'), findsOneWidget); // 2×2.00 + 1×1.50

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(resultado, isNotNull);
    expect(resultado!.map((e) => (e.taper.id, e.cantidad)).toList(), [
      ('t-1', 2),
      ('t-2', 1),
    ]);
  });
}
