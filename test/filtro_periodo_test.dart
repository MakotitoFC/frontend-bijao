import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/inventario_periodo.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/filtro_periodo.dart';
import 'package:frontend_bijao/widgets/menu_flotante.dart';

void main() {
  test('los atajos dan el periodo correcto', () {
    final ahora = DateTime(2026, 11, 16, 15, 30);
    expect(periodoAtajo('hoy', ahora: ahora), periodoDeUnDia(ahora));
    expect(
      periodoAtajo('ayer', ahora: ahora),
      periodoDeUnDia(DateTime(2026, 11, 15)),
    );
    final siete = periodoAtajo('7', ahora: ahora)!;
    expect(siete.start, DateTime(2026, 11, 10));
    expect(siete.end, DateTime(2026, 11, 16));
    final mes = periodoAtajo('mes', ahora: ahora)!;
    expect(mes.start, DateTime(2026, 11, 1));
    expect(mes.end, DateTime(2026, 11, 16));
  });

  test('enPeriodo incluye el primer y el último día', () {
    final p = DateTimeRange(
      start: DateTime(2026, 11, 10),
      end: DateTime(2026, 11, 12),
    );
    expect(enPeriodo(p, DateTime(2026, 11, 10, 0, 0)), true);
    expect(enPeriodo(p, DateTime(2026, 11, 12, 23, 59)), true);
    expect(enPeriodo(p, DateTime(2026, 11, 9, 23, 59)), false);
    expect(enPeriodo(p, DateTime(2026, 11, 13)), false);
    expect(fechaApi(DateTime(2026, 11, 5)), '2026-11-05');
  });

  Future<void> abrir(
    WidgetTester tester,
    DateTimeRange valor,
    ValueChanged<DateTimeRange> onChanged,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: FiltroPeriodo(valor: valor, onChanged: onChanged),
          ),
        ),
      ),
    );
  }

  testWidgets('las flechas mueven de día en día y no pasan de hoy', (
    tester,
  ) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    DateTimeRange? ultimo;
    await abrir(tester, periodoDeUnDia(hoy), (r) => ultimo = r);
    // Hoy: la flecha siguiente no hace nada.
    await tester.tap(find.byTooltip('Día siguiente'));
    expect(ultimo, isNull);
    await tester.tap(find.byTooltip('Día anterior'));
    expect(ultimo, periodoDeUnDia(hoy.subtract(const Duration(days: 1))));
    expect(tester.takeException(), isNull);
  });

  testWidgets('con un rango las flechas de día no actúan', (tester) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    DateTimeRange? ultimo;
    await abrir(
      tester,
      DateTimeRange(
        start: hoy.subtract(const Duration(days: 6)),
        end: hoy,
      ),
      (r) => ultimo = r,
    );
    await tester.tap(find.byTooltip('Día anterior'));
    await tester.tap(find.byTooltip('Día siguiente'));
    expect(ultimo, isNull);
  });

  testWidgets('el menú de atajos elige Ayer', (tester) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    DateTimeRange? ultimo;
    await abrir(tester, periodoDeUnDia(hoy), (r) => ultimo = r);
    await tester.tap(find.byTooltip('Atajos'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ayer').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(ultimo, periodoDeUnDia(hoy.subtract(const Duration(days: 1))));
  });

  testWidgets('el menú con iconos separa y destaca la opción roja', (
    tester,
  ) async {
    String? elegida;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: MenuFlotante<String>(
              tooltip: 'Más acciones',
              opciones: const [
                OpcionMenu(
                  valor: 'ver',
                  etiqueta: 'Ver movimientos',
                  icono: Icons.history,
                ),
                OpcionMenu(
                  valor: 'eliminar',
                  etiqueta: 'Eliminar',
                  color: Colors.red,
                  icono: Icons.delete_outline,
                ),
              ],
              onSeleccionar: (v) => elegida = v,
              disparador: (_, _) => const Icon(Icons.more_vert),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Más acciones'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(elegida, 'eliminar');
  });
}
