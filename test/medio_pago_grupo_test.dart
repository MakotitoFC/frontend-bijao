import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/movimientos_caja_store.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/widgets/medio_pago_dialog.dart';

void main() {
  tearDown(mediosPago.clear);

  test('el grupo viene del servidor; sin él se supone por el nombre', () {
    final conGrupo = MedioPago.fromJson({
      'id': '1',
      'medio_pago': 'Caja chica',
      'grupo': 'digital',
    });
    expect(conGrupo.grupo, 'digital');
    final sinGrupo = MedioPago.fromJson({'id': '2', 'medio_pago': 'Yape Joel'});
    expect(sinGrupo.grupo, 'digital');
    expect(
      MedioPago.fromJson({'id': '3', 'medio_pago': 'Visa'}).grupo,
      'tarjeta',
    );
    expect(
      MedioPago.fromJson({'id': '4', 'medio_pago': 'Efectivo'}).grupo,
      'efectivo',
    );
  });

  test('varios Yape suman en el grupo digital de las tarjetas de Caja', () {
    mediosPago.addAll(const [
      MedioPago(
        id: 'a',
        medioPago: 'Yape Joel',
        aplicaComision: false,
        grupo: 'digital',
      ),
      MedioPago(
        id: 'b',
        medioPago: 'Yape local',
        aplicaComision: false,
        grupo: 'digital',
      ),
      MedioPago(
        id: 'c',
        medioPago: 'Mi billetera',
        aplicaComision: false,
        grupo: 'digital',
      ),
    ]);
    expect(grupoDeMedio('Yape Joel'), 'digital');
    expect(grupoDeMedio('yape local'), 'digital');
    // El nombre no importa: manda el grupo que eligió el administrador.
    expect(grupoDeMedio('Mi billetera'), 'digital');
    expect(FilaResumenMedio('Otro', grupoServidor: 'digital').grupo, 'digital');
  });

  testWidgets('al crear un método el grupo se propone según el nombre', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MedioPagoDialog())),
    );
    expect(find.text('Tarjeta / otros'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Yape Joel');
    await tester.pump();
    expect(find.text('Digital (Yape, Plin…)'), findsOneWidget);
  });
}
