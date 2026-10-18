import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/borrador_pedido_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/models/sede.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/home_screen.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/auth_service.dart';
import 'package:frontend_bijao/theme/app_theme.dart';
import 'package:frontend_bijao/widgets/punto_aviso.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mozo = Usuario(
  id: 'u1',
  nombre: 'ana',
  email: 'a@a',
  rol: AppRole.mesero,
);

const _linea = PedidoLine(
  id: 'l1',
  cartaId: 'c1',
  nombrePlato: 'Tacacho',
  cantidad: 1,
  modificadores: [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: 12,
  descuentoAplicado: 0,
  precioTotalLinea: 12,
);

BorradorPedido _borrador(String usuarioId) => BorradorPedido(
  usuarioId: usuarioId,
  tipo: 'mesa',
  mesaNumero: null,
  mesaId: null,
  carrito: const [_linea],
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

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
    limpiarBorradorPedido();
    AuthService.instance.userNotifier.value = _mozo;
  });

  tearDown(() {
    limpiarBorradorPedido();
    AuthService.instance.userNotifier.value = null;
  });

  Future<void> abrir(WidgetTester tester, Size tam) async {
    tester.view.physicalSize = tam;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          sede: Sede(id: '1', ruc: '1', direccion: 'Av. 1'),
          usuario: _mozo,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> avanzar(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  for (final t in {
    'menú lateral': const Size(1400, 900),
    'barra inferior': const Size(375, 812),
  }.entries) {
    testWidgets('${t.key}: avisa que hay un pedido sin confirmar', (
      tester,
    ) async {
      await abrir(tester, t.value);
      expect(find.byType(PuntoAviso), findsNothing);

      // Se sale de Pedidos con el pedido a medias.
      borradorPedido = _borrador('u1');
      await avanzar(tester);
      expect(find.byType(PuntoAviso), findsOneWidget);

      // Se confirma o se cierra: el aviso se va.
      limpiarBorradorPedido();
      await avanzar(tester);
      expect(find.byType(PuntoAviso), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('el borrador de otro usuario no muestra el aviso', (
    tester,
  ) async {
    await abrir(tester, const Size(1400, 900));
    borradorPedido = _borrador('otro');
    await avanzar(tester);
    expect(find.byType(PuntoAviso), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('el aviso usa el mismo color mostaza que el estado Pendiente', () {
    expect(AppColors.pendiente, const Color(0xFFCA8A04));
  });
}
