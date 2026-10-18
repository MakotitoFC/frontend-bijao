import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/carta_variante.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/utils/monto_letras.dart';
import 'package:frontend_bijao/utils/ticket_texto.dart';
import 'package:frontend_bijao/widgets/boleta_pedido_dialog.dart';
import 'package:frontend_bijao/widgets/ticket_papel.dart';

Pedido _pedido({String tipo = 'mesa', String? notas}) => Pedido(
  id: 'p1',
  numeroPedido: '0007',
  mesaNumero: tipo == 'mesa' ? 2 : 0,
  tipoPedido: tipo,
  estado: 'pendiente',
  fechaPedido: DateTime(2026, 10, 17, 16, 20, 5),
  usuarioId: 'u1',
  notas: notas,
);

PedidoLine _linea({
  String id = 'l1',
  String nombre = 'Juane Especial de Gallina',
  int cantidad = 1,
  double precio = 25,
  String? comentario,
  String tipoEntrega = 'mesa',
  CartaVariante? variante,
}) => PedidoLine(
  id: id,
  cartaId: 'c-$id',
  nombrePlato: nombre,
  cantidad: cantidad,
  modificadores: const [],
  presentacion: null,
  promocion: null,
  comentario: comentario,
  precioUnitario: precio,
  descuentoAplicado: 0,
  precioTotalLinea: precio * cantidad,
  tipoEntrega: tipoEntrega,
  variante: variante,
);

String _texto(List<LineaTicket> t) => t.map((l) => l.texto).join('\n');

