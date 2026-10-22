import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/services/eventos_service.dart';

void main() {
  test('CARTA_ACTUALIZADA pide volver a leer solo la carta', () {
    final a = traducirEvento('CARTA_ACTUALIZADA');
    expect(a.carta, isTrue);
    expect(a.ninguna, isFalse);
    expect(a.pedidos, isFalse);
    expect(a.mesas, isFalse);
    expect(a.stock, isFalse);
  });

  test('los demás eventos no tocan la carta', () {
    for (final nombre in [
      'PEDIDO_NUEVO',
      'MESA_LIBERADA',
      'STOCK_ACTUALIZADO',
    ]) {
      expect(traducirEvento(nombre).carta, isFalse, reason: nombre);
    }
  });

  test('un plato agotado relee el stock y también la carta', () {
    final acciones = traducirEvento('PLATO_AGOTADO');
    expect(acciones.stock, isTrue);
    expect(acciones.carta, isTrue);
  });

  test('varios eventos seguidos se unen en una sola lectura', () {
    final unidas = traducirEvento('CARTA_ACTUALIZADA')
        .unir(traducirEvento('PEDIDO_NUEVO'));
    expect(unidas.carta, isTrue);
    expect(unidas.pedidos, isTrue);
  });
}
