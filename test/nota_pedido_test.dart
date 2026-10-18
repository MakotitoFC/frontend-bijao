import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/utils/nota_pedido.dart';
import 'package:frontend_bijao/widgets/detalle_pedido_panel.dart';

Pedido _pedido({String? notas, String estado = 'pendiente'}) => Pedido(
  id: 'p1',
  numeroPedido: '1',
  mesaNumero: 2,
  tipoPedido: 'mesa',
  estado: estado,
  fechaPedido: DateTime(2026, 10, 17, 13),
  usuarioId: 'u1',
  notas: notas,
);

void main() {
  group('nota general y nombre del cliente', () {
    test('la nota no incluye la línea "Cliente:" del backend', () {
      expect(notaGeneralDe('Cliente: Ana\nsin picante'), 'sin picante');
      expect(notaGeneralDe('Cliente: Ana'), isNull);
      expect(notaGeneralDe('solo nota'), 'solo nota');
      expect(notaGeneralDe(null), isNull);
      expect(notaGeneralDe('  '), isNull);
    });

    test('al guardar se conserva el nombre del cliente', () {
      expect(
        comentariosConNota('Cliente: Ana\nvieja', 'nueva'),
        'Cliente: Ana\nnueva',
      );
      expect(comentariosConNota('Cliente: Ana\nvieja', ''), 'Cliente: Ana');
      expect(comentariosConNota(null, 'hola'), 'hola');
      expect(comentariosConNota('vieja', null), isNull);
      expect(comentariosConNota(null, '  '), isNull);
    });

    test('la nota local se guarda y se quita', () {
      pedidos
        ..clear()
        ..add(_pedido());
      actualizarNotaPedido('p1', 'cumpleaños');
      expect(pedidos.single.notas, 'cumpleaños');
      actualizarNotaPedido('p1', '');
      expect(pedidos.single.notas, isNull);
      pedidos.clear();
    });
  });

  Future<void> pintar(WidgetTester tester, Pedido p) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pedidos
      ..clear()
      ..add(p);
    detallesPorPedido[p.id] = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetallePedidoPanel(pedido: p, onCambio: () {}, esAdmin: false),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('el panel muestra la nota del pedido y permite agregarla', (
    tester,
  ) async {
    await pintar(tester, _pedido());
    expect(find.text('Nota del pedido'), findsOneWidget);
    expect(find.textContaining('Sin nota'), findsOneWidget);

    await tester.tap(find.text('Nota del pedido'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    // El diálogo trae el campo y el botón de guardar.
    expect(find.text('Guardar nota'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'cliente alérgico');
    await tester.tap(find.text('Guardar nota'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(pedidos.single.notas, 'cliente alérgico');
    pedidos.clear();
    detallesPorPedido.clear();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('con nota se ve su texto (sin la línea del cliente)', (
    tester,
  ) async {
    await pintar(tester, _pedido(notas: 'Cliente: Ana\nllevar todo junto'));
    expect(find.text('llevar todo junto'), findsOneWidget);
    expect(find.textContaining('Cliente:'), findsNothing);
    pedidos.clear();
    detallesPorPedido.clear();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'un pedido ya cobrado no se puede editar ni muestra el aviso vacío',
    (tester) async {
      await pintar(tester, _pedido(estado: 'pagado'));
      expect(find.text('Nota del pedido'), findsNothing);
      pedidos.clear();
      detallesPorPedido.clear();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
