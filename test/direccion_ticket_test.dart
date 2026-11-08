import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/utils/direccion_ticket.dart';

Pedido _pedido({String? direccion, String? celular}) => Pedido(
  id: 'p1',
  numeroPedido: '1',
  mesaNumero: 0,
  tipoPedido: 'delivery',
  estado: 'pendiente',
  fechaPedido: DateTime(2026, 11, 8, 13),
  usuarioId: 'u1',
  direccionDelivery: direccion,
  clienteCelular: celular,
);

void main() {
  test('dirección y teléfono van separados con " | "', () {
    expect(
      direccionConTelefono(
        _pedido(direccion: 'Av. Los Pinos 123', celular: '987654321'),
      ),
      'Av. Los Pinos 123 | Tel. 987654321',
    );
  });

  test('solo teléfono o solo dirección, sin separador', () {
    expect(
      direccionConTelefono(_pedido(celular: ' 987654321 ')),
      'Tel. 987654321',
    );
    expect(
      direccionConTelefono(_pedido(direccion: 'Jr. Lima 45')),
      'Jr. Lima 45',
    );
  });

  test('sin ninguno de los dos, no manda nada', () {
    expect(direccionConTelefono(_pedido()), isNull);
    expect(direccionConTelefono(_pedido(direccion: ' ', celular: '')), isNull);
  });
}
