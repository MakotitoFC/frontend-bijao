import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/disponibilidad_store.dart';
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
  const sobreventa = SedeConfigStock(sedeId: 's', permiteSobreventa: true);

  test('sin fila: libre o sin abrir según la sede', () {
    expect(
      estadoDisponibilidadDe('a', config: libre, filas: []).tipo,
      TipoDisponibilidad.libre,
    );
    expect(
      estadoDisponibilidadDe('a', config: estricta, filas: []).vendible,
      false,
    );
  });

  test('con cantidad, agotado y sin límite', () {
    final filas = [
      _fila('tacacho', inicial: 3, disp: 2),
      _fila('pollo', agotado: true),
      _fila('sopa', inicial: 5, disp: 0),
      _fila('chicha'),
    ];
    final t = estadoDisponibilidadDe('tacacho', config: libre, filas: filas);
    expect(t.tipo, TipoDisponibilidad.conCantidad);
    expect(t.quedan, 2);
    expect(t.etiqueta, 'Quedan 2');
    expect(
      estadoDisponibilidadDe('pollo', config: libre, filas: filas).tipo,
      TipoDisponibilidad.agotado,
    );
    expect(
      estadoDisponibilidadDe('sopa', config: libre, filas: filas).vendible,
      false,
    );
    expect(
      estadoDisponibilidadDe('sopa', config: sobreventa, filas: filas).vendible,
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
      TipoDisponibilidad.conCantidad,
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

  test('tope de unidades: lo que quedó en "Abrir el día"', () {
    disponibilidadHoyNotifier.value = [
      _fila('tacacho', inicial: 3, disp: 2),
      _fila('pollo', agotado: true),
      _fila('jugo'),
    ];
    configStockNotifier.value = libre;
    expect(topeDeUnidades('tacacho'), 2);
    expect(topeDeUnidades('jugo'), null); // sin cantidad registrada
    expect(topeDeUnidades('otro'), null); // sin fila de hoy
    configStockNotifier.value = sobreventa;
    expect(topeDeUnidades('tacacho'), null); // con sobreventa no hay tope
    disponibilidadHoyNotifier.value = [];
    configStockNotifier.value = null;
  });
}
