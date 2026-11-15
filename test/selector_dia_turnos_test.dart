import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/caja_servidor.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/selector_dia_turnos.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

// El día y los turnos de Caja se adaptan a cualquier ancho: sin íconos de más,
// sin desbordes, y "Volver a Hoy" y los turnos bajan de línea si no caben.
AperturaCaja _ap(String id, String nombre, {bool abierta = false}) =>
    AperturaCaja(
      id: id,
      montoInicial: 0,
      fechaApertura: DateTime(2026, 11, 12, 9),
      turnoNombre: nombre,
      estado: abierta ? 'abierta' : 'cerrada',
    );

void main() {
  final turnos = [
    _ap('1', 'Turno 1 - Mañana'),
    _ap('2', 'Turno 2 - Almuerzo con nombre bastante largo'),
    _ap('3', 'Turno 3 - Noche', abierta: true),
  ];

  Future<void> montar(
    WidgetTester tester,
    Size tam, {
    bool esHoy = true,
    List<AperturaCaja>? aperturas,
    ValueChanged<String>? onApertura,
    ValueChanged<DateTime>? onDia,
  }) async {
    tester.view.physicalSize = tam;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SelectorDiaYTurnos(
              dia: DateTime(2026, 11, 12),
              esHoy: esHoy,
              aperturas: aperturas ?? turnos,
              aperturaSeleccionadaId: '3',
              cargando: false,
              onDia: onDia ?? (_) {},
              onApertura: onApertura ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  for (final tam in const [
    Size(320, 640),
    Size(375, 812),
    Size(768, 1024),
    Size(1024, 768),
    Size(1440, 900),
  ]) {
    final ancho = tam.width.round();

    testWidgets('hoy a $ancho px: sin desbordes ni ícono de más', (
      tester,
    ) async {
      await montar(tester, tam);
      expect(tester.takeException(), isNull);
      // El calendario es solo el del botón del día; el ícono verde suelto que
      // iba a su izquierda ya no está.
      expect(find.byIcon(LucideIcons.calendarDays), findsOneWidget);
      expect(find.byIcon(LucideIcons.calendar), findsNothing);
      expect(find.text('Turnos del día:'), findsOneWidget);
      expect(find.textContaining('(En curso)'), findsOneWidget);
      expect(find.text('Consolidado del día'), findsNothing);
      expect(find.text('Volver a Hoy'), findsNothing);
    });

    testWidgets('día pasado a $ancho px: "Volver a Hoy" sin desbordes', (
      tester,
    ) async {
      await montar(tester, tam, esHoy: false);
      expect(tester.takeException(), isNull);
      expect(find.text('Volver a Hoy'), findsOneWidget);
      // Todo dentro del ancho de la pantalla.
      final derecha = tester.getTopRight(find.text('Volver a Hoy')).dx;
      expect(derecha, lessThanOrEqualTo(tam.width));
    });
  }

  testWidgets('en celular "Volver a Hoy" baja de línea; en tablet va al lado', (
    tester,
  ) async {
    await montar(tester, const Size(320, 640), esHoy: false);
    final selectorCel = tester
        .getCenter(find.byIcon(LucideIcons.calendarDays))
        .dy;
    final volverCel = tester.getCenter(find.text('Volver a Hoy')).dy;
    expect(volverCel, greaterThan(selectorCel + 20));

    await montar(tester, const Size(1024, 768), esHoy: false);
    final selectorTab = tester
        .getCenter(find.byIcon(LucideIcons.calendarDays))
        .dy;
    final volverTab = tester.getCenter(find.text('Volver a Hoy')).dy;
    expect((volverTab - selectorTab).abs(), lessThan(8));
  });

  testWidgets('tocar un turno avisa cuál se eligió', (tester) async {
    String? elegido;
    await montar(
      tester,
      const Size(375, 812),
      onApertura: (id) => elegido = id,
    );
    await tester.tap(find.textContaining('Turno 1'));
    await tester.pump();
    expect(elegido, '1');
  });

  testWidgets('un día sin turnos no deja la etiqueta sola', (tester) async {
    await montar(tester, const Size(375, 812), aperturas: const []);
    expect(find.text('Turnos del día:'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
