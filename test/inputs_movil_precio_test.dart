import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/utils/blur_dialog.dart';
import 'package:frontend_bijao/widgets/campo_texto.dart';
import 'package:frontend_bijao/widgets/producto_opciones_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _plato = CartaItem(
  id: 'c1',
  nombrePlato: 'Toa en patarashca',
  descripcion: 'Pescado toa fresco',
  categoriaId: 'k',
  precioCliente: 45,
  stock: 10,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
  });

  // Celular, con la letra del sistema al 140 %: los campos del precio manual
  // deben medir al menos 44 px (antes eran de 36 y cortaban el texto).
  testWidgets('precio manual en celular: campos de 44 px o más', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBlurDialog<ProductoConfigurado>(
                context: context,
                builder: (_) => const ProductoOpcionesDialog(
                  item: _plato,
                  esAdmin: true,
                  permitePrecioManual: true,
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.byIcon(LucideIcons.pencil).first);
    await tester.pump();
    final campos = find.byType(CampoTexto);
    expect(campos, findsWidgets);
    for (final f in campos.evaluate()) {
      final alto = tester.getSize(find.byWidget(f.widget)).height;
      expect(alto, greaterThanOrEqualTo(44), reason: 'campo de $alto px');
    }
    expect(find.text('Precio para este pedido'), findsOneWidget);
    expect(find.text('Motivo del cambio'), findsOneWidget);
  });
}
