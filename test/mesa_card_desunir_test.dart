import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/widgets/mesa_card.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

// Mesas unidas: "Desunir" también está en la tarjeta compacta, que es la que
// se ve en el celular.
void main() {
  Widget tarjeta({required bool compacta, VoidCallback? onDesunir}) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MesaCard(
              numero: 1,
              unidas: const [2],
              ocupada: false,
              onTap: () {},
              onDesunir: onDesunir,
              simplificada: compacta,
            ),
          ),
        ),
      );

  testWidgets('en la tarjeta compacta se puede desunir', (tester) async {
    var desunidas = 0;
    await tester.pumpWidget(
      tarjeta(compacta: true, onDesunir: () => desunidas++),
    );
    expect(find.byTooltip('Desunir mesas'), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.unlink));
    await tester.pump();
    expect(desunidas, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin onDesunir (mesa ocupada) no aparece el control', (
    tester,
  ) async {
    await tester.pumpWidget(tarjeta(compacta: true));
    expect(find.byTooltip('Desunir mesas'), findsNothing);
  });

  testWidgets('en la tarjeta completa sigue funcionando', (tester) async {
    var desunidas = 0;
    await tester.pumpWidget(
      tarjeta(compacta: false, onDesunir: () => desunidas++),
    );
    await tester.tap(find.byIcon(LucideIcons.unlink));
    await tester.pump();
    expect(desunidas, 1);
  });
}
