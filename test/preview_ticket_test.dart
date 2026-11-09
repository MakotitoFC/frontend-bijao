import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/preview_ticket_service.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/utils/ticket_texto.dart';
import 'package:frontend_bijao/widgets/boleta_pedido_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

// La vista previa de la cuenta muestra lo que imprime el servidor; si el servidor
// no la ofrece, la app avisa que es aproximada y muestra la suya.
const _pedidoId = '01925b6a-9b1d-7234-a123-abcdef012345';

final _respuesta = {
  'ancho': 48,
  'logo_url': '/api/v1/impresion/config/logo',
  'lineas': [
    {
      'texto': 'CUENTA DE CONSUMO',
      'alineacion': 'centro',
      'negrita': true,
      'doble': true,
    },
    {'texto': 'ORDEN: #0006', 'alineacion': 'centro'},
    {'texto': 'Mozo:            Ana', 'alineacion': 'izquierda'},
    {'texto': 'TOTAL: S/    32.00', 'alineacion': 'derecha', 'negrita': true},
    {'texto': '', 'alineacion': 'centro', 'qr': 'https://ejemplo.pe/qr'},
  ],
};

Pedido _pedido() => Pedido(
  id: _pedidoId,
  numeroPedido: '0006',
  mesaNumero: 0,
  tipoPedido: 'llevar',
  estado: 'pendiente',
  fechaPedido: DateTime(2026, 11, 8, 13),
  usuarioId: 'u1',
);

void main() {
  group('lectura de la respuesta', () {
    test('convierte las líneas con su alineación, negrita y tamaño', () {
      final p = PreviewTicket.deJson(_respuesta)!;
      expect(p.conLogo, isTrue);
      expect(p.lineas.length, 5);
      expect(p.lineas[0].texto, 'CUENTA DE CONSUMO');
      expect(p.lineas[0].alineacion, AlineacionTicket.centro);
      expect(p.lineas[0].negrita, isTrue);
      expect(p.lineas[0].doble, isTrue);
      expect(p.lineas[2].alineacion, AlineacionTicket.izquierda);
      expect(p.lineas[3].alineacion, AlineacionTicket.derecha);
      // El QR queda en su lugar, como línea de código.
      expect(p.lineas[4].qr, 'https://ejemplo.pe/qr');
    });

    test('sin logo y con respuestas inválidas', () {
      final sinLogo = PreviewTicket.deJson({
        'lineas': [
          {'texto': 'A'},
        ],
      })!;
      expect(sinLogo.conLogo, isFalse);
      expect(PreviewTicket.deJson(null), isNull);
      expect(PreviewTicket.deJson({'lineas': []}), isNull);
      expect(PreviewTicket.deJson('algo'), isNull);
    });
  });

  group('en la cuenta del pedido', () {
    late List<String> pedidas;
    PreviewTicket? respuesta;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ApiClient.instance.initialize();
      pedidas = [];
      respuesta = PreviewTicket.deJson(_respuesta);
      pedidos
        ..clear()
        ..add(_pedido());
      // Sin red: la lectura del servidor se sustituye en la prueba.
      PreviewTicketService.instance.lectorCuentaDePrueba = (id) async {
        pedidas.add(id);
        return respuesta;
      };
    });

    tearDown(() {
      PreviewTicketService.instance.lectorCuentaDePrueba = null;
      pedidos.clear();
    });

    Future<void> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BoletaPedidoDialog(
                pedido: _pedido(),
                mesero: 'Ana',
                titulo: 'Cuenta',
                metodoPago: 'Sin pago',
                onImprimir: () {},
                onCerrar: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('muestra el ticket que arma el servidor', (tester) async {
      await abrir(tester);
      expect(pedidas, [_pedidoId]);
      expect(find.textContaining('ORDEN: #0006'), findsOneWidget);
      expect(find.textContaining('TOTAL: S/    32.00'), findsOneWidget);
      expect(find.textContaining('Vista aproximada'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('si el servidor no lo ofrece, avisa que es aproximada', (
      tester,
    ) async {
      respuesta = null;
      await abrir(tester);
      expect(find.textContaining('Vista aproximada'), findsOneWidget);
      // Sigue mostrando la cuenta de la app.
      expect(find.textContaining('CUENTA DE CONSUMO'), findsWidgets);
      expect(find.textContaining('ORDEN: #0006'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
