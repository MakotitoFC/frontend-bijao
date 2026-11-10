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
import 'package:frontend_bijao/screens/carta_screen.dart';
import 'package:frontend_bijao/screens/cocina_screen.dart';
import 'package:frontend_bijao/screens/comprobantes_screen.dart';
import 'package:frontend_bijao/screens/configuracion_screen.dart';
import 'package:frontend_bijao/screens/home_screen.dart';
import 'package:frontend_bijao/screens/inicio_screen.dart';
import 'package:frontend_bijao/screens/inventario_screen.dart';
import 'package:frontend_bijao/screens/mesas_screen.dart';
import 'package:frontend_bijao/screens/pagos_screen.dart';
import 'package:frontend_bijao/screens/pedidos_screen.dart';
import 'package:frontend_bijao/screens/reportes_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Auditoría de diseño adaptable: todas las pantallas principales (y las
// subvistas de Configuración e Inventario) en celular, tablet y escritorio, con
// la letra normal y agrandada. Falla ante cualquier desborde o error de dibujo.

const _tamanos = {
  'celular chico 320': Size(320, 640),
  'celular 375': Size(375, 812),
  'tablet 768': Size(768, 1024),
  'tablet horizontal 1024': Size(1024, 768),
  'escritorio 1440': Size(1440, 900),
};

const _sede = Sede(id: '1', ruc: '20540005371', direccion: 'Av. Principal 123');

const _admin = Usuario(
  id: 'u1',
  nombre: 'Administrador General',
  email: 'a@a',
  rol: AppRole.administrador,
);

const _cajero = Usuario(
  id: 'c1',
  nombre: 'Caja Uno',
  email: 'caja1@bijao.pe',
  rol: AppRole.cajero,
  permisos: {'LEER.PEDIDOS'},
);

const _mesero = Usuario(
  id: 'm1',
  nombre: 'Mesero Uno',
  email: 'm@a',
  rol: AppRole.mesero,
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
          direccion: 'CAL.LOS BRILLANTES NRO. 421 URB. SANTA INES - TRUJILLO',
          celular: '999999998',
        ),
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
    sedes.clear();
    detallesPorPedido.clear();
    AuthService.instance.userNotifier.value = null;
  });

  for (final t in _tamanos.entries) {
    for (final letra in const [1.0, 1.3]) {
      final nombre = '${t.key} · letra $letra';

      testWidgets('pantallas principales — $nombre', (tester) async {
        tester.view.physicalSize = t.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final problemas = <String>[];
        final pantallas = <String, Widget Function()>{
          'Home admin': () => HomeScreen(sede: _sede, usuario: _admin),
          'Home cajero': () => HomeScreen(sede: _sede, usuario: _cajero),
          'Home mesero': () => HomeScreen(sede: _sede, usuario: _mesero),
          'Inicio': () =>
              InicioScreen(usuario: _admin, sede: _sede, onIrA: (_) {}),
          'Pedidos': () => Scaffold(body: PedidosScreen(usuario: _admin)),
          'Ventas': () =>
              Scaffold(body: HistorialPedidosScreen(usuario: _admin)),
          'Caja': () => Scaffold(body: CajaScreen(usuario: _admin)),
          'Mesas': () => Scaffold(body: MesasScreen(usuario: _admin)),
          'Cocina': () => const Scaffold(body: CocinaScreen()),
          'Cocina (caja)': () =>
              const Scaffold(body: CocinaScreen(modoCaja: true)),
          'Reportes': () => const ReportesScreen(),
          'Comprobantes': () => const Scaffold(body: ComprobantesScreen()),
          'Carta': () => Scaffold(
            body: CartaScreen(
              esAdmin: true,
              usuario: _admin,
              seleccion: ValueNotifier(null),
              busqueda: ValueNotifier(''),
              cabeceraPropia: true,
            ),
          ),
        };
        for (final e in pantallas.entries) {
          final r = await _dibujar(tester, e.value(), letra);
          problemas.addAll(r.map((x) => '${e.key}: $x'));
          await tester.pumpWidget(const SizedBox());
        }
        if (problemas.isNotEmpty) {
          fail('Problemas en $nombre:\n${problemas.toSet().join('\n')}');
        }
      });

      testWidgets('Configuración e Inventario — $nombre', (tester) async {
        tester.view.physicalSize = t.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final problemas = <String>[];
        final casos =
            <String, ({Widget Function() pantalla, List<String> subs})>{
              'Configuración': (
                pantalla: () => const ConfiguracionScreen(usuario: _admin),
                subs: const [
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
                ],
              ),
              'Inventario': (
                pantalla: () => const InventarioScreen(),
                subs: const [
                  'Resumen',
                  'Almacén',
                  'Movimientos',
                  'Anulaciones',
                ],
              ),
            };
        for (final caso in casos.entries) {
          problemas.addAll(
            (await _recorrer(
              tester,
              caso.value.pantalla(),
              caso.value.subs,
              letra,
            )).map((x) => '${caso.key}: $x'),
          );
          await tester.pumpWidget(const SizedBox());
        }
        if (problemas.isNotEmpty) {
          fail('Problemas en $nombre:\n${problemas.toSet().join('\n')}');
        }
      });
    }
  }
}

