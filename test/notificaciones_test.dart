import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/notificaciones_store.dart';
import 'package:frontend_bijao/widgets/app_toast.dart';
import 'package:frontend_bijao/widgets/campana_notificaciones.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final store = NotificacionesStore.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store.reiniciar();
  });

  test(
    'los avisos del día se guardan y se descartan los de otro día',
    () async {
      store.agregar(TipoNotificacion.exito, 'Éxito', 'Pago registrado');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      store.reiniciar();
      await store.cargar();
      expect(store.lista.value.single.mensaje, 'Pago registrado');

      final ayer = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'notificaciones_del_dia': jsonEncode({
          'dia':
              '${ayer.year}-${ayer.month.toString().padLeft(2, '0')}-'
              '${ayer.day.toString().padLeft(2, '0')}',
          'items': [
            {
              'id': '1',
              'tipo': 'error',
              'titulo': 'Error',
              'mensaje': 'viejo',
              'fecha': ayer.toIso8601String(),
            },
          ],
        }),
      });
      store.reiniciar();
      await store.cargar();
      expect(store.lista.value, isEmpty);
    },
  );

  testWidgets('un toast queda en la campana y se ve al abrirla', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                const CampanaNotificaciones(),
                TextButton(
                  onPressed: () => showAppToast(
                    context,
                    'Pago registrado',
                    type: ToastType.success,
                    titulo: 'Pago',
                  ),
                  child: const Text('toast'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('toast'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1'), findsOneWidget); // insignia sin leer
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.byTooltip('Notificaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Notificaciones de hoy'), findsOneWidget);
    expect(find.text('Pago registrado'), findsWidgets);
  });
}
