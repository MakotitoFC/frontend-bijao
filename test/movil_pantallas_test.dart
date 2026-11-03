import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/configuracion_store.dart';
import 'package:frontend_bijao/data/mesas_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/medio_pago.dart';
import 'package:frontend_bijao/models/mesa.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/models/sede.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/cocina_screen.dart';
import 'package:frontend_bijao/screens/configuracion_screen.dart';
import 'package:frontend_bijao/screens/inicio_screen.dart';
import 'package:frontend_bijao/screens/mesas_screen.dart';
import 'package:frontend_bijao/screens/reportes_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Pantallas en celular: se recorren en los tamaños de teléfono más comunes y
// fallan si algo se desborda.

const _tamanos = {
  'celular (375)': Size(375, 812),
  'celular (360)': Size(360, 740),
  'celular chico (320)': Size(320, 640),
};

const _sede = Sede(id: '1', ruc: '1', direccion: 'Av. Principal 123');

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
        const MedioPago(id: 'mp1', medioPago: 'Efectivo', aplicaComision: false),
      );
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
          id: 'p1',
          numeroPedido: '0012',
          mesaNumero: 1,
          tipoPedido: 'mesa',
          estado: 'pendiente',
          fechaPedido: DateTime.now().subtract(const Duration(minutes: 8)),
          usuarioId: 'u1',
        ),
      );
    detallesPorPedido['p1'] = const [
      PedidoLine(
        id: 'l1',
        cartaId: 'c1',
        nombrePlato: 'Tacacho con cecina y chorizo regional',
        cantidad: 2,
        modificadores: [],
        presentacion: null,
        promocion: null,
        comentario: null,
        precioUnitario: 12,
        descuentoAplicado: 0,
        precioTotalLinea: 24,
      ),
    ];
  });

  tearDown(() {
    pedidos.clear();
    mesas.clear();
    mediosPago.clear();
    detallesPorPedido.clear();
    AuthService.instance.userNotifier.value = null;
  });

  // Dibuja y devuelve los desbordes encontrados (texto de dónde ocurren).
  Future<List<String>> revisar(WidgetTester tester, Widget pantalla) async {
    final anterior = FlutterError.onError;
    final fallos = <FlutterErrorDetails>[];
    FlutterError.onError = fallos.add;
    await tester.pumpWidget(MaterialApp(home: pantalla));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    FlutterError.onError = anterior;
    return _desbordes(fallos);
  }

  for (final t in _tamanos.entries) {
    testWidgets('pantallas sin desbordes en ${t.key}', (tester) async {
      tester.view.physicalSize = t.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final problemas = <String>[];
      final pantallas = <String, Widget Function()>{
        'Inicio': () => InicioScreen(
          usuario: _admin,
          sede: _sede,
          onIrA: (_) {},
        ),
        'Mesas': () => Scaffold(body: MesasScreen(usuario: _admin)),
        'Cocina': () => const Scaffold(body: CocinaScreen()),
        'Cocina (caja)': () =>
            const Scaffold(body: CocinaScreen(modoCaja: true)),
        'Reportes': () => const ReportesScreen(),
      };
      for (final e in pantallas.entries) {
        final r = await revisar(tester, e.value());
        problemas.addAll(r.map((x) => '${e.key}: $x'));
        await tester.pumpWidget(const SizedBox());
      }
      if (problemas.isNotEmpty) {
        fail('Desbordes en ${t.key}:\n${problemas.toSet().join('\n')}');
      }
    });

    testWidgets('Configuración (todas las pestañas) en ${t.key}', (
      tester,
    ) async {
      tester.view.physicalSize = t.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final problemas = <String>[];
      final anterior = FlutterError.onError;
      final fallos = <FlutterErrorDetails>[];
      FlutterError.onError = fallos.add;
      await tester.pumpWidget(
        const MaterialApp(home: ConfiguracionScreen(usuario: _admin)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      for (final pestana in const [
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
        final f = find.text(pestana);
        if (f.evaluate().isEmpty) {
          problemas.add('Configuración: no se encontró la pestaña "$pestana"');
          continue;
        }
        await tester.ensureVisible(f.first);
        await tester.pump();
        await tester.tap(f.first);
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        problemas.addAll(
          _desbordes(fallos).map((x) => '$pestana: $x'),
        );
        fallos.clear();
      }
      FlutterError.onError = anterior;
      await tester.pumpWidget(const SizedBox());
      if (problemas.isNotEmpty) {
        fail('Desbordes en ${t.key}:\n${problemas.toSet().join('\n')}');
      }
    });
  }
}

List<String> _desbordes(List<FlutterErrorDetails> fallos) {
  final r = <String>[];
  for (final f in fallos) {
    final texto = f.toString();
    if (!texto.contains('overflowed')) continue;
    final lineas = texto
        .split('\n')
        .where(
          (l) =>
              l.contains('overflowed') ||
              RegExp(r'lib/[a-z_/]+\.dart:\d+').hasMatch(l),
        )
        .take(2)
        .join(' | ');
    r.add(lineas);
  }
  return r;
}
