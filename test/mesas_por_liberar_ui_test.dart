import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/mesas_por_liberar_store.dart';
import 'package:frontend_bijao/data/mesas_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/mesa.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/widgets/campana_notificaciones.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mesa3 = '33333333-3333-4333-8333-333333333303';
const _mesa5 = '33333333-3333-4333-8333-333333333305';

Usuario _usuario(AppRole rol) =>
    Usuario(id: 'u1', nombre: 'mozo1', email: 'm@m', rol: rol, sedeId: 's');

void main() {
  late HttpServer servidor;
  final peticiones = <String>[];
  // Mesas que el servidor devuelve (cambia al liberar una).
  var mesasServidor = <Map<String, dynamic>>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    await ApiClient.instance.setToken('t');
    peticiones.clear();
    limpiarMesasPorLiberar();
    pedidos.clear();
    detallesPorPedido.clear();
    mesas
      ..clear()
      ..addAll(const [
        Mesa(id: _mesa3, numero: 3, estado: 'ocupada'),
        Mesa(id: _mesa5, numero: 5, estado: 'ocupada'),
      ]);
    mesasServidor = [
      {
        'id': _mesa3,
        'numero': 3,
        'estado': 'ocupada',
        'numero_sillas': 4,
        'zona_id': 'z',
      },
      {
        'id': _mesa5,
        'numero': 5,
        'estado': 'ocupada',
        'numero_sillas': 4,
        'zona_id': 'z',
      },
    ];
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
    servidor.listen((req) async {
      peticiones.add('${req.method} ${req.uri.path}');
      Object cuerpo = [];
      if (req.method == 'POST' && req.uri.path.endsWith('/liberar')) {
        final id = req.uri.pathSegments[req.uri.pathSegments.length - 2];
        for (final m in mesasServidor) {
          if (m['id'] == id) m['estado'] = 'disponible';
        }
        cuerpo = {'mensaje': 'Mesa liberada exitosamente'};
      } else if (req.uri.path == '/api/mesas') {
        cuerpo = mesasServidor;
      }
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(cuerpo));
      await req.response.close();
    });
  });

  tearDown(() async {
    limpiarMesasPorLiberar();
    AuthService.instance.userNotifier.value = null;
    await servidor.close(force: true);
  });

  Future<void> abrir(WidgetTester tester, AppRole rol) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final u = _usuario(rol);
    AuthService.instance.userNotifier.value = u;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CampanaNotificaciones())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> abrirPanel(WidgetTester tester) async {
    await tester.tap(find.byType(CampanaNotificaciones));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('el mozo ve en la campana la mesa que el backend informa', (
    tester,
  ) async {
    // El backend informó solo su mesa cobrada (las llamadas HTTP de las
    // pruebas de widgets no salen, por eso se siembra la lista).
    fijarMesasPorLiberar('u1', [mesas.first]);
    await abrir(tester, AppRole.mesero);
    expect(find.text('1'), findsOneWidget); // contador de la campana

    await abrirPanel(tester);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Mesa 3 por liberar'), findsOneWidget);
    // La mesa 5 (de otro mozo) no se le ofrece: el backend no la informa.
    expect(find.text('Mesa 5 por liberar'), findsNothing);
    expect(find.text('Liberar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sin mesas cobradas la campana no cuenta nada', (tester) async {
    await abrir(tester, AppRole.mesero);
    expect(find.text('1'), findsNothing);
    await abrirPanel(tester);
    expect(find.text('No hay notificaciones.'), findsOneWidget);
    expect(find.text('Liberar'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('el administrador ve todas las que el backend informa', (
    tester,
  ) async {
    fijarMesasPorLiberar('u1', [...mesas]);
    await abrir(tester, AppRole.administrador);
    expect(find.text('2'), findsOneWidget);
    await abrirPanel(tester);
    expect(find.text('Mesa 3 por liberar'), findsOneWidget);
    expect(find.text('Mesa 5 por liberar'), findsOneWidget);
    expect(find.text('Liberar'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'una mesa nueva por liberar se avisa en pantalla (con x) y queda en la campana',
    (tester) async {
      await abrir(tester, AppRole.mesero);
      expect(find.text('Mesa 3 por liberar'), findsNothing);

      // Llega la notificación (como si el servidor la informara).
      fijarMesasPorLiberar('u1', [mesas.first]);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Mesa 3 por liberar'), findsOneWidget); // en pantalla
      expect(find.byTooltip('Cerrar aviso'), findsOneWidget); // la "x" gris
      expect(find.text('1'), findsOneWidget); // contador de la campana

      // El aviso no se va solo: queda hasta cerrarlo.
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Mesa 3 por liberar'), findsOneWidget);

      // Con la "x" se cierra, pero la notificación sigue en la campana.
      await tester.tap(find.byTooltip('Cerrar aviso'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Mesa 3 por liberar'), findsNothing);
      expect(find.text('1'), findsOneWidget);
      await abrirPanel(tester);
      expect(find.text('Mesa 3 por liberar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('al liberarse la mesa el aviso en pantalla desaparece', (
    tester,
  ) async {
    await abrir(tester, AppRole.mesero);
    fijarMesasPorLiberar('u1', [mesas.first]);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byTooltip('Cerrar aviso'), findsOneWidget);
    quitarMesaPorLiberar(mesas.first.id);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Cerrar aviso'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Liberar intenta liberar la mesa; si falla, avisa y la deja', (
    tester,
  ) async {
    // En las pruebas de widgets las llamadas HTTP no salen (responden 400):
    // sirve para ver que el botón lanza la acción y que, si el servidor no la
    // acepta, la mesa sigue en la lista. La liberación exitosa se prueba en
    // pedido_mozo_service_test.
    fijarMesasPorLiberar('u1', [mesas.first]);
    await abrir(tester, AppRole.mesero);
    await abrirPanel(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Liberar'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('No se pudo liberar la mesa 3'), findsOneWidget);
    expect(mesasPorLiberar(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
}
