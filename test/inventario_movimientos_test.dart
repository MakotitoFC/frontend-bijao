import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/catalogos_store.dart';
import 'package:frontend_bijao/data/inventario_store.dart';
import 'package:frontend_bijao/models/inventario_movimiento.dart';
import 'package:frontend_bijao/models/tipo_movimiento.dart';
import 'package:frontend_bijao/services/api_client.dart';
import 'package:frontend_bijao/services/catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _producto = '01925b6a-9b1d-7234-a123-abcdef012345';

Map<String, dynamic> _json({
  String id = 'm1',
  String tipoId = movEntradaManualId,
  String codigo = 'entrada_manual',
  String nombre = 'Entrada manual',
  double cantidad = 50,
}) => {
  'id': id,
  'producto_inventario_id': _producto,
  'producto_nombre': 'Táper Rey',
  'tipo_movimiento_id': tipoId,
  'tipo_movimiento_codigo': codigo,
  'tipo_movimiento_nombre': nombre,
  'cantidad': cantidad,
  'costo_unitario': 0.5,
  'costo_total': 25.0,
  'usuario_nombre': 'admin',
  'fecha': '2026-10-17T18:30:00Z',
  'notas': 'Reposición',
};

void main() {
  test('el movimiento del backend se lee con su tipo y magnitud positiva', () {
    final entrada = InventarioMovimiento.fromJson(_json());
    expect(entrada.tipoMovimiento.codigo, 'entrada_manual');
    expect(entrada.tipoMovimiento.esEntrada, true);
    expect(entrada.cantidad, 50);
    expect(entrada.usuarioNombre, 'admin');
    expect(entrada.costoTotal, 25);

    // Una salida llega con cantidad negativa: se muestra como magnitud.
    final salida = InventarioMovimiento.fromJson(
      _json(
        tipoId: movSalidaManualId,
        codigo: 'salida_manual',
        nombre: 'Salida manual',
        cantidad: -3,
      ),
    );
    expect(salida.cantidad, 3);
    expect(salida.tipoMovimiento.esEntrada, false);

    // Tipo desconocido: el signo sale de la cantidad guardada.
    final raro = InventarioMovimiento.fromJson(
      _json(tipoId: 'otro-uuid', codigo: 'x', nombre: 'Otro', cantidad: -2),
    );
    expect(raro.tipoMovimiento.esEntrada, false);
  });

  test('los tipos de movimiento son UUID y se comparan por id', () {
    expect(movEntradaManual.id, '55551111-1111-1111-1111-111111111107');
    final copia = TipoMovimiento.fromJson({
      'id': movEntradaManualId,
      'codigo': 'entrada_manual',
      'tipo_movimiento': 'Entrada manual',
      'signo': 1,
    });
    expect(copia == movEntradaManual, true);
    expect(codigosMovimientoManual.contains('merma'), true);
    expect(codigosMovimientoManual.contains('salida_venta'), false);
  });

  group('contra el backend', () {
    late HttpServer servidor;
    final peticiones = <String>[];
    final cuerpos = <String>[];
    var stock = 0.0;
    final movimientosServidor = <Map<String, dynamic>>[];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ApiClient.instance.initialize();
      peticiones.clear();
      cuerpos.clear();
      stock = 0;
      movimientosServidor.clear();
      productosInventario.clear();
      movimientosInventario.clear();
      servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      ApiClient.instance.setBaseUrl('http://127.0.0.1:${servidor.port}');
      servidor.listen((req) async {
        final texto = await utf8.decoder.bind(req).join();
        final consulta = req.uri.query.isEmpty ? '' : '?${req.uri.query}';
        peticiones.add('${req.method} ${req.uri.path}$consulta');
        cuerpos.add(texto);
        Object cuerpo = [];
        var estado = 200;
        final ruta = req.uri.path;
        if (ruta == '/api/tipos-movimiento') {
          cuerpo = [
            {
              'id': movEntradaManualId,
              'codigo': 'entrada_manual',
              'tipo_movimiento': 'Entrada manual',
              'signo': 1,
              'estado': true,
            },
            {
              'id': movSalidaManualId,
              'codigo': 'salida_manual',
              'tipo_movimiento': 'Salida manual',
              'signo': -1,
              'estado': true,
            },
          ];
        } else if (ruta == '/api/productos-inventario') {
          cuerpo = [
            {
              'id': _producto,
              'nombre': 'Táper Rey',
              'tipo_producto_id': 't',
              'unidad_producto_id': 'u',
              'stock_actual': stock,
            },
          ];
        } else if (ruta == '/api/inventario-movimientos') {
          if (req.method == 'POST') {
            final b = jsonDecode(texto) as Map<String, dynamic>;
            stock += (b['cantidad'] as num).toDouble();
            final m = _json(cantidad: (b['cantidad'] as num).toDouble());
            movimientosServidor.insert(0, m);
            cuerpo = m;
            estado = 201;
          } else {
            cuerpo = movimientosServidor;
          }
        }
        req.response
          ..statusCode = estado
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(cuerpo));
        await req.response.close();
      });
    });

    tearDown(() async => servidor.close(force: true));

    test('el ajuste se envía al backend y el stock sale de la base', () async {
      await CatalogService.instance.cargarProductosInventario();
      expect(productosInventario.single.stockActual, 0);

      final m = await CatalogService.instance.registrarAjusteInventario(
        productoInventarioId: _producto,
        tipoMovimientoId: movEntradaManualId,
        cantidad: 50,
        notas: 'Reposición',
      );

      final i = peticiones.indexOf('POST /api/inventario-movimientos');
      expect(i, isNot(-1));
      final enviado = jsonDecode(cuerpos[i]) as Map<String, dynamic>;
      expect(enviado['tipo_movimiento_id'], movEntradaManualId);
      expect(enviado['producto_inventario_id'], _producto);
      expect(enviado['cantidad'], 50);
      expect(enviado['notas'], 'Reposición');
      expect(m.tipoMovimiento.codigo, 'entrada_manual');
      // Se volvió a leer el producto: el stock es el de la base de datos.
      expect(productosInventario.single.stockActual, 50);
      expect(movimientosInventario[_producto]!.first.cantidad, 50);
    });

    test('la actividad se lee del backend y sobrevive a recargar', () async {
      movimientosServidor.add(_json());
      await CatalogService.instance.cargarMovimientosInventario();
      expect(movimientosInventario[_producto]!.length, 1);

      // "Recargar la pantalla": se vacía lo local y se vuelve a leer.
      movimientosInventario.clear();
      await CatalogService.instance.cargarMovimientosInventario();
      expect(movimientosInventario[_producto]!.length, 1);

      await CatalogService.instance.cargarMovimientosInventario(
        productoId: _producto,
      );
      expect(
        peticiones,
        contains(
          'GET /api/inventario-movimientos?producto_inventario_id=$_producto',
        ),
      );
    });

    test('el catálogo de tipos se sincroniza con el backend', () async {
      await CatalogService.instance.cargarTiposMovimiento();
      expect(tiposMovimiento.length, 2);
      expect(tiposMovimiento.first.id, movEntradaManualId);
    });
  });
}
