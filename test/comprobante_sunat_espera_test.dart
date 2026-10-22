import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/comprobante.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/widgets/comprobante_en_cobro.dart';

final _pedido = Pedido(
  id: 'p1',
  numeroPedido: '0007',
  mesaNumero: 2,
  tipoPedido: 'mesa',
  estado: 'pagado',
  fechaPedido: DateTime(2026, 10, 21, 14, 0),
  usuarioId: 'u1',
);

Comprobante _comp(String estado, {String tipo = 'boleta'}) =>
    Comprobante.fromJson({
      'id': 'c1',
      'pedidos_id': 'p1',
      'tipo_documento': tipo,
      'numero_comprobante': 'B001-00000007',
      'total': 52,
      'estado_sunat': estado,
    });

void main() {
  late List<String> llamadas;
  late List<String> respuestas;

  setUp(() {
    llamadas = [];
    respuestas = [];
    esperaEntreConsultas = const Duration(milliseconds: 50);
    consultarEstadoComprobante = (id) async {
      llamadas.add('consultar');
      final e = respuestas.isEmpty ? 'PENDIENTE' : respuestas.removeAt(0);
      return _comp(e);
    };
    imprimirComprobante = (id) async => llamadas.add('imprimir');
  });

  tearDown(() {
    esperaEntreConsultas = const Duration(seconds: 2);
  });

  Future<void> abrir(
    WidgetTester tester,
    Comprobante c, {
    bool imprimir = true,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComprobanteEmitidoDialog(
            comprobante: c,
            pedido: _pedido,
            imprimirAlConfirmar: imprimir,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('pendiente: espera a SUNAT y recién entonces imprime', (
    tester,
  ) async {
    respuestas = ['PENDIENTE', 'ACEPTADO'];
    await abrir(tester, _comp('PENDIENTE'));
    expect(find.text('Esperando la respuesta de SUNAT…'), findsOneWidget);
    // Mientras no responde, no se imprime nada.
    expect(llamadas.contains('imprimir'), isFalse);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(llamadas.where((l) => l == 'imprimir'), isEmpty);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    await tester.pump();
    expect(find.text('Esperando la respuesta de SUNAT…'), findsNothing);
    expect(llamadas.where((l) => l == 'imprimir'), hasLength(1));
  });

  testWidgets('ya aceptado: imprime de una vez y una sola vez', (tester) async {
    await abrir(tester, _comp('ACEPTADO'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(llamadas, ['imprimir']);
  });

  testWidgets('rechazado por SUNAT: no se imprime', (tester) async {
    respuestas = ['RECHAZADO'];
    await abrir(tester, _comp('PENDIENTE'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    await tester.pump();
    expect(llamadas.where((l) => l == 'imprimir'), isEmpty);
    expect(find.text('Esperando la respuesta de SUNAT…'), findsNothing);
  });

  testWidgets('sin pedir impresión no imprime aunque SUNAT responda', (
    tester,
  ) async {
    respuestas = ['ACEPTADO'];
    await abrir(tester, _comp('PENDIENTE'), imprimir: false);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    await tester.pump();
    expect(llamadas.where((l) => l == 'imprimir'), isEmpty);
  });

  testWidgets(
    'si SUNAT no responde a tiempo queda guardado y se puede reintentar',
    (tester) async {
      await abrir(tester, _comp('PENDIENTE'));
      // 10 consultas sin respuesta.
      for (var i = 0; i < 11; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pump();
      expect(find.text('Esperando la respuesta de SUNAT…'), findsNothing);
      expect(find.text('Consultar de nuevo'), findsOneWidget);
      expect(llamadas.where((l) => l == 'imprimir'), isEmpty);

      respuestas = ['ACEPTADO'];
      await tester.tap(find.text('Consultar de nuevo'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
      await tester.pump();
      expect(llamadas.where((l) => l == 'imprimir'), hasLength(1));
    },
  );
}
