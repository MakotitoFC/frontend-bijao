import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/data/disponibilidad_store.dart';
import 'package:frontend_bijao/data/mesas_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/app_role.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/disponibilidad.dart';
import 'package:frontend_bijao/models/mesa.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/models/sede.dart';
import 'package:frontend_bijao/models/taper.dart';
import 'package:frontend_bijao/models/usuario.dart';
import 'package:frontend_bijao/screens/inicio_screen.dart';
import 'package:frontend_bijao/utils/resumen_inicio.dart';

final _ahora = DateTime(2026, 10, 15, 13, 0);

Pedido _pedido(
  String id, {
  String estado = 'pendiente',
  String tipo = 'mesa',
  int mesa = 1,
  int minutos = 5,
  String usuario = 'u1',
}) => Pedido(
  id: id,
  numeroPedido: id,
  mesaNumero: mesa,
  tipoPedido: tipo,
  estado: estado,
  fechaPedido: _ahora.subtract(Duration(minutes: minutos)),
  usuarioId: usuario,
);

const _plato = CartaItem(
  id: 'c1',
  nombrePlato: 'Tacacho',
  descripcion: '',
  categoriaId: 'k',
);
const _agotado = CartaItem(
  id: 'c2',
  nombrePlato: 'Ceviche',
  descripcion: '',
  categoriaId: 'k',
  estado: 'agotado',
);

double _total(String id) => id == 'a' ? 30 : (id == 'b' ? 20 : 10);

void main() {
  tearDown(() {
    pedidos.clear();
    detallesPorPedido.clear();
    mesas.clear();
    cartasNotifier.value = [];
    disponibilidadHoyNotifier.value = [];
    configStockNotifier.value = null;
  });

  test('las cifras salen de pedidos abiertos, mesas, stock y tápers', () {
    disponibilidadHoyNotifier.value = [
      const CartaDisponibilidad(
        id: 'd1',
        sedeId: 's',
        fecha: '2026-10-15',
        cartaId: 'c1',
        agotado: true,
      ),
    ];
    final r = calcularResumenInicio(
      pedidos: [
        _pedido('a', minutos: 30),
        _pedido('b', minutos: 10, mesa: 2),
        _pedido('c', estado: 'servido', tipo: 'llevar', mesa: 0),
        _pedido('d', estado: 'pagado'), // cobrado: no cuenta
        _pedido('e', tipo: 'delivery', mesa: 0, usuario: 'u2'),
      ],
      totalDe: _total,
      mesas: [
        const Mesa(id: 'm1', numero: 1, estado: 'ocupada'),
        const Mesa(id: 'm2', numero: 2, estado: 'ocupada'),
        const Mesa(id: 'm3', numero: 3, estado: 'disponible'),
      ],
      cartas: [_plato, _agotado],
      tapers: [
        const Taper(
          id: 't1',
          nombre: 'Grande',
          precio: 1,
          stock: 1,
          stockMinimo: 2,
        ),
        const Taper(
          id: 't2',
          nombre: 'Mediano',
          precio: 1,
          stock: 9,
          stockMinimo: 2,
        ),
      ],
      ahora: _ahora,
    );

    expect(r.activos, 4);
    expect(r.pendientes, 3);
    expect(r.servidos, 1);
    expect([r.enMesa, r.paraLlevar, r.delivery], [2, 1, 1]);
    expect(r.porCobrar, 30 + 20 + 10 + 10);
    expect([r.mesasOcupadas, r.mesasLibres, r.mesasTotal], [2, 1, 3]);
    expect(r.masAntiguo?.id, 'a');
    expect(r.masEsperando.map((p) => p.id), ['a', 'b', 'e']);
    expect(r.esperaPromedio, const Duration(minutes: 15)); // (30+10+5)/3
    expect(r.pendientesLentos, 1);
    expect(r.platosAgotados, ['Ceviche', 'Tacacho']); // por orden alfabético
    expect(r.tapersBajos, ['Grande']);
  });

  test('el mozo solo ve lo suyo', () {
    final r = calcularResumenInicio(
      pedidos: [
        _pedido('a', usuario: 'u1'),
        _pedido('b', usuario: 'u1', mesa: 2),
        _pedido('c', usuario: 'u2', mesa: 3),
      ],
      totalDe: _total,
      mesas: const [],
      cartas: const [],
      tapers: const [],
      ahora: _ahora,
      soloUsuarioId: 'u1',
    );
    expect(r.activos, 2);
    expect(r.mesasConPedido, 2);
    expect(r.porCobrar, 50);
  });

  test('sin pedidos no hay espera ni más antiguo', () {
    final r = calcularResumenInicio(
      pedidos: const [],
      totalDe: _total,
      mesas: const [],
      cartas: const [],
      tapers: const [],
      ahora: _ahora,
    );
    expect(r.esperaPromedio, isNull);
    expect(r.masAntiguo, isNull);
    expect(r.masEsperando, isEmpty);
  });

  test('duraciones en palabras', () {
    expect(textoDeDuracion(const Duration(seconds: 20)), 'menos de 1 min');
    expect(textoDeDuracion(const Duration(minutes: 12)), '12 min');
    expect(textoDeDuracion(const Duration(minutes: 65)), '1 h 05 min');
  });

  for (final rol in [
    AppRole.administrador,
    AppRole.mesero,
    AppRole.cajero,
    AppRole.trabajador,
  ]) {
    testWidgets('Inicio se dibuja para ${rol.label}', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      mesas.addAll(const [
        Mesa(id: 'm1', numero: 1, estado: 'ocupada'),
        Mesa(id: 'm2', numero: 2, estado: 'disponible'),
      ]);
      cartasNotifier.value = [_plato, _agotado];
      pedidos.add(_pedido('a', usuario: 'u1', minutos: 25));
      detallesPorPedido['a'] = [
        const PedidoLine(
          id: 'l',
          cartaId: 'c1',
          nombrePlato: 'Tacacho',
          cantidad: 2,
          modificadores: [],
          presentacion: null,
          promocion: null,
          comentario: null,
          precioUnitario: 15,
          descuentoAplicado: 0,
          precioTotalLinea: 30,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: InicioScreen(
            usuario: Usuario(
              id: 'u1',
              nombre: 'ana',
              email: 'a@a',
              rol: rol,
              permisos: const {},
            ),
            sede: const Sede(id: '1', ruc: '1', direccion: 'Av. Principal 123'),
            onIrA: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Hola, ana'), findsOneWidget);
      expect(find.text('Alertas'), findsOneWidget);
      expect(find.text('Esperando más tiempo'), findsOneWidget);
      expect(find.text('#a'), findsOneWidget);
      // Sin desbordes ni errores de dibujo.
      expect(tester.takeException(), isNull);

      // Desmonta para cancelar los temporizadores.
      await tester.pumpWidget(const SizedBox());
    });
  }
}
