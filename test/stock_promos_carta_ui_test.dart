import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/data/disponibilidad_store.dart';
import 'package:frontend_bijao/models/disponibilidad.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/categoria_comida.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/carta_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/promociones_config.dart';
import 'package:frontend_bijao/widgets/stock_diario_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Stock diario, Promociones y Carta (productos) en celular, tablet y escritorio:
// se dibujan sin desbordes (con letra normal y grande) y sus acciones
// principales responden.
const _admin = Usuario(
  id: 'a1',
  nombre: 'Admin',
  email: 'a@a',
  rol: AppRole.administrador,
);

const _tamanos = {
  'celular chico': Size(320, 640),
  'celular': Size(375, 812),
  'tablet': Size(768, 1024),
  'escritorio': Size(1400, 900),
};

CartaItem _plato(String id, String nombre, double precio, {String? estado}) =>
    CartaItem(
      id: id,
      nombrePlato: nombre,
      descripcion: 'Rico $nombre',
      categoriaId: 'cat1',
      categoriaNombre: 'Platos criollos',
      subcategoriaIds: const [],
      precioCliente: precio,
      estado: estado ?? estadoDisponible,
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    AuthService.instance.userNotifier.value = _admin;
    configStockNotifier.value = const SedeConfigStock(sedeId: 's1');
    cartasNotifier.value = [
      _plato('c1', 'Arroz chaufa', 18),
      _plato('c2', 'Tacacho con cecina y chorizo regional', 25.5),
      _plato('c3', 'Jugo de camu camu', 7, estado: estadoAgotado),
    ];
  });

  tearDown(() {
    cartasNotifier.value = [];
    configStockNotifier.value = null;
    AuthService.instance.userNotifier.value = null;
  });

  Future<void> abrir(
    WidgetTester tester,
    Widget pantalla,
    Size tam,
    double letra,
  ) async {
    tester.view.physicalSize = tam;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(letra)),
          child: child!,
        ),
        home: Scaffold(body: pantalla),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  for (final t in _tamanos.entries) {
    for (final letra in const [1.0, 1.3]) {
      final nombre = '${t.key} · letra $letra';

      testWidgets('Stock diario — $nombre', (tester) async {
        await abrir(tester, const StockDiarioConfig(), t.value, letra);
        expect(tester.takeException(), isNull);
        expect(find.text('Cantidades diarias de platos'), findsOneWidget);
        expect(find.text('Exigir apertura diaria'), findsOneWidget);
        expect(find.text('Permitir sobreventa'), findsOneWidget);
        expect(find.text('Marcar agotado automáticamente'), findsOneWidget);
        // La apertura del día está oculta (AppConfig.mostrarAperturaDia).
        expect(find.text('Apertura del día'), findsNothing);
        expect(find.text('1. Definir cantidades base'), findsNothing);
        expect(find.text('2. Abrir el día de hoy'), findsNothing);
      });

      testWidgets('Promociones — $nombre', (tester) async {
        await abrir(tester, const PromocionesConfig(), t.value, letra);
        expect(tester.takeException(), isNull);
        // El botón para crear una promoción está y abre su formulario.
        final boton = find
            .ancestor(
              of: find.text('Promoción'),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            )
            .first;
        await tester.ensureVisible(boton);
        await tester.tap(boton);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(tester.takeException(), isNull);
        expect(find.text('Nueva promoción'), findsOneWidget);
        expect(find.text('Paso 1 de 3'), findsOneWidget);
        expect(find.text('Siguiente'), findsOneWidget);
      });

      testWidgets('Carta (productos) — $nombre', (tester) async {
        final seleccion = ValueNotifier<CategoriaComida?>(null);
        final busqueda = ValueNotifier<String>('');
        await abrir(
          tester,
          CartaScreen(
            esAdmin: true,
            usuario: _admin,
            seleccion: seleccion,
            busqueda: busqueda,
            cabeceraPropia: t.value.width < 700,
          ),
          t.value,
          letra,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Arroz chaufa'), findsWidgets);
        expect(find.textContaining('Tacacho'), findsWidgets);

        // El buscador de la carta filtra por nombre.
        busqueda.value = 'arroz';
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Arroz chaufa'), findsWidgets);
        expect(find.textContaining('Tacacho'), findsNothing);
        busqueda.value = 'no existe';
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Arroz chaufa'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
