import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/pagos_store.dart';
import 'package:frontend_bijao/data/pedidos_store.dart';
import 'package:frontend_bijao/models/incidencia.dart';
import 'package:frontend_bijao/models/pago_detalle.dart';
import 'package:frontend_bijao/models/pedido.dart';
import 'package:frontend_bijao/models/pedido_line.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/devolucion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pedidoId = '01925b6a-9b1d-7234-a123-abcdef012345';
const _lineaId = '01925b6a-9b1d-7234-a123-abcdef0123aa';
const _medioId = '01925b6a-9b1d-7234-a123-abcdef0123bb';

Pedido _pedido() => Pedido(
  id: _pedidoId,
  numeroPedido: '0007',
  mesaNumero: 0,
  tipoPedido: 'llevar',
  estado: 'servido',
  fechaPedido: DateTime(2026, 10, 20, 14, 0),
  usuarioId: 'u1',
);

const _linea = PedidoLine(
  id: _lineaId,
  cartaId: 'c1',
  nombrePlato: 'Ceviche',
  cantidad: 1,
  modificadores: [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: 40,
  descuentoAplicado: 0,
  precioTotalLinea: 40,
);

ReporteProblema _reporte(String resolucion, {String? medio}) => (
  categoria: 'No le gustó',
  detalle: 'Muy salado',
  evidencia: null,
  foto: null,
  nombreFoto: null,
  resolucion: resolucion,
  reemplazoNombre: null,
  reemplazoPrecio: null,
  reemplazoCartaId: null,
  medioReembolsoId: medio,
);

void main() {
  late HttpServer servidor;
  final peticiones = <String>[];
  final cuerpos = <Map<String, dynamic>>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
  });

  setUp(() async {
    pagos.clear();
    pagoDetalles.clear();
    peticiones.clear();
    cuerpos.clear();
    detallesPorPedido[_pedidoId] = [_linea];
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
    servidor.listen((req) async {
      final texto = await utf8.decoder.bind(req).join();
      peticiones.add('${req.method} ${req.uri.path}');
      if (texto.isNotEmpty) cuerpos.add(jsonDecode(texto));
      req.response.headers.contentType = ContentType.json;
      if (req.uri.path.endsWith('/devolver')) {
        final tipo = cuerpos.last['tipo_devolucion'];
        req.response.write(
          jsonEncode({
            'devolucion_id': 'd1',
            'tipo_devolucion': tipo,
            if (tipo == 'vale') 'vale_codigo': 'VALE-3D8F91A2',
            if (tipo == 'vale') 'fecha_vencimiento': '2026-11-19',
          }),
        );
      } else {
        req.response.write(jsonEncode([]));
      }
      await req.response.close();
    });
  });

  tearDown(() async {
    await servidor.close(force: true);
    pagos.clear();
    pagoDetalles.clear();
    detallesPorPedido.remove(_pedidoId);
  });

  test('solo se hace en el servidor con pedido y línea del servidor', () {
    expect(
      DevolucionService.instance.puedeEnServidor(_pedido(), _linea),
      isTrue,
    );
    final demo = _pedido().copyWith(id: '12');
    expect(DevolucionService.instance.puedeEnServidor(demo, _linea), isFalse);
  });

  test(
    'reembolso de lo ya pagado: manda efectivo con el monto pagado',
    () async {
      pagoDetalles.add(
        const PagoDetalle(
          pagoId: 'p1',
          pedidoDetalleId: _lineaId,
          montoAplicado: 25,
        ),
      );
      final resumen = await DevolucionService.instance.devolver(
        pedido: _pedido(),
        linea: _linea,
        reporte: _reporte('reembolso', medio: _medioId),
      );
      expect(
        peticiones.first,
        'POST /api/v1/caja/pedidos/$_pedidoId/items/$_lineaId/devolver',
      );
      expect(cuerpos.first['tipo_devolucion'], 'efectivo');
      // Se devuelve lo pagado de esa línea, no todo su precio.
      expect(cuerpos.first['monto'], 25);
      expect(cuerpos.first['medio_pago_id'], _medioId);
      expect(cuerpos.first['motivo'], 'No le gustó: Muy salado');
      expect(resumen, 'Reembolso de S/ 25.00.');
    },
  );

  test('vale: manda el vale y devuelve su código y vigencia', () async {
    final resumen = await DevolucionService.instance.devolver(
      pedido: _pedido(),
      linea: _linea,
      reporte: _reporte('vale'),
    );
    expect(cuerpos.first['tipo_devolucion'], 'vale');
    expect(cuerpos.first['monto'], 40);
    expect(
      resumen,
      'Vale VALE-3D8F91A2 por S/ 40.00, válido hasta 2026-11-19.',
    );
  });

  test('nota de crédito: solo la baja, la nota se emite aparte', () async {
    final resumen = await DevolucionService.instance.devolver(
      pedido: _pedido(),
      linea: _linea,
      reporte: _reporte('nota_credito'),
    );
    expect(cuerpos.first['tipo_devolucion'], 'nota_credito');
    expect(resumen, contains('se emite aparte'));
  });

  test('una resolución desconocida no llama al servidor', () async {
    await expectLater(
      DevolucionService.instance.devolver(
        pedido: _pedido(),
        linea: _linea,
        reporte: _reporte('otra'),
      ),
      throwsA(predicate((e) => e.toString().contains('no válida'))),
    );
    expect(peticiones, isEmpty);
  });
}
