import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/cartas_store.dart';
import 'package:frontend_bijao/data/disponibilidad_store.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/disponibilidad.dart';
import 'package:frontend_bijao/utils/error_disponibilidad.dart';

CartaDisponibilidad _fila(
  String carta, {
  String? pres,
  String? vari,
  int? inicial,
  int? disp,
  bool agotado = false,
}) => CartaDisponibilidad(
  id: '$carta-$pres-$vari',
  sedeId: 's',
  fecha: '2026-10-12',
  cartaId: carta,
  cartaPresentacionId: pres,
  cartaVarianteId: vari,
  cantidadInicial: inicial,
  cantidadDisponible: disp,
  agotado: agotado,
);

void main() {
  const libre = SedeConfigStock(sedeId: 's');
  const estricta = SedeConfigStock(sedeId: 's', requiereAperturaDiaria: true);

  test('sin fila de hoy el plato se vende libre, aunque la sede tenga apertura', () {
    expect(
      estadoDisponibilidadDe('a', config: libre, filas: []).tipo,
      TipoDisponibilidad.libre,
    );
    // La apertura diaria ya no limita las ventas.
    expect(
      estadoDisponibilidadDe('a', config: estricta, filas: []).vendible,
      true,
    );
  });

  test('la cantidad diaria ya no limita: solo cuenta el agotado manual', () {
    final filas = [
      _fila('tacacho', inicial: 3, disp: 2),
      _fila('pollo', agotado: true),
      _fila('sopa', inicial: 5, disp: 0),
      _fila('chicha'),
    ];
    final t = estadoDisponibilidadDe('tacacho', config: libre, filas: filas);
    expect(t.tipo, TipoDisponibilidad.sinLimite);
    expect(t.etiqueta, isNull); // sin "Quedan N"
    expect(
      estadoDisponibilidadDe('pollo', config: libre, filas: filas).tipo,
      TipoDisponibilidad.agotado,
    );
    expect(
      estadoDisponibilidadDe('sopa', config: libre, filas: filas).vendible,
      true,
    );
    expect(
      estadoDisponibilidadDe('chicha', config: estricta, filas: filas).tipo,
      TipoDisponibilidad.sinLimite,
    );
  });

  test('fila exacta de variante y respaldo en la general', () {
    final filas = [
      _fila('pescado', vari: 'grande', inicial: 1, disp: 1),
      _fila('pescado', agotado: true),
    ];
    expect(
      estadoDisponibilidadDe(
        'pescado',
        varianteId: 'grande',
        config: libre,
        filas: filas,
      ).tipo,
      TipoDisponibilidad.sinLimite,
    );
    expect(
      estadoDisponibilidadDe(
        'pescado',
        varianteId: 'mediano',
        config: libre,
        filas: filas,
      ).tipo,
      TipoDisponibilidad.agotado,
    );
  });

  group('agotado en inventario', () {
    tearDown(() {
      cartasNotifier.value = [];
      configStockNotifier.value = null;
    });

    void cargar({required bool bloquear}) {
      cartasNotifier.value = [
        const CartaItem(
          id: 'agua',
          nombrePlato: 'Agua',
          descripcion: '',
          categoriaId: 'c',
          agotadoInventario: true,
        ),
        const CartaItem(
          id: 'cecina',
          nombrePlato: 'Cecina',
          descripcion: '',
          categoriaId: 'c',
        ),
      ];
      configStockNotifier.value = SedeConfigStock(
        sedeId: 's',
        bloquearAgotadoInventario: bloquear,
      );
    }

    test('por defecto se sigue vendiendo: etiqueta "Agotado" pero vendible', () {
      cargar(bloquear: false);
      final e = estadoDisponibilidadDe('agua', filas: []);
      expect(e.tipo, TipoDisponibilidad.agotadoInventario);
      expect(e.etiqueta, 'Agotado');
      expect(e.vendible, true);
      expect(estadoDisponibilidadDe('cecina', filas: []).etiqueta, isNull);
    });

    test('un plato por agotarse se etiqueta pero se vende normal', () {
      cartasNotifier.value = [
        const CartaItem(
          id: 'chicha',
          nombrePlato: 'Chicha',
          descripcion: '',
          categoriaId: 'c',
          stockBajoInventario: true,
        ),
      ];
      configStockNotifier.value = const SedeConfigStock(
        sedeId: 's',
        bloquearAgotadoInventario: true,
      );
      final e = estadoDisponibilidadDe('chicha', filas: []);
      expect(e.tipo, TipoDisponibilidad.stockBajoInventario);
      expect(e.etiqueta, 'Por agotarse'); // sin cantidad calculable
      // Aun con el bloqueo activo, "por agotarse" no frena la venta.
      expect(e.vendible, true);
    });

    test('por agotarse con cantidad: "Quedan N" solo en ese caso', () {
      cartasNotifier.value = [
        const CartaItem(
          id: 'agua',
          nombrePlato: 'Agua',
          descripcion: '',
          categoriaId: 'c',
          stockBajoInventario: true,
          quedanInventario: 3,
        ),
        const CartaItem(
          id: 'cecina',
          nombrePlato: 'Cecina',
          descripcion: '',
          categoriaId: 'c',
        ),
      ];
      final e = estadoDisponibilidadDe('agua', filas: []);
      expect(e.quedan, 3);
      expect(e.etiqueta, 'Quedan 3');
      expect(estadoDisponibilidadDe('cecina', filas: []).etiqueta, isNull);
      expect(
        CartaItem.fromJson({
          'id': 'x',
          'nombre_plato': 'X',
          'categoria_comida_id': 'c',
          'stock_bajo_inventario': true,
          'quedan_inventario': 4,
        }).quedanInventario,
        4,
      );
    });

    test('con el bloqueo activo el plato agotado no se puede pedir', () {
      cargar(bloquear: true);
      final e = estadoDisponibilidadDe('agua', filas: []);
      expect(e.etiqueta, 'Agotado');
      expect(e.vendible, false);
      expect(estadoDisponibilidadDe('cecina', filas: []).vendible, true);
    });

    test('el "Agotado hoy" manual tiene prioridad sobre el de inventario', () {
      cargar(bloquear: false);
      final e = estadoDisponibilidadDe(
        'agua',
        filas: [_fila('agua', agotado: true)],
      );
      expect(e.tipo, TipoDisponibilidad.agotado);
    });

    test('la configuración lee bloquear_agotado_inventario', () {
      expect(
        SedeConfigStock.fromJson({'sede_id': 's'}).bloquearAgotadoInventario,
        false,
      );
      expect(
        SedeConfigStock.fromJson({
          'sede_id': 's',
          'bloquear_agotado_inventario': true,
        }).bloquearAgotadoInventario,
        true,
      );
    });
  });

  test('lectura del error de stock', () {
    final a = ErrorDisponibilidad.tryParse(
      "el plato 'Tacacho con Cecina' se encuentra agotado",
    );
    expect(a?.motivo, MotivoStock.agotado);
    expect(a?.plato, 'Tacacho con Cecina');
    final i = ErrorDisponibilidad.tryParse(
      "Error: stock insuficiente de 'Tacacho': disponibles 1, requeridos 2",
    );
    expect(i?.motivo, MotivoStock.insuficiente);
    expect(i?.disponibles, 1);
    expect(i?.requeridos, 2);
    expect(
      ErrorDisponibilidad.tryParse(
        'el plato requiere apertura diaria y no ha sido abierto hoy',
      )?.motivo,
      MotivoStock.sinApertura,
    );
    expect(
      ErrorDisponibilidad.tryParse('la cantidad debe ser mayor a 0'),
      null,
    );
  });

  test('no hay tope de unidades: el stock no limita los pedidos', () {
    disponibilidadHoyNotifier.value = [
      _fila('tacacho', inicial: 3, disp: 2),
      _fila('pollo', agotado: true),
    ];
    configStockNotifier.value = libre;
    expect(topeDeUnidades('tacacho'), null);
    expect(topeDeUnidades('otro'), null);
    disponibilidadHoyNotifier.value = [];
    configStockNotifier.value = null;
  });
}
