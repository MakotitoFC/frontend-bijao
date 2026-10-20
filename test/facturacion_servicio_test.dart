import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/comprobante.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/facturacion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pedidoId = '01925b6a-9b1d-7234-a123-abcdef012345';

Map<String, dynamic> _json({
  String tipo = 'boleta',
  String estado = 'ACEPTADO',
}) => {
  'id': '7f09cb8d-56cb-4ca0-9856-749e7b23395b',
  'pedidos_id': _pedidoId,
  'tipo_documento': tipo,
  'serie': 'B001',
  'numero': 104,
  'numero_comprobante': 'B001-00000104',
  'fecha_emision': '2026-10-20',
  'hora_emision': '00:15:20',
  'cliente_tipo_doc': '1',
  'cliente_num_doc': '72458912',
  'cliente_denominacion': 'JUAN PEREZ',
  'total': '52.00',
  'total_igv': '7.93',
  'estado_sunat': estado,
  'pdf_ticket_url': 'https://x.pe/ticket.pdf',
};

void main() {
  late HttpServer servidor;
  final peticiones = <String>[];
  final consultas = <Map<String, String>>[];
  final cuerpos = <Map<String, dynamic>>[];
  Object respuesta = {};

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.initialize();
  });

  setUp(() async {
    peticiones.clear();
    consultas.clear();
    cuerpos.clear();
    respuesta = {};
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
    servidor.listen((req) async {
      final texto = await utf8.decoder.bind(req).join();
      peticiones.add('${req.method} ${req.uri.path}');
      consultas.add(req.uri.queryParameters);
      if (texto.isNotEmpty) cuerpos.add(jsonDecode(texto));
      req.response.headers.contentType = ContentType.json;
      req.response.statusCode =
          req.method == 'POST' && req.uri.path.endsWith('/comprobantes')
          ? 201
          : 200;
      req.response.write(jsonEncode(respuesta));
      await req.response.close();
    });
  });

  tearDown(() async => servidor.close(force: true));

  test('el comprobante lee sus datos y sus estados', () {
    final c = Comprobante.fromJson(_json());
    expect(c.numeroComprobante, 'B001-00000104');
    expect(c.tipoEtiqueta, 'Boleta');
    expect(c.total, 52);
    expect(c.estadoEtiqueta, 'Aceptado');
    expect(c.puedeAnularse, isTrue);
    expect(
      Comprobante.fromJson(_json(estado: 'ANULADO')).puedeAnularse,
      isFalse,
    );
    expect(
      Comprobante.fromJson(_json(estado: 'RECHAZADO')).puedeAnularse,
      isFalse,
    );
    expect(Comprobante.fromJson(_json(estado: 'PENDIENTE')).pendiente, isTrue);
    expect(
      Comprobante.fromJson(_json(tipo: 'ticket_venta', estado: 'NO_APLICA'))
          .esInterno,
      isTrue,
    );
  });

  test('un RUC solo se factura si esta ACTIVO y HABIDO', () {
    RucInfo ruc(String e, String c) => RucInfo(
      ruc: '20100070970',
      razonSocial: 'X',
      direccionFiscal: 'Y',
      estado: e,
      condicion: c,
    );
    expect(ruc('ACTIVO', 'HABIDO').puedeFacturarse, isTrue);
    expect(ruc('BAJA DE OFICIO', 'HABIDO').puedeFacturarse, isFalse);
    expect(ruc('ACTIVO', 'NO HABIDO').puedeFacturarse, isFalse);
  });

  test('consultarRuc pide el RUC y lee razon social y direccion', () async {
    respuesta = {
      'ruc': '20100070970',
      'razon_social': 'SUPERMERCADOS PERUANOS S.A.',
      'direccion_fiscal': 'CAL. MORELLI 181',
      'estado': 'ACTIVO',
      'condicion': 'HABIDO',
    };
    final r = await FacturacionService.instance.consultarRuc(' 20100070970 ');
    expect(peticiones.single, 'GET /api/v1/facturacion/ruc/20100070970');
    expect(r.razonSocial, 'SUPERMERCADOS PERUANOS S.A.');
    expect(r.puedeFacturarse, isTrue);
  });

  test('boleta con DNI manda los datos del cliente', () async {
    respuesta = _json();
    final c = await FacturacionService.instance.emitir(
      pedidoId: _pedidoId,
      tipoDocumento: 'boleta',
      clienteTipoDoc: '1',
      clienteNumDoc: '72458912',
      clienteDenominacion: 'JUAN PEREZ',
    );
    expect(peticiones.single, 'POST /api/v1/facturacion/comprobantes');
    expect(cuerpos.single['pedido_id'], _pedidoId);
    expect(cuerpos.single['tipo_documento'], 'boleta');
    expect(cuerpos.single['cliente_tipo_doc'], '1');
    expect(cuerpos.single['cliente_num_doc'], '72458912');
    expect(cuerpos.single['imprimir'], true);
    expect(c.numeroComprobante, 'B001-00000104');
  });

  test('el ticket de venta no manda datos de cliente', () async {
    respuesta = _json(tipo: 'ticket_venta', estado: 'NO_APLICA');
    await FacturacionService.instance.emitir(
      pedidoId: _pedidoId,
      tipoDocumento: 'ticket_venta',
      imprimir: false,
    );
    expect(cuerpos.single.keys.toSet(), {
      'pedido_id',
      'tipo_documento',
      'imprimir',
    });
    expect(cuerpos.single['imprimir'], false);
  });

  test('listar pide el rango de fechas en el formato del servidor', () async {
    respuesta = [_json(), _json(estado: 'ANULADO')];
    final lista = await FacturacionService.instance.listar(
      desde: DateTime(2026, 10, 20),
      hasta: DateTime(2026, 10, 20),
    );
    expect(consultas.single['desde'], '2026-10-20');
    expect(consultas.single['hasta'], '2026-10-20');
    expect(lista, hasLength(2));
    expect(lista.last.anulado, isTrue);
  });

  test('anular manda el motivo; reimprimir y estado usan su ruta', () async {
    respuesta = {'mensaje': 'ok'};
    await FacturacionService.instance.anular('c1', motivo: 'Error de monto');
    expect(peticiones.last, 'POST /api/v1/facturacion/comprobantes/c1/anular');
    expect(cuerpos.last['motivo'], 'Error de monto');
    await FacturacionService.instance.reimprimir('c1');
    expect(
      peticiones.last,
      'POST /api/v1/facturacion/comprobantes/c1/imprimir',
    );
    respuesta = _json(estado: 'PENDIENTE');
    final c = await FacturacionService.instance.consultarEstado('c1');
    expect(
      peticiones.last,
      'POST /api/v1/facturacion/comprobantes/c1/consultar-status',
    );
    expect(c.pendiente, isTrue);
  });
}
