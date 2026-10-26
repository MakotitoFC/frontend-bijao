import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cierres_store.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/utils/ticket_texto.dart';

const _efectivo = MedioPago(
  id: 'm1',
  medioPago: 'Efectivo',
  aplicaComision: false,
);
const _tarjeta = MedioPago(
  id: 'm2',
  medioPago: 'Tarjeta',
  aplicaComision: true,
  porcentajeComision: 4,
);

Pedido _pedido() => Pedido(
  id: 'p1',
  numeroPedido: '0007',
  mesaNumero: 2,
  tipoPedido: 'mesa',
  estado: 'servido',
  fechaPedido: DateTime(2026, 10, 19, 14, 0),
  usuarioId: 'u1',
);

PedidoLine _linea(double precio) => PedidoLine(
  id: 'l1',
  cartaId: 'c1',
  nombrePlato: 'Ceviche',
  cantidad: 1,
  modificadores: const [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: precio,
  descuentoAplicado: 0,
  precioTotalLinea: precio,
  tipoEntrega: 'mesa',
);

String _texto(List<LineaTicket> t) => t.map((l) => l.texto).join('\n');

void main() {
  setUp(() {
    pagos.clear();
    pedidos.clear();
    detallesPorPedido.clear();
    pedidos.add(_pedido());
    detallesPorPedido['p1'] = [_linea(100)];
  });

  tearDown(() {
    pagos.clear();
    pedidos.clear();
    detallesPorPedido.clear();
  });

  test('el recargo es un porcentaje del monto, solo si el método lo lleva', () {
    expect(_tarjeta.recargoSobre(100), 4);
    expect(_tarjeta.recargoSobre(12.34), 0.49); // 4 % de 12,34 = 0,4936
    expect(_efectivo.recargoSobre(100), 0);
    expect(_tarjeta.recargoSobre(0), 0);
  });

  test('con tarjeta el cliente paga la cuenta más el recargo', () {
    final pago = registrarPago(
      pedido: _pedido(),
      medioPago: _tarjeta,
      montoAbonado: 100,
      propina: 0,
    );
    expect(pago.montoAbonado, 100); // lo que se descuenta de la cuenta
    expect(pago.montoComision, 4); // el recargo
    expect(pago.montoCobrado, 104); // lo que se le cobra al cliente
    // La cuenta queda saldada con 100: el recargo no cuenta como abono.
    expect(saldoPendienteDePedido('p1'), closeTo(0, 0.001));
    expect(recargoCobradoDePedido('p1'), 4);
  });

  test('con efectivo no hay recargo', () {
    final pago = registrarPago(
      pedido: _pedido(),
      medioPago: _efectivo,
      montoAbonado: 100,
      propina: 0,
    );
    expect(pago.montoComision, 0);
    expect(pago.montoCobrado, 100);
    expect(recargoCobradoDePedido('p1'), 0);
  });

  test('la caja cuenta lo que entró con tarjeta, recargo incluido', () {
    registrarPago(
      pedido: _pedido(),
      medioPago: _tarjeta,
      montoAbonado: 100,
      propina: 0,
    );
    expect(totalesCajaActual().tarjeta, 104);
    expect(totalesCajaActual().efectivo, 0);
  });

  test('la vista previa del ticket de venta, la boleta y la factura', () {
    const sede = (direccion: 'Av. Principal 123', telefono: '', ruc: '2012');
    String vista(String tipo, {String? doc, String? nombre}) => _texto(
      ticketComprobante(
        tipo: tipo,
        pedido: _pedido(),
        lineas: [_linea(118)],
        mozo: 'Joel',
        sede: sede,
        documentoCliente: doc,
        denominacionCliente: nombre,
      ),
    );
    final ticket = vista('ticket_venta');
    expect(ticket, contains('TICKET DE VENTA'));
    expect(ticket, contains('Documento interno, sin validez tributaria'));
    expect(ticket, isNot(contains('IGV')));

    final boleta = vista('boleta');
    expect(boleta, contains('BOLETA DE VENTA ELECTRONICA'));
    expect(boleta, contains('B###-########'));
    expect(boleta, contains('Cliente: CLIENTES VARIOS'));
    expect(boleta, contains('DNI: 00000000'));
    expect(boleta, contains('OP. GRAVADA'));
    expect(boleta, contains('S/ 100.00'));
    expect(boleta, contains('IGV (18%)'));
    expect(boleta, contains('S/ 18.00'));
    expect(boleta, contains('Atendido por: Joel'));

    final factura = vista(
      'factura',
      doc: '20100070970',
      nombre: 'EMPRESA S.A.',
    );
    expect(factura, contains('FACTURA ELECTRONICA'));
    expect(factura, contains('F###-########'));
    expect(factura, contains('RUC: 20100070970'));
    expect(factura, contains('Razon social: EMPRESA S.A.'));
    expect(factura, contains('Representacion impresa de la factura'));
  });

  test('la boleta lista cada medio de pago con su nombre y su monto', () {
    const sede = (direccion: 'Av. Principal 123', telefono: '', ruc: '2012');
    final texto = _texto(
      ticketBoleta(
        pedido: _pedido(),
        lineas: [_linea(100)],
        mozo: 'Joel',
        sede: sede,
        metodoPago: 'Yape Joel, Efectivo',
        pagos: const [
          (medio: 'Yape Joel', monto: 30),
          (medio: 'Efectivo', monto: 70),
        ],
        pagado: 100,
      ),
    );
    expect(texto, contains('Atendido por: Joel'));
    expect(texto, contains('PAGO CON: YAPE JOEL S/ 30.00'));
    expect(texto, contains('PAGO CON: EFECTIVO S/ 70.00'));
  });

  test('la boleta muestra el recargo y el total a pagar', () {
    const sede = (direccion: 'Av. Principal 123', telefono: '', ruc: '2012');
    final texto = _texto(
      ticketBoleta(
        pedido: _pedido(),
        lineas: [_linea(100)],
        mozo: 'Joel',
        sede: sede,
        metodoPago: 'Tarjeta',
        pagado: 100,
        recargo: 4,
      ),
    );
    expect(texto, contains('TOTAL CUENTA'));
    expect(texto, contains('RECARGO POR PAGO CON TARJETA'));
    expect(texto, contains('TOTAL A PAGAR: S/ 104.00'));
    expect(texto, contains('PAGO CON: TARJETA'));
    expect(texto, contains('104.00'));

    // Sin recargo no aparecen esas líneas.
    final sin = _texto(
      ticketBoleta(
        pedido: _pedido(),
        lineas: [_linea(100)],
        mozo: 'Joel',
        sede: sede,
        metodoPago: 'Efectivo',
        pagado: 100,
      ),
    );
    expect(sin, isNot(contains('RECARGO')));
    expect(sin, contains('TOTAL: S/ 100.00'));
  });

  test('la boleta muestra el efectivo recibido y el vuelto', () {
    const sede = (direccion: 'Av. Principal 123', telefono: '', ruc: '2012');
    final texto = _texto(
      ticketBoleta(
        pedido: _pedido(),
        lineas: [_linea(100)],
        mozo: 'Joel',
        sede: sede,
        metodoPago: 'Efectivo',
        pagado: 100,
        recibido: 120,
        vuelto: 20,
      ),
    );
    expect(texto, contains('EFECTIVO RECIBIDO'));
    expect(texto, contains('120.00'));
    expect(texto, contains('VUELTO'));
    expect(texto, contains('20.00'));
    expect(texto, contains('TOTAL: S/ 100.00'));
  });
}
