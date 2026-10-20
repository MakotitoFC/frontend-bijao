import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/utils/whatsapp_cuenta.dart';

void main() {
  test('el texto de WhatsApp lleva el detalle y la dirección de entrega', () {
    final pedido = Pedido(
      id: 'p1',
      numeroPedido: '0007',
      mesaNumero: 0,
      tipoPedido: 'delivery',
      estado: 'pendiente',
      fechaPedido: DateTime(2026, 10, 20, 14, 0),
      usuarioId: 'u1',
      clienteNombre: 'Ana',
      direccionDelivery: 'Av. Lima 123',
    );
    const linea = PedidoLine(
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
    final texto = textoCuentaWhatsapp(pedido: pedido, lineas: const [linea]);
    expect(texto, contains('Cliente: Ana'));
    expect(texto, contains('Entrega: Av. Lima 123'));
    expect(texto, contains('2 x Ceviche'));
    expect(texto, contains('*TOTAL: S/ 40.00*'));
  });
}
