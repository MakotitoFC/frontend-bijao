import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/taper.dart';
import 'package:frontend_bijao/widgets/selector_taper.dart';
import 'package:frontend_bijao/widgets/taper_catalogo_dialog.dart';

const _plato = '01925b6a-9b1d-7234-a123-abcdef012345';
const _sub = '01925b6a-9b1d-7234-a123-abcdef0123aa';

const _t1 = Taper(id: 't1', nombre: 'Táper chico', precio: 1, stock: 5);
const _t2 = Taper(id: 't2', nombre: 'Táper grande', precio: 2, stock: 0);
const _t3 = Taper(id: 't3', nombre: 'Táper sopa', precio: 3, stock: 9);

void main() {
  group('modelo', () {
    test('sin taper_ids usa el taper_id de siempre', () {
      final i = CartaItem.fromJson({
        'id': _plato,
        'nombre_plato': 'Arroz',
        'subcategoria_id': _sub,
        'taper_id': 't1',
      });
      expect(i.taperIds, ['t1']);
      expect(i.taperId, 't1');
    });

    test('con taper_ids los lee todos y los manda al guardar', () {
      final i = CartaItem.fromJson({
        'id': _plato,
        'nombre_plato': 'Arroz',
        'subcategoria_id': _sub,
        'taper_id': 't1',
        'taper_ids': ['t1', 't2', 't3'],
      });
      expect(i.taperIds, ['t1', 't2', 't3']);
      expect(i.toJson()['taper_ids'], ['t1', 't2', 't3']);
    });
  });

  group('en el pedido el stock se ve pero no bloquea', () {
    testWidgets('el selector deja elegir un táper sin stock', (tester) async {
      Taper? elegido;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SelectorTaper(
                tapers: const [_t1, _t2],
                seleccionado: elegido,
                cantidadNecesaria: 2,
                onElegir: (t) => setState(() => elegido = t),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Stock 5'), findsOneWidget);
      expect(find.text('Stock 0'), findsOneWidget);
      await tester.tap(find.text('Táper grande'));
      await tester.pump();
      expect(elegido?.id, 't2');
      expect(find.textContaining('Igual se puede agregar'), findsOneWidget);
    });

    testWidgets('el selector múltiple marca y desmarca varios tápers', (
      tester,
    ) async {
      final elegidos = <String>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SelectorTaper(
                tapers: const [_t1, _t2, _t3],
                seleccionados: elegidos,
                cantidadNecesaria: 2,
                onAlternar: (t) => setState(() {
                  if (!elegidos.remove(t.id)) elegidos.add(t.id);
                }),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Táper chico'));
      await tester.pump();
      await tester.tap(find.text('Táper sopa'));
      await tester.pump();
      expect(elegidos, {'t1', 't3'});
      expect(find.byIcon(Icons.check_box), findsNWidgets(2));
      // Tocar otra vez lo desmarca.
      await tester.tap(find.text('Táper chico'));
      await tester.pump();
      expect(elegidos, {'t3'});
    });

    testWidgets('cada táper marcado tiene su propia cantidad', (tester) async {
      final elegidos = <String>{'t1', 't3'};
      final cantidades = <String, int>{'t1': 2, 't3': 2};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SelectorTaper(
                tapers: const [_t1, _t2, _t3],
                seleccionados: elegidos,
                cantidadNecesaria: 2,
                cantidades: cantidades,
                onAlternar: (_) {},
                onCantidad: (t, c) => setState(() => cantidades[t.id] = c),
              ),
            ),
          ),
        ),
      );
      // Solo los marcados muestran su cantidad.
      expect(find.text('Cantidad'), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
      expect(cantidades, {'t1': 3, 't3': 2});
    });

    testWidgets('el diálogo Táper muestra el stock y deja pasarse', (
      tester,
    ) async {
      List<TaperElegido>? res;
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  res = await showDialog<List<TaperElegido>>(
                    context: context,
                    builder: (_) =>
                        const TaperCatalogoDialog(tapers: [_t1, _t2]),
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
      expect(find.textContaining('Stock 0'), findsOneWidget);
      // Táper grande tiene stock 0 y igual se puede agregar.
      await tester.tap(find.byTooltip('Agregar uno').last);
      await tester.pump();
      await tester.tap(find.textContaining('Agregar ·'));
      await tester.pumpAndSettle();
      expect(res?.single.taper.id, 't2');
      expect(res?.single.cantidad, 1);
    });
  });
}
