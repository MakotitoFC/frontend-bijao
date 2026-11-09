import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/utils/nota_pedido.dart';
import 'package:frontend_bijao/widgets/propina_dialog.dart';

// La propina: modal solo en soles (un input con "S/."), guardada en las notas del
// pedido para que viaje a otros equipos.
void main() {
  group('PropinaDialog', () {
    Future<double?> abrir(WidgetTester tester, {double actual = 0}) async {
      double? resultado = -1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => resultado = await showDialog<double>(
                  context: context,
                  builder: (_) => Dialog(child: PropinaDialog(actual: actual)),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return resultado;
    }

    testWidgets('solo un input en soles, sin porcentajes', (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await abrir(tester);
      expect(find.text('Propina'), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);
      // El placeholder es "S/." y no hay porcentajes sugeridos.
      expect(find.text('S/.'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      // Sin monto, "Aplicar" no hace nada.
      final aplicar = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Aplicar'),
      );
      expect(aplicar.onPressed, isNull);
      expect(find.text('Quitar'), findsNothing);
    });

    testWidgets('en celular el input no se corta: toma el alto de su texto', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await abrir(tester, actual: 4.5);
      final alto = tester.getSize(find.byType(TextField)).height;
      // Letra de 13.5 px con 12 px de margen arriba y abajo: más de 36 px.
      expect(alto, greaterThan(38));
      expect(find.text('4.50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con una propina puesta se puede cambiar o quitar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await abrir(tester, actual: 4);
      expect(find.text('4.00'), findsOneWidget);
      expect(find.text('Quitar'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '5.5');
      await tester.pump();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
    });
  });

  group('la propina viaja en las notas del pedido', () {
    test('se guarda como una línea y no toca el resto de la nota', () {
      expect(comentariosConPropina(null, 4), 'Propina: 4.00');
      expect(comentariosConPropina('Sin ají', 3.5), 'Sin ají\nPropina: 3.50');
      // Cambiar la propina reemplaza la línea, no la duplica.
      expect(
        comentariosConPropina('Sin ají\nPropina: 3.50', 5),
        'Sin ají\nPropina: 5.00',
      );
      // Quitarla deja solo la nota.
      expect(comentariosConPropina('Sin ají\nPropina: 3.50', 0), 'Sin ají');
      expect(comentariosConPropina('Propina: 3.50', 0), isNull);
    });

    test('se lee desde las notas', () {
      expect(propinaEnComentarios('Cliente: Maria\nPropina: 4.00'), 4.0);
      expect(propinaEnComentarios('Propina: 2,5'), 2.5);
      expect(propinaEnComentarios('Sin ají'), isNull);
      expect(propinaEnComentarios(null), isNull);
      expect(propinaEnComentarios('Propina: abc'), isNull);
    });

    test('la nota que ve el usuario no muestra la línea de la propina', () {
      expect(notaGeneralDe('Sin ají\nPropina: 4.00'), 'Sin ají');
      expect(notaGeneralDe('Propina: 4.00'), isNull);
      expect(sinLineaDePropina('Cliente: Ana\nPropina: 4.00'), 'Cliente: Ana');
      // Al editar la nota, la propina y el cliente se conservan.
      expect(
        comentariosConNota('Cliente: Ana\nPropina: 4.00', 'Sin sal'),
        'Cliente: Ana\nPropina: 4.00\nSin sal',
      );
    });

    test('al leer los pedidos del servidor, caja recibe la propina', () {
      pedidos.clear();
      detallesPorPedido.clear();
      final p = Pedido(
        id: 'p1',
        numeroPedido: '1',
        mesaNumero: 0,
        tipoPedido: 'llevar',
        estado: 'pendiente',
        fechaPedido: DateTime(2026, 11, 8, 13),
        usuarioId: 'u1',
        notas: 'Sin ají\nPropina: 4.00',
      );
      sincronizarPedidosDesdeServidor([p], {'p1': []});
      expect(propinaDePedido('p1'), 4.0);
      pedidos.clear();
      detallesPorPedido.clear();
    });
  });
}