void main() {
  group('texto de los tickets', () {
    test('padLinea alinea a la derecha y respeta las 48 columnas', () {
      final l = padLinea('SUBTOTAL', 'S/ 56.00');
      expect(l.length, anchoTicket);
      expect(l.startsWith('SUBTOTAL'), true);
      expect(l.endsWith('S/ 56.00'), true);
      // Si la izquierda es muy larga, se recorta y sigue cabiendo.
      expect(padLinea('x' * 80, 'S/ 1.00').length, anchoTicket);
    });

    test('envolver no corta palabras y respeta el ancho', () {
      final r = envolver('uno dos tres cuatro cinco seis siete', 12);
      expect(r.every((x) => x.length <= 12), true);
      expect(r.join(' '), 'uno dos tres cuatro cinco seis siete');
      // Una palabra más larga que el ancho se parte.
      expect(envolver('a' * 30, 10).every((x) => x.length <= 10), true);
      // La sangría de los renglones siguientes cuenta dentro del ancho.
      final s = envolver('uno dos tres cuatro cinco', 14, sangria: '  ');
      expect(s.every((x) => x.length <= 14), true);
      expect(s.skip(1).every((x) => x.startsWith('  ')), true);
    });

    test('la comanda no lleva precios y trae lo que cocina necesita', () {
      final t = ticketComanda(
        pedido: _pedido(notas: 'Cliente: Ana\nTraer servilletas adicionales'),
        lineas: [
          _linea(comentario: 'Sin aceituna'),
          _linea(
            id: 'l2',
            nombre: 'Tacacho con Cecina',
            cantidad: 2,
            tipoEntrega: 'llevar',
            variante: const CartaVariante(
              id: 'v',
              cartaId: 'c',
              nombre: 'Grande',
              precioCliente: 1,
              precioPersonal: 1,
            ),
          ),
        ],
        mozo: 'Joel',
      );
      final texto = _texto(t);
      expect(texto, contains('*** COMANDA COCINA ***'));
      expect(texto, contains('ORDEN #0007'));
      expect(texto, contains('MESA: 02  (SALON)'));
      expect(texto, contains('Mozo: Joel'));
      expect(texto, contains('Fecha: 17/10/2026 16:20:05'));
      expect(texto, contains('NOTA PEDIDO: Traer servilletas adicionales'));
      // El nombre del cliente que guarda el backend no es una nota.
      expect(texto, isNot(contains('Cliente: Ana')));
      expect(texto, contains('[1x] Juane Especial'));
      expect(texto, contains('* NOTA: Sin aceituna'));
      expect(texto, contains('> [PARA LLEVAR / TAPER] <'));
      expect(texto, contains('Variante: Grande'));
      expect(texto, contains('--- Fin de Comanda ---'));
      // Sin precios ni totales.
      expect(texto.contains('S/'), false);
      expect(texto.toUpperCase().contains('TOTAL'), false);
      // Ninguna línea normal pasa de 48 columnas (las dobles, de 24).
      for (final l in t) {
        expect(l.texto.length, lessThanOrEqualTo(l.doble ? 24 : anchoTicket));
      }
    });

    test('comanda de delivery, para llevar y reimpresión', () {
      final delivery = _texto(
        ticketComanda(
          pedido: _pedido(tipo: 'delivery'),
          lineas: [_linea()],
          mozo: 'Joel',
        ),
      );
      expect(delivery, contains('TIPO: >> DELIVERY <<'));
      final llevar = _texto(
        ticketComanda(
          pedido: _pedido(tipo: 'llevar'),
          lineas: [_linea()],
          mozo: 'Joel',
          reimpresion: true,
        ),
      );
      expect(llevar, contains('TIPO: >> PARA LLEVAR <<'));
      expect(llevar, contains('*** REIMPRESION ***'));
    });

    const sede = (
      direccion: 'Av. Principal 123, San Isidro',
      telefono: '987654321',
      ruc: '20123456789',
    );

    test('la boleta sigue el orden pedido: sede, título, datos, productos, SON, QR', () {
      final t = ticketBoleta(
        pedido: _pedido().copyWith(clienteNombre: 'Ana Perez'),
        lineas: [
          _linea(cantidad: 2, precio: 28),
          _linea(id: 'l2', nombre: 'Inca Kola', precio: 5),
        ],
        mozo: 'Joel',
        sede: sede,
        metodoPago: 'Efectivo',
        pagado: 61,
      );
      final textos = t.map((l) => l.texto).toList();
      int i(String parte) => textos.indexWhere((x) => x.contains(parte));

      // Orden de arriba a abajo.
      final orden = [
        i('Av. Principal 123'),
        i('Tel. 987654321'),
        i('BOLETA DE VENTA ELECTRONICA'),
        i('0007'),
        i('Fecha de emision: 17/10/2026'),
        i('Forma de pago: Efectivo'),
        i('Cliente: Ana Perez'),
        i('Atendido por: Joel'),
        i('Juane Especial'),
        i('Inca Kola'),
        i('SUBTOTAL'),
        i('TOTAL: S/ 61.00'),
        i('SON: SESENTA Y UNO CON 00/100 SOLES'),
        t.indexWhere((l) => l.qr != null),
        i('PAGO CON: EFECTIVO S/ 61.00'),
        i('REPRESENTACION IMPRESA DE LA'),
      ];
      expect(orden.every((x) => x >= 0), true, reason: '$orden');
      expect([...orden]..sort(), orden, reason: 'fuera de orden: $orden');
      // El pie dice la frase completa.
      expect(textos.join(' '), contains('BOLETA DE VENTA ELECTRONICA'));
      final qr = t.firstWhere((l) => l.qr != null).qr!;
      // Solo visual por ahora: no imita un código de la SUNAT.
      expect(qr, 'BOLETA-0007');
      expect(qr.contains('|'), false);
      for (final l in t) {
        expect(l.texto.length, lessThanOrEqualTo(l.doble ? 24 : anchoTicket));
      }
    });

    test('sin pago, la boleta lo dice y sin cliente va como varios', () {
      final texto = _texto(
        ticketBoleta(
          pedido: _pedido(),
          lineas: [_linea()],
          mozo: 'Joel',
          sede: sede,
        ),
      );
      expect(texto, contains('Forma de pago: Pendiente de pago'));
      expect(texto, contains('Cliente: CLIENTES VARIOS'));
      expect(texto, contains('PAGO CON: --'));
    });

    test('un producto con nombre largo no desborda las columnas', () {
      final t = ticketBoleta(
        pedido: _pedido(),
        lineas: [
          _linea(
            nombre:
                'Juane especial de gallina con arroz y plátano frito grande',
            precio: 25,
          ),
        ],
        mozo: 'Joel',
        sede: sede,
      );
      for (final l in t) {
        expect(l.texto.length, lessThanOrEqualTo(l.doble ? 24 : anchoTicket));
      }
    });

    test('la boleta de un pagador lleva el mismo formato', () {
      final t = ticketPagador(
        pedido: _pedido(),
        pagador: 'Pagador 1',
        items: [(descripcion: 'Parte del consumo (1/2)', monto: 30.5)],
        total: 30.5,
        pagos: [(medio: 'Yape', monto: 30.5)],
        sede: sede,
      );
      final texto = _texto(t);
      expect(texto, contains('BOLETA DE VENTA ELECTRONICA'));
      expect(texto, contains('Cliente: Pagador 1'));
      expect(texto, contains('SON: TREINTA CON 50/100 SOLES'));
      expect(texto, contains('PAGO CON: YAPE S/ 30.50'));
      expect(t.any((l) => l.qr != null), true);
    });
  });

  test('monto en letras', () {
    expect(montoEnLetras(0), 'CERO CON 00/100 SOLES');
    expect(montoEnLetras(1), 'UNO CON 00/100 SOLES');
    expect(montoEnLetras(21), 'VEINTIUNO CON 00/100 SOLES');
    expect(montoEnLetras(56), 'CINCUENTA Y SEIS CON 00/100 SOLES');
    expect(montoEnLetras(100), 'CIEN CON 00/100 SOLES');
    expect(montoEnLetras(101.5), 'CIENTO UNO CON 50/100 SOLES');
    expect(montoEnLetras(1000), 'MIL CON 00/100 SOLES');
    expect(montoEnLetras(1250.75), 'MIL DOSCIENTOS CINCUENTA CON 75/100 SOLES');
    expect(montoEnLetras(21000), 'VEINTIUN MIL CON 00/100 SOLES');
    expect(montoEnLetras(2000000), 'DOS MILLONES CON 00/100 SOLES');
    expect(montoEnLetras(12.999), 'TRECE CON 00/100 SOLES');
  });

  group('ticket en pantalla', () {
    tearDown(() {
      pedidos.clear();
      detallesPorPedido.clear();
    });

    for (final tam in [
      const Size(1200, 900),
      const Size(375, 812),
      const Size(320, 640),
    ]) {
      testWidgets('se ve sin desbordes en ${tam.width.toInt()} px', (
        tester,
      ) async {
        tester.view.physicalSize = tam;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final p = _pedido(notas: 'Cliente: Ana\nsin picante');
        pedidos.add(p);
        detallesPorPedido[p.id] = [
          _linea(comentario: 'bien dorado'),
          _linea(id: 'l2', nombre: 'Inca Kola', precio: 5),
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BoletaPedidoDialog(
                pedido: p,
                mesero: 'Joel',
                titulo: 'Mesa 2',
                metodoPago: 'Sin pago',
                onImprimir: () {},
                onCerrar: () {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(TicketPapel), findsOneWidget);
        expect(find.byType(ColorFiltered), findsNothing);
        // La vista previa es la comanda normal (la reimpresión lleva otro rótulo).
        expect(find.text('*** COMANDA COCINA ***'), findsOneWidget);
        expect(find.text('*** REIMPRESION ***'), findsNothing);
        expect(find.text('Reimprimir comanda'), findsOneWidget);

        // Cuenta: otro ticket, y ya no se ofrece reimprimir.
        await tester.tap(find.text('Boleta'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('BOLETA DE VENTA ELECTRONICA'), findsWidgets);
        expect(find.byType(QrImageView), findsOneWidget);
        // La cuenta de caja lleva el logo (en blanco y negro); la comanda no.
        expect(
          find.descendant(
            of: find.byType(TicketPapel),
            matching: find.byType(ColorFiltered),
          ),
          findsOneWidget,
        );
        expect(find.text('Reimprimir comanda'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
