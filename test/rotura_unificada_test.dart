import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/utensilios_store.dart';
import 'package:frontend_bijao/models/utensilio_roto.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/rotura_service.dart';
import 'package:frontend_bijao/widgets/roturas_por_cobrar.dart';
import 'package:shared_preferences/shared_preferences.dart';

UtensilioRoto _rotura({
  String id = 'r1',
  double costo = 10,
  double pagado = 0,
  bool aCuenta = true,
  bool done = false,
  String? notas,
}) => UtensilioRoto(
  id: id,
  productoInventarioId: 'p1',
  productoNombre: 'Vaso',
  empleadoId: 'e1',
  empleadoNombre: 'Alexis',
  cantidad: 1,
  costoTotal: costo,
  fecha: DateTime(2026, 11, 12),
  notas: notas,
  isPagado: aCuenta,
  done: done,
  totalPagado: pagado,
);

void main() {
  group('código de rotura', () {
    test('se genera con el formato ROT-xxxxxx y se encuentra en la nota', () {
      final c = nuevoCodigoRotura();
      expect(RegExp(r'^ROT-[0-9a-f]{6}$').hasMatch(c), isTrue);
      final nota = notaConCodigo('Rotura · Vaso · Pedido #0007', c);
      expect(codigoDeRotura(nota), c);
      expect(notaSinCodigo(nota), 'Rotura · Vaso · Pedido #0007');
    });

    test('una nota vacía solo lleva la referencia', () {
      final c = nuevoCodigoRotura();
      expect(notaConCodigo('', c), 'Ref $c');
      expect(notaSinCodigo('Ref $c'), '');
    });

    test('sin código no hay enlace; el abono se reconoce', () {
      expect(codigoDeRotura('Rotura · Vaso'), isNull);
      expect(esAbonoDeRotura('Rotura · 1x Vaso · Mozo: A · Abono'), isTrue);
      expect(esAbonoDeRotura('Rotura · Vaso · Cliente: B'), isFalse);
    });
  });

  group('estado de la rotura', () {
    test('por cobrar: a cuenta de sueldo, con saldo y sin anular', () {
      expect(_rotura().porCobrar, isTrue);
      expect(_rotura(pagado: 10).porCobrar, isFalse);
      expect(_rotura(aCuenta: false).porCobrar, isFalse);
      expect(_rotura(done: true).porCobrar, isFalse);
      final anulada = _rotura(notas: 'ANULADA: error · Ref ROT-aaaaaa');
      expect(anulada.anulada, isTrue);
      expect(anulada.porCobrar, isFalse);
      expect(_rotura(pagado: 4).saldo, 6);
    });
  });

  group('aviso de Caja', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ApiClient.instance.initialize();
      utensiliosRotos.clear();
    });
    tearDown(utensiliosRotos.clear);

    Future<void> montar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RoturasPorCobrarAviso())),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('sin roturas por cobrar no sale nada', (tester) async {
      utensiliosRotos.add(_rotura(pagado: 10));
      await montar(tester);
      expect(find.text('Cobrar roturas'), findsNothing);
    });

    testWidgets('con roturas por cobrar muestra el total y la lista', (
      tester,
    ) async {
      utensiliosRotos.addAll([
        _rotura(id: 'a', costo: 10, pagado: 4),
        _rotura(id: 'b', costo: 5),
      ]);
      await montar(tester);
      expect(find.textContaining('2 roturas de mozos por cobrar'), findsOne);
      expect(find.textContaining('S/ 11.00'), findsWidgets);
      await tester.tap(find.text('Cobrar roturas'));
      await tester.pumpAndSettle();
      expect(find.text('Roturas por cobrar'), findsOneWidget);
      expect(find.text('Abonar'), findsNWidgets(2));
      expect(find.textContaining('Alexis'), findsWidgets);
    });
  });
}
