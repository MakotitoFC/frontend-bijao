import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/categoria_comida.dart';
import 'package:frontend_bijao/models/sede.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/carta_form_screen.dart';
import 'package:frontend_bijao/screens/carta_screen.dart';
import 'package:frontend_bijao/screens/home_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/utils/blur_dialog.dart';
import 'package:frontend_bijao/widgets/dialogo_app.dart';
import 'package:frontend_bijao/widgets/inventario/inventario_comun.dart';
import 'package:frontend_bijao/widgets/producto_inventario_form_dialog.dart';
import 'package:frontend_bijao/widgets/tipo_producto_form_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Usuario _usuario(AppRole rol) => Usuario(
  id: 'u1',
  nombre: 'Ana',
  email: 'a@a',
  rol: rol,
  permisos: const {},
);

const _ancho = 375.0;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
  });

  tearDown(() {
    cartasNotifier.value = [];
    AuthService.instance.userNotifier.value = null;
  });

  // Abre un modal desde un botón, con una pantalla de celular.
  Future<void> abrirModal(WidgetTester tester, WidgetBuilder modal) async {
    tester.view.physicalSize = const Size(_ancho, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showBlurDialog<void>(context: context, builder: modal),
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
  }

  testWidgets('en celular los modales ocupan todo el ancho y salen de abajo', (
    tester,
  ) async {
    for (final modal in <WidgetBuilder>[
      (_) => const ProductoInventarioFormDialog(),
      (_) => const TipoProductoFormDialog(),
      (c) => AlertaApp(
        title: const Text('Eliminar'),
        content: const Text('¿Seguro?'),
        actions: [TextButton(onPressed: () {}, child: const Text('Ok'))],
      ),
    ]) {
      await abrirModal(tester, modal);
      final caja = find.byType(DialogoApp);
      expect(caja, findsOneWidget);
      // De lado a lado, sin margen lateral...
      expect(tester.getSize(caja).width, _ancho);
      expect(tester.getTopLeft(caja).dx, 0);
      // ...y pegado al borde inferior de la pantalla.
      expect(tester.getBottomLeft(caja).dy, 812);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('la confirmación de acciones usa el mismo diseño', (
    tester,
  ) async {
    bool? resultado;
    tester.view.physicalSize = const Size(_ancho, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => resultado = await confirmarAccion(
                context,
                titulo: 'Eliminar producto',
                mensaje: '¿Eliminar "Arroz"?',
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
    expect(find.text('Eliminar producto'), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(resultado, true);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    '"Más" muestra tarjetas en dos columnas y los grupos con título',
    (tester) async {
      tester.view.physicalSize = const Size(_ancho, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final u = _usuario(AppRole.administrador);
      AuthService.instance.userNotifier.value = u;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            sede: const Sede(id: '1', ruc: '1', direccion: 'Av. Principal 123'),
            usuario: u,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Más'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.text('Más opciones'), findsOneWidget);
      // El grupo "Ventas" va como título gris con sus tarjetas debajo.
      expect(find.text('Ventas'), findsWidgets);
      final reportes = find.text('Reportes');
      final caja = find.text('Caja');
      expect(reportes, findsWidgets);
      expect(caja, findsWidgets);

      // Dos columnas: dos tarjetas por fila con el mismo ancho, que juntas
      // llenan el ancho de la hoja menos el margen.
      final hijos = find.text('Historial de pedidos');
      expect(hijos, findsOneWidget);
      final a = tester.getTopLeft(find.text('Historial de pedidos')).dy;
      final b = tester.getTopLeft(find.text('Caja').last).dy;
      expect(a, b); // misma fila
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Carta: el admin ve el botón de foto y todos los productos; el '
      'mozo no ve los inhabilitados', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    cartasNotifier.value = const [
      CartaItem(
        id: 'c1',
        nombrePlato: 'Tacacho',
        descripcion: '',
        categoriaId: 'k',
        precioCliente: 12,
      ),
      CartaItem(
        id: 'c2',
        nombrePlato: 'Ceviche',
        descripcion: '',
        categoriaId: 'k',
        precioCliente: 25,
        estado: estadoInhabilitado,
      ),
    ];

    Future<void> pintar(Usuario u, bool admin) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CartaScreen(
            esAdmin: admin,
            usuario: u,
            seleccion: ValueNotifier<CategoriaComida?>(null),
            busqueda: ValueNotifier(''),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    await pintar(_usuario(AppRole.administrador), true);
    expect(find.text('Tacacho'), findsOneWidget);
    expect(find.text('Ceviche'), findsOneWidget);
    expect(find.byTooltip('Subir foto'), findsNWidgets(2));
    expect(find.byTooltip('Habilitar'), findsOneWidget); // el del inhabilitado
    await tester.pumpWidget(const SizedBox());

    await pintar(_usuario(AppRole.mesero), false);
    expect(find.text('Tacacho'), findsOneWidget);
    expect(find.text('Ceviche'), findsNothing);
    expect(find.byTooltip('Subir foto'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('el formulario de plato trae el bloque para subir la foto', (
    tester,
  ) async {
    for (final item in <CartaItem?>[
      null,
      const CartaItem(
        id: 'c1',
        nombrePlato: 'Tacacho',
        descripcion: 'x',
        categoriaId: 'k',
        precioCliente: 12,
      ),
    ]) {
      await abrirModal(tester, (_) => CartaFormScreen(item: item));
      expect(find.text('Foto del plato'), findsOneWidget);
      expect(find.text('Subir foto'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
    await abrirModal(
      tester,
      (_) => const CartaFormScreen(
        item: CartaItem(
          id: 'c1',
          nombrePlato: 'Tacacho',
          descripcion: 'x',
          categoriaId: 'k',
          urlImagen: '/uploads/evidencias/2026-10/a.jpg',
        ),
      ),
    );
    expect(find.text('Cambiar foto'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
