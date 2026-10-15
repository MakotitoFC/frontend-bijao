import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/mesas_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/mesa.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/sede.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/cocina_screen.dart';
import 'package:frontend_bijao/screens/configuracion_screen.dart';
import 'package:frontend_bijao/screens/home_screen.dart';
import 'package:frontend_bijao/screens/inicio_screen.dart';
import 'package:frontend_bijao/screens/mesas_screen.dart';
import 'package:frontend_bijao/screens/pedidos_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/nuevo_pedido_dialog.dart';
import 'package:frontend_bijao/widgets/reportar_problema_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sede = Sede(id: '1', ruc: '1', direccion: 'Av. Principal 123');

Usuario _usuario(AppRole rol) => Usuario(
  id: 'u1',
  nombre: 'Ana Maria',
  email: 'a@a',
  rol: rol,
  permisos: const {},
);

const _tamanos = {
  'celular': Size(375, 812),
  'celular chico': Size(320, 640),
  'tablet': Size(768, 1024),
  'tablet horizontal': Size(1024, 768),
};

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    mesas
      ..clear()
      ..addAll(const [
        Mesa(id: 'm1', numero: 1, estado: 'ocupada'),
        Mesa(id: 'm2', numero: 2, estado: 'disponible'),
      ]);
    pedidos
      ..clear()
      ..add(
        Pedido(
          id: 'a',
          numeroPedido: 'A1',
          mesaNumero: 1,
          tipoPedido: 'mesa',
          estado: 'pendiente',
          fechaPedido: DateTime.now().subtract(const Duration(minutes: 8)),
          usuarioId: 'u1',
        ),
      );
  });

  tearDown(() {
    pedidos.clear();
    mesas.clear();
    AuthService.instance.userNotifier.value = null;
  });

  Future<void> dibujar(
    WidgetTester tester,
    Size tam,
    Widget Function() crear,
  ) async {
    tester.view.physicalSize = tam;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final anterior = FlutterError.onError;
    final fallos = <FlutterErrorDetails>[];
    FlutterError.onError = fallos.add;
    await tester.pumpWidget(MaterialApp(home: crear()));
    await tester.pump(const Duration(milliseconds: 400));
    FlutterError.onError = anterior;
    if (fallos.isNotEmpty) {
      final texto = fallos.first.toString();
      final lineas = texto
          .split('\n')
          .where(
            (l) =>
                l.contains('overflowed') ||
                l.contains('creator:') ||
                l.contains('error-causing') ||
                RegExp(r'lib/[a-z_/]+\.dart:\d+').hasMatch(l),
          )
          .take(8)
          .join('\n');
      fail('Fallo de dibujo:\n$lineas');
    }
    await tester.pumpWidget(const SizedBox());
  }

  for (final t in _tamanos.entries) {
    for (final rol in [AppRole.administrador, AppRole.mesero]) {
      testWidgets('Home en ${t.key} (${rol.label})', (tester) async {
        final u = _usuario(rol);
        AuthService.instance.userNotifier.value = u;
        await dibujar(
          tester,
          t.value,
          () => HomeScreen(sede: _sede, usuario: u),
        );
      });
    }

    testWidgets('pantallas sueltas en ${t.key}', (tester) async {
      final u = _usuario(AppRole.administrador);
      AuthService.instance.userNotifier.value = u;
      final pantallas = <String, Widget Function()>{
        'inicio': () => InicioScreen(usuario: u, sede: _sede, onIrA: (_) {}),
        'pedidos': () => Scaffold(body: PedidosScreen(usuario: u)),
        'mesas': () => Scaffold(body: MesasScreen(usuario: u)),
        'cocina': () => const Scaffold(body: CocinaScreen()),
        'configuracion': () => Scaffold(body: ConfiguracionScreen(usuario: u)),
      };
      for (final e in pantallas.entries) {
        try {
          await dibujar(tester, t.value, e.value);
        } catch (err) {
          fail('${e.key} en ${t.key}: $err');
        }
      }
    });

    testWidgets('diálogos en ${t.key}', (tester) async {
      final u = _usuario(AppRole.administrador);
      AuthService.instance.userNotifier.value = u;
      await dibujar(
        tester,
        t.value,
        () => const Scaffold(
          body: SingleChildScrollView(
            child: ReportarProblemaDialog(nombrePlato: 'Tacacho'),
          ),
        ),
      );
      await dibujar(
        tester,
        t.value,
        () => Scaffold(
          body: NuevoPedidoDialog(
            usuario: u,
            tipo: 'mesa',
            onTerminar: (_) {},
            onVolver: () {},
          ),
        ),
      );
    });
  }

  testWidgets('el menú lateral se contrae solo al achicar la pantalla', (
    tester,
  ) async {
    final u = _usuario(AppRole.administrador);
    AuthService.instance.userNotifier.value = u;
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;

    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(sede: _sede, usuario: u),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final menu = find.byWidgetPredicate(
      (w) =>
          w is AnimatedContainer &&
          (w.decoration as BoxDecoration?)?.color == AppColors.navbar,
    );
    expect(tester.getSize(menu).width, 256); // expandido

    tester.view.physicalSize = const Size(900, 900);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getSize(menu).width, 68); // solo íconos

    tester.view.physicalSize = const Size(1400, 900);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getSize(menu).width, 256);
    await tester.pumpWidget(const SizedBox());
  });
}
