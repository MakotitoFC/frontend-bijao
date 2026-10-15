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
import 'package:frontend_bijao/screens/pedidos_screen.dart';
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
    quitarMesaPorLiberar(_mesa3);
    quitarMesaPorLiberar(_mesa5);
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
      MaterialApp(
        home: Scaffold(body: PedidosScreen(usuario: u)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('el mozo ve la franja con su mesa cobrada', (tester) async {
    marcarMesaPorLiberar(_mesa3); // su pedido se cobró con la app abierta
    await abrir(tester, AppRole.mesero);

    expect(find.text('Mesas por liberar'), findsOneWidget);
    expect(find.text('Mesa 3'), findsOneWidget);
    // La mesa 5 (de otro mozo) no se le ofrece.
    expect(find.text('Mesa 5'), findsNothing);

    // Cada mesa trae su botón "Liberar".
    expect(find.text('Liberar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sin mesas cobradas el mozo no ve la franja', (tester) async {
    await abrir(tester, AppRole.mesero);
    expect(find.text('Mesas por liberar'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('el administrador ve también las ocupadas sin pedido abierto', (
    tester,
  ) async {
    await abrir(tester, AppRole.administrador);
    expect(find.text('Mesas por liberar'), findsOneWidget);
    expect(find.text('Mesa 3'), findsOneWidget);
    expect(find.text('Mesa 5'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
