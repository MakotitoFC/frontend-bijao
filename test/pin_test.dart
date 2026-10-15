import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/widgets/cambiar_pin_dialog.dart';

void main() {
  test('el login recuerda si el backend pide cambiar el PIN', () {
    final u = Usuario.fromJson({
      'usuario_id': 'u1',
      'usuario': 'admin',
      'rol': 'ADMINISTRADOR',
      'debe_cambiar_pin': true,
    });
    expect(u.debeCambiarPin, true);
    expect(u.rol, AppRole.administrador);
    expect(Usuario.fromJson(u.toJson()).debeCambiarPin, true);
    expect(u.copyWith(debeCambiarPin: false).debeCambiarPin, false);
    expect(Usuario.fromJson({'usuario': 'x', 'rol': 'MOZO'}).debeCambiarPin, false);
  });

  testWidgets('el PIN debe tener de 4 a 10 dígitos y coincidir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CambiarPinDialog())),
    );
    final campos = find.byType(TextField);

    Future<void> guardar(String a, String b) async {
      await tester.enterText(campos.at(0), a);
      await tester.enterText(campos.at(1), b);
      await tester.tap(find.text('Guardar PIN'));
      await tester.pump();
    }

    await guardar('123', '123');
    expect(find.text('El PIN debe tener de 4 a 10 dígitos.'), findsOneWidget);
    await guardar('12345', '12346');
    expect(find.text('Los dos PIN no coinciden.'), findsOneWidget);
    // Solo se aceptan dígitos.
    await tester.enterText(campos.at(0), 'ab12cd');
    expect(tester.widget<TextField>(campos.at(0)).controller!.text, '12');
  });

  testWidgets('con PIN obligatorio no hay "x" ni Cancelar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CambiarPinDialog(obligatorio: true)),
      ),
    );
    expect(find.byTooltip('Cerrar'), findsNothing);
    expect(find.text('Cancelar'), findsNothing);
    expect(find.text('Cambia tu PIN'), findsOneWidget);
  });
}
