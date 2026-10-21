import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/utils/whatsapp_cuenta.dart';
import 'package:frontend_bijao/widgets/boton_imprimir_whatsapp.dart';
import 'package:frontend_bijao/widgets/whatsapp_cuenta_dialog.dart';

Pedido _pedido({String? celular}) => Pedido(
  id: 'p1',
  numeroPedido: '0007',
  mesaNumero: 5,
  tipoPedido: 'mesa',
  estado: 'servido',
  fechaPedido: DateTime(2026, 10, 19, 14, 0),
  usuarioId: 'u1',
  clienteNombre: 'Ana',
  clienteCelular: celular,
);

const _ceviche = PedidoLine(
  id: 'l1',
  cartaId: 'c1',
  nombrePlato: 'Ceviche',
  cantidad: 2,
  modificadores: [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: 20,
  descuentoAplicado: 0,
  precioTotalLinea: 40,
);

void main() {
  group('numeroWhatsapp', () {
    test('un celular de 9 dígitos recibe el código de Perú', () {
      expect(numeroWhatsapp('987 654 321'), '51987654321');
      expect(numeroWhatsapp('987-654-321'), '51987654321');
    });

    test('un número que ya trae código de país se respeta', () {
      expect(numeroWhatsapp('+51 987654321'), '51987654321');
      expect(numeroWhatsapp('573001234567'), '573001234567');
    });

    test('vacío o demasiado corto no es válido', () {
      expect(numeroWhatsapp(null), isNull);
      expect(numeroWhatsapp(''), isNull);
      expect(numeroWhatsapp('12345'), isNull);
      // 9 dígitos que no empiezan en 9 no son un celular peruano.
      expect(numeroWhatsapp('187654321'), isNull);
    });
  });

  test('el enlace lleva el número y el mensaje codificado', () {
    final url = urlWhatsapp('51987654321', 'Hola & chau\n*TOTAL*');
    expect(url.host, 'api.whatsapp.com');
    expect(url.path, '/send');
    expect(url.queryParameters['phone'], '51987654321');
    expect(url.queryParameters['text'], 'Hola & chau\n*TOTAL*');
  });

  test('los íconos viajan en UTF-8 y los espacios como %20', () {
    const mensaje = '🚀 *PEDIDO: #0007* 🚀\n💵 S/ 1';
    final url = urlWhatsapp('51987654321', mensaje);
    expect(url.toString(), contains('%F0%9F%9A%80%20'));
    expect(url.toString(), isNot(contains('+')));
    expect(url.queryParameters['text'], mensaje);
  });

  group('textoCuentaWhatsapp', () {
    test('lista los productos y el total', () {
      final texto = textoCuentaWhatsapp(
        pedido: _pedido(),
        lineas: const [_ceviche],
      );
      expect(texto, contains('🚀 *PEDIDO: #0007* 🚀'));
      expect(texto, contains('📅 19/10/2026, 02:00 p. m.'));
      expect(texto, contains('🪑 *Atención:* Mesa 5'));
      expect(texto, contains('*Nombre:* Ana'));
      expect(texto, contains('🔸 *2x Ceviche*'));
      expect(texto, contains('   💵 S/ 40.00'));
      expect(texto, contains('Subtotal: S/ 40.00'));
      expect(texto, contains('🔥 *TOTAL: S/ 40.00* 🔥'));
      expect(texto, contains('💳 Pago: PENDIENTE DE PAGO'));
      expect(texto, contains('🙌 ¡Gracias por tu compra!'));
      expect(texto, isNot(contains('Recargo')));
    });

    test('con tarjeta suma el recargo al total a pagar', () {
      final texto = textoCuentaWhatsapp(
        pedido: _pedido(),
        lineas: const [_ceviche],
        metodoPago: 'Tarjeta',
        recargo: 1.6,
      );
      expect(texto, contains('Total de la cuenta: S/ 40.00'));
      expect(texto, contains('Recargo por pago con tarjeta: S/ 1.60'));
      expect(texto, contains('*TOTAL A PAGAR: S/ 41.60*'));
    });

    test('un pedido pagado muestra el método en mayúsculas', () {
      final texto = textoCuentaWhatsapp(
        pedido: _pedido(),
        lineas: const [_ceviche],
        metodoPago: 'Efectivo',
        pagado: 40,
      );
      expect(texto, contains('💳 Pago: EFECTIVO'));
      expect(texto, isNot(contains('PENDIENTE')));
      expect(texto, isNot(contains('Saldo pendiente')));
    });

    test('un pago parcial muestra lo pagado y el saldo', () {
      final texto = textoCuentaWhatsapp(
        pedido: _pedido(),
        lineas: const [_ceviche],
        pagado: 15,
      );
      expect(texto, contains('Pagado: S/ 15.00'));
      expect(texto, contains('⚠️ *Saldo pendiente: S/ 25.00*'));
    });
  });

  testWidgets('un solo botón con dos mitades: impresora y WhatsApp', (
    tester,
  ) async {
    var imprimir = 0;
    var whatsapp = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: BotonImprimirWhatsapp(
                onImprimir: () => imprimir++,
                onWhatsapp: () => whatsapp++,
              ),
            ),
          ),
        ),
      ),
    );
    // Dos mitades en el mismo botón.
    expect(find.byType(BotonImprimirWhatsapp), findsOneWidget);
    expect(find.byType(IconoWhatsapp), findsOneWidget);

    await tester.tap(find.byType(IconoWhatsapp));
    expect(whatsapp, 1);
    expect(imprimir, 0);

    await tester.tapAt(
      tester.getTopLeft(find.byType(BotonImprimirWhatsapp)) +
          const Offset(20, 20),
    );
    expect(imprimir, 1);
    expect(whatsapp, 1);
  });

  group('WhatsappCuentaDialog', () {
    Future<void> abrir(WidgetTester tester, {String? celular}) async {
      String? resultado;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  resultado = await showDialog<String>(
                    context: context,
                    builder: (_) =>
                        WhatsappCuentaDialog(celularInicial: celular),
                  );
                },
                child: Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      addTearDown(() => resultado);
    }

    FilledButton boton(WidgetTester tester) => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Abrir WhatsApp'),
        matching: find.byType(FilledButton),
      ),
    );

    testWidgets('con el celular del pedido ya escrito deja enviar', (
      tester,
    ) async {
      await abrir(tester, celular: '987654321');
      expect(boton(tester).onPressed, isNotNull);
    });

    testWidgets('sin celular, o con uno inválido, no deja enviar', (
      tester,
    ) async {
      await abrir(tester);
      expect(boton(tester).onPressed, isNull);

      await tester.enterText(find.byType(EditableText), '123');
      await tester.pump();
      expect(boton(tester).onPressed, isNull);
      expect(find.textContaining('celular válido'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), '912345678');
      await tester.pump();
      expect(boton(tester).onPressed, isNotNull);
    });
  });
}
