import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bijao/main.dart';

void main() {
  testWidgets('Login screen shows email and password fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
