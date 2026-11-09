import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/sede.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/configuracion_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Configuración en celular, con el tema real: los datos de solo lectura apilan
// la etiqueta sobre el valor (alineado a la izquierda), van en grupos y "Editar
// en Restaurantes" abre esa pestaña.
const _admin = Usuario(
  id: 'u1',
  nombre: 'Administrador General',
  email: 'a@a',
  rol: AppRole.administrador,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    AuthService.instance.userNotifier.value = _admin;
    mediosPago
      ..clear()
      ..add(
        const MedioPago(
          id: 'mp1',
          medioPago: 'Efectivo',
          aplicaComision: false,
        ),
      );
    sedes
      ..clear()
      ..add(
        const Sede(
          id: '1',
          ruc: '20540005371',
          razonSocial: 'Servicios multiples el bijao',
          direccion:
              'CAL.LOS BRILLANTES NRO. 421 URB. SANTA INES LA LIBERTAD - '
              'TRUJILLO - TRUJILLO',
          celular: '999999998',
        ),
      );
  });

  tearDown(() {
    sedes.clear();
    mediosPago.clear();
    AuthService.instance.userNotifier.value = null;
  });

  for (final tam in const [Size(375, 812), Size(320, 640)]) {
    testWidgets('General en celular ${tam.width.round()}: datos apilados y '
        'agrupados', (tester) async {
      tester.view.physicalSize = tam;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ConfiguracionScreen(usuario: _admin),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      // El índice lista todas las páginas, agrupadas y sin barra oscura.
      for (final p in const [
        'General',
        'Servicio',
        'Restaurantes',
        'Métodos de pago',
        'Usuarios y roles',
        'Promociones',
        'Stock diario',
        'Impresoras',
        'Impresión en cocina',
        'Sede y Facturación',
        'Turnos de Caja',
        'Negocio',
      ]) {
        await tester.scrollUntilVisible(
          find.text(p),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(p), findsOneWidget, reason: p);
      }
      await tester.scrollUntilVisible(
        find.text('General'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      // De vuelta arriba, se ve el título del primer grupo.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('NEGOCIO Y SERVICIO'), findsOneWidget);
      await tester.ensureVisible(find.text('General'));
      await tester.tap(find.text('General'));
      await tester.pump(const Duration(milliseconds: 400));

      // Grupos y enlace.
      expect(find.text('DATOS FISCALES'), findsOneWidget);
      expect(find.text('CONTACTO'), findsOneWidget);
      expect(find.text('Editar en Restaurantes'), findsOneWidget);

      // Etiqueta arriba y valor debajo, alineados a la izquierda.
      final etiqueta = tester.getRect(find.text('Razón social'));
      final valor = tester.getRect(find.text('Servicios multiples el bijao'));
      expect(valor.top, greaterThan(etiqueta.bottom - 1));
      expect((valor.left - etiqueta.left).abs(), lessThan(1));

      // La dirección se lee de corrido: ocupa casi todo el ancho disponible.
      final direccion = tester.getRect(find.textContaining('CAL.LOS'));
      expect(direccion.left, lessThan(30));

      // El enlace abre la pestaña Restaurantes.
      await tester.tap(find.text('Editar en Restaurantes'));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text('Restaurante 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Métodos de pago en celular: sin título repetido y con la acción '
      'en la cabecera', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ConfiguracionScreen(usuario: _admin),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      find.text('Métodos de pago'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Métodos de pago'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    // El título aparece una sola vez (en la cabecera) y el botón está arriba.
    expect(find.text('Métodos de pago'), findsOneWidget);
    final boton = find.widgetWithText(FilledButton, 'Método');
    expect(boton, findsOneWidget);
    expect(tester.getRect(boton).top, lessThan(80));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
