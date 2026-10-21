import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/borrador_pedido_store.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/carta_presentacion.dart';
import 'package:frontend_bijao/models/carta_variante.dart';
import 'package:frontend_bijao/models/modificador.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/models/promocion_componente.dart';
import 'package:frontend_bijao/models/unidad_bebida.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/widgets/nuevo_pedido_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mozo = Usuario(
  id: 'u1',
  nombre: 'ana',
  email: 'a@a',
  rol: AppRole.mesero,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    limpiarBorradorPedido();
    AuthService.instance.userNotifier.value = _mozo;
    cartasNotifier.value = [
      const CartaItem(
        id: 'c1',
        nombrePlato: 'Tacacho',
        descripcion: '',
        categoriaId: 'k',
        precioCliente: 12,
        stock: 10,
      ),
    ];
  });

  tearDown(() {
    AuthService.instance.userNotifier.value = null;
    cartasNotifier.value = [];
    limpiarBorradorPedido();
  });

  Widget dialogo({
    Usuario usuario = _mozo,
    VoidCallback? alCerrar,
    ValueChanged<bool>? alTerminar,
  }) => MaterialApp(
    home: Scaffold(
      body: NuevoPedidoDialog(
        key: UniqueKey(),
        usuario: usuario,
        tipo: 'llevar',
        onTerminar: alTerminar ?? (_) {},
        onVolver: alCerrar ?? () {},
      ),
    ),
  );

  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> agregarTacacho(WidgetTester tester) async {
    await tester.tap(find.text('Agregar al pedido').first);
    await esperar(tester);
    await tester.tap(find.textContaining('Agregar S/'));
    await esperar(tester);
  }

  testWidgets('al salir de la vista y volver, el pedido en armado sigue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(dialogo());
    await esperar(tester);
    await agregarTacacho(tester);
    await tester.tap(find.byTooltip('Ver detalle completo'));
    await esperar(tester);
    await tester.enterText(find.byType(TextField).first, 'Carlos');
    await tester.tap(find.text('Seguir agregando'));
    await esperar(tester);
    expect(find.textContaining('Pedido · 1 producto'), findsOneWidget);

    // El usuario cambia de vista: la pantalla se destruye.
    await tester.pumpWidget(const SizedBox());
    expect(borradorDe('u1')?.carrito.length, 1);

    // Vuelve a Pedidos: el pedido está como lo dejó.
    await tester.pumpWidget(dialogo());
    await esperar(tester);
    expect(find.textContaining('Pedido · 1 producto'), findsOneWidget);
    expect(borradorDe('u1')?.nombre, 'Carlos');
    await tester.tap(find.byTooltip('Ver detalle completo'));
    await esperar(tester);
    expect(find.text('Carlos'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mientras se arma, el pedido se va guardando en el dispositivo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(dialogo());
    await esperar(tester);
    await agregarTacacho(tester);
    // Pasan unos segundos con la pantalla abierta (autoguardado).
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    final guardado = await tester.runAsync(() async {
      final p = await SharedPreferences.getInstance();
      return p.getString('borrador_pedido_u1');
    });
    expect(guardado, isNotNull);
    expect(guardado, contains('Tacacho'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'si el envío falla, el pedido sigue guardado y listo para reintentar',
    (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var terminado = false;
      await tester.pumpWidget(dialogo(alTerminar: (_) => terminado = true));
      await esperar(tester);
      await agregarTacacho(tester);

      // Las llamadas HTTP de las pruebas fallan: es un envío que no llega.
      await tester.tap(find.text('Confirmar pedido'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(terminado, false);
      final b = borradorDe('u1');
      expect(b, isNotNull);
      expect(b!.enviando, false);
      expect(b.carrito.length, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('cerrar con la "x" descarta el pedido en armado', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var terminado = false;
    await tester.pumpWidget(dialogo(alTerminar: (_) => terminado = true));
    await esperar(tester);
    await agregarTacacho(tester);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    expect(terminado, true);

    await tester.pumpWidget(const SizedBox());
    expect(borradorPedido, isNull);

    await tester.pumpWidget(dialogo());
    await esperar(tester);
    expect(find.text('Aún no agregas productos'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('el borrador de un usuario no lo ve otro', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(dialogo());
    await esperar(tester);
    await agregarTacacho(tester);
    await tester.pumpWidget(const SizedBox());
    expect(borradorDe('u1'), isNotNull);
    expect(borradorDe('u2'), isNull);

    const otro = Usuario(
      id: 'u2',
      nombre: 'luis',
      email: 'l@l',
      rol: AppRole.mesero,
    );
    AuthService.instance.userNotifier.value = otro;
    await tester.pumpWidget(dialogo(usuario: otro));
    await esperar(tester);
    expect(find.text('Aún no agregas productos'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('un pedido recién abierto y vacío no se guarda', () {
    final vacio = BorradorPedido(
      usuarioId: 'u1',
      tipo: 'mesa',
      mesaNumero: null,
      mesaId: null,
      carrito: [],
      descEmpleado: false,
      propina: 0,
      tupper: (grande: 0, precioGrande: 0, mediano: 0, precioMediano: 0),
      nombre: '',
      telefono: '',
      direccion: '',
      referencia: '',
      envio: '',
      notas: '',
    );
    expect(vacio.tieneContenido, false);
  });

  testWidgets('al cerrar sesión no queda ninguna copia del pedido', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(dialogo());
    await esperar(tester);
    await agregarTacacho(tester);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    final antes = await tester.runAsync(() async {
      final p = await SharedPreferences.getInstance();
      return p.getString('borrador_pedido_u1');
    });
    expect(antes, isNotNull);

    // Cierra sesión (la pantalla se destruye justo después).
    await tester.runAsync(() => AuthService.instance.logout());
    await tester.pumpWidget(const SizedBox());

    final despues = await tester.runAsync(() async {
      final p = await SharedPreferences.getInstance();
      return p.getString('borrador_pedido_u1');
    });
    expect(despues, isNull);
    expect(borradorPedido, isNull);
  });

  group('guardado en el dispositivo', () {
    const linea = PedidoLine(
      id: 'l1',
      cartaId: 'c1',
      nombrePlato: 'Tacacho',
      cantidad: 2,
      modificadores: [
        Modificador(
          id: 'm1',
          cartaId: 'c1',
          nombre: 'Sin cebolla',
          tipo: 'quitar',
          precioAjuste: 0,
        ),
      ],
      presentacion: CartaPresentacion(
        id: 'pr1',
        cartaId: 'c1',
        unidad: UnidadBebida(id: '2', unidadPresentacion: 'Jarra'),
        volumenMl: 1000,
        precioCliente: 9,
      ),
      promocion: null,
      comentario: 'bien dorado',
      precioUnitario: 12,
      descuentoAplicado: 1,
      precioTotalLinea: 23,
      tipoEntrega: 'llevar',
      aplicaTaper: true,
      taperId: 't1',
      precioTaper: 1.5,
      variante: CartaVariante(
        id: 'v1',
        cartaId: 'c1',
        nombre: 'Grande',
        precioCliente: 12,
        precioPersonal: 10,
      ),
      componentes: [
        ComponenteElegido(
          componenteId: 'co1',
          opcionId: 'op1',
          cartaId: 'c2',
          nombre: 'Jugo',
          cantidad: 1,
          esCambio: true,
          precio: 4,
          precioAjuste: 1,
        ),
      ],
    );

    BorradorPedido borrador(String usuario, {bool enviando = false}) =>
        BorradorPedido(
          usuarioId: usuario,
          tipo: 'llevar',
          mesaNumero: null,
          mesaId: null,
          carrito: const [linea],
          descEmpleado: true,
          propina: 2,
          tupper: (grande: 1, precioGrande: 1.5, mediano: 0, precioMediano: 1),
          nombre: 'Carlos',
          telefono: '999',
          direccion: 'Av. 1',
          referencia: '',
          envio: '3.00',
          notas: 'sin picante',
          enviando: enviando,
        );

    Future<String?> guardadoEnDispositivo(String usuario) async {
      final p = await SharedPreferences.getInstance();
      return p.getString('borrador_pedido_$usuario');
    }

    test('el pedido a medias se guarda y se recupera igual', () async {
      await guardarBorradorYEsperar(borrador('u1'));
      expect(await guardadoEnDispositivo('u1'), isNotNull);

      // "Se cerró y se volvió a abrir la app": se vacía la memoria y se carga.
      olvidarBorradorEnMemoria();
      expect(borradorDe('u1'), isNull);
      await cargarBorradorGuardado('u1');

      final b = borradorDe('u1')!;
      expect(b.nombre, 'Carlos');
      expect(b.envio, '3.00');
      expect(b.propina, 2);
      expect(b.descEmpleado, true);
      expect(b.tupper.grande, 1);
      final l = b.carrito.single;
      expect(l.cantidad, 2);
      expect(l.modificadores.single.nombre, 'Sin cebolla');
      expect(l.presentacion?.unidad.unidadPresentacion, 'Jarra');
      expect(l.variante?.nombre, 'Grande');
      expect(l.componentes.single.esCambio, true);
      expect(l.componentes.single.precioAjuste, 1);
      expect(l.tipoEntrega, 'llevar');
      expect(l.aplicaTaper, true);
      expect(l.comentario, 'bien dorado');
      expect(l.precioTotalLinea, 23);
    });

    test(
      'al enviarse el pedido se borra de inmediato del dispositivo',
      () async {
        await guardarBorradorYEsperar(borrador('u1'));
        expect(await guardadoEnDispositivo('u1'), isNotNull);

        await descartarBorradorYEsperar();

        expect(borradorPedido, isNull);
        expect(await guardadoEnDispositivo('u1'), isNull);
        // Y al volver a abrir la app no reaparece.
        await cargarBorradorGuardado('u1');
        expect(borradorDe('u1'), isNull);
      },
    );

    test('limpiar (cerrar con la "x") también borra del dispositivo', () async {
      borradorPedido = borrador('u1');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await guardadoEnDispositivo('u1'), isNotNull);
      limpiarBorradorPedido();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await guardadoEnDispositivo('u1'), isNull);
    });

    test(
      'un pedido que se estaba enviando al cerrarse la app se descarta',
      () async {
        await guardarBorradorYEsperar(borrador('u1', enviando: true));
        olvidarBorradorEnMemoria();
        await cargarBorradorGuardado('u1');
        expect(borradorDe('u1'), isNull);
        expect(await guardadoEnDispositivo('u1'), isNull);
      },
    );

    test('un borrador de más de 30 minutos se descarta', () async {
      final viejo = borrador('u1').toJson()
        ..['guardado_en'] = DateTime.now()
            .subtract(const Duration(minutes: 31))
            .toIso8601String();
      SharedPreferences.setMockInitialValues({
        'borrador_pedido_u1': jsonEncode(viejo),
      });
      await cargarBorradorGuardado('u1');
      expect(borradorDe('u1'), isNull);
      expect(await guardadoEnDispositivo('u1'), isNull);
    });

    test('cada usuario ve solo su borrador', () async {
      await guardarBorradorYEsperar(borrador('u1'));
      olvidarBorradorEnMemoria();
      await cargarBorradorGuardado('u2');
      expect(borradorDe('u2'), isNull);
      expect(await guardadoEnDispositivo('u1'), isNotNull);
    });

    test('un dato dañado se descarta sin fallar', () async {
      SharedPreferences.setMockInitialValues({
        'borrador_pedido_u1': '{no es json',
      });
      await cargarBorradorGuardado('u1');
      expect(borradorDe('u1'), isNull);
      expect(await guardadoEnDispositivo('u1'), isNull);
    });
  });
}