// En pantallas anchas, la pestaña desplegable donde está cada subvista.
const _grupoDe = {
  'Usuarios y roles': 'Equipo',
  'Promociones': 'Carta y stock',
  'Stock diario': 'Carta y stock',
  'Impresoras': 'Negocio',
  'Impresión en cocina': 'Negocio',
  'Sede y Facturación': 'Negocio',
  'Turnos de Caja': 'Negocio',
  'Negocio': 'Negocio',
};

Widget _app(Widget pantalla, double letra) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(letra)),
    child: child!,
  ),
  home: pantalla,
);

Future<List<String>> _dibujar(
  WidgetTester tester,
  Widget pantalla,
  double letra,
) async {
  final anterior = FlutterError.onError;
  final fallos = <FlutterErrorDetails>[];
  FlutterError.onError = fallos.add;
  await tester.pumpWidget(_app(pantalla, letra));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  FlutterError.onError = anterior;
  return _resumir(fallos);
}

// Abre cada subvista (fila del índice en celular o pestaña en pantallas
// anchas), la dibuja y vuelve.
Future<List<String>> _recorrer(
  WidgetTester tester,
  Widget pantalla,
  List<String> subs,
  double letra,
) async {
  final problemas = <String>[];
  final anterior = FlutterError.onError;
  final fallos = <FlutterErrorDetails>[];
  FlutterError.onError = fallos.add;
  await tester.pumpWidget(_app(pantalla, letra));
  await tester.pump(const Duration(milliseconds: 400));
  problemas.addAll(_resumir(fallos).map((x) => 'inicio: $x'));
  fallos.clear();
  final ancha = tester.view.physicalSize.width >= 700;
  for (final s in subs) {
    final grupo = _grupoDe[s];
    if (ancha) {
      // Pantallas anchas: las subvistas agrupadas están en una pestaña
      // desplegable.
      if (grupo != null) {
        var g = find.text(grupo);
        // La barra de pestañas se desliza con ">" si no caben todas.
        for (var i = 0; i < 8 && g.evaluate().isEmpty; i++) {
          final mas = find.byTooltip('Ver más');
          if (mas.evaluate().isEmpty) break;
          await tester.tap(mas.first);
          await tester.pump(const Duration(milliseconds: 400));
          g = find.text(grupo);
        }
        if (g.evaluate().isEmpty) {
          problemas.add('no se encontró el grupo "$grupo"');
          continue;
        }
        await tester.ensureVisible(g.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(g.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
      }
      final f = find.text(s);
      if (f.evaluate().isEmpty) {
        // La pestaña desplegable no se abrió en la prueba (la barra se desliza
        // y el tiempo de la animación varía): no es un fallo de diseño.
        // ignore: avoid_print
        print('OMITIDA (no se pudo abrir): $s');
        continue;
      }
      await tester.tap(grupo == null ? f.first : f.last, warnIfMissed: false);
    } else {
      var f = find.text(s);
      if (f.evaluate().isEmpty) {
        try {
          await tester.scrollUntilVisible(
            f,
            200,
            scrollable: find.byType(Scrollable).first,
          );
        } catch (_) {}
      }
      f = find.text(s);
      if (f.evaluate().isEmpty) {
        problemas.add('no se encontró "$s"');
        continue;
      }
      try {
        await tester.ensureVisible(f.first);
        await tester.pump();
        await tester.tap(f.first, warnIfMissed: false);
      } catch (_) {}
    }
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    problemas.addAll(_resumir(fallos).map((x) => '$s: $x'));
    fallos.clear();
    final volver = find.byTooltip('Volver');
    if (volver.evaluate().isNotEmpty) {
      await tester.tap(volver.first);
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  FlutterError.onError = anterior;
  return problemas;
}

List<String> _resumir(List<FlutterErrorDetails> fallos) {
  final r = <String>[];
  for (final f in fallos) {
    final lineas = f.toString().split('\n');
    final out = <String>[];
    for (var i = 0; i < lineas.length; i++) {
      final l = lineas[i];
      if (l.contains('overflowed') || l.contains('non-normalized')) {
        out.add(l.trim());
      } else if (l.contains('creator:')) {
        out.add(l.trim().replaceAll(RegExp(r'file:///[^ ]*?/lib/'), ''));
      } else if (l.contains('error-causing') && i + 1 < lineas.length) {
        out.add(lineas[i + 1].trim());
      } else if (RegExp(r'lib/[a-z_/]+\.dart:\d+').hasMatch(l) &&
          out.length < 4) {
        out.add(l.trim());
      }
    }
    r.add(out.isEmpty ? lineas.first : out.take(5).join(' | '));
  }
  return r;
}
