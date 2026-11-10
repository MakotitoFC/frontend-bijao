import '../data/catalogos_store.dart';
import '../data/configuracion_store.dart';
import '../data/inventario_store.dart';
import '../data/movimientos_caja_store.dart';
import '../models/inventario_movimiento.dart';
import '../models/medio_pago.dart';
import '../models/movimiento_caja.dart';
import '../models/producto_inventario.dart';
import 'catalog_service.dart';
import 'movimiento_caja_service.dart';

// Un alquiler de menaje (por ejemplo, manteles). No tiene tabla propia: es un
// ingreso de Caja de la categoría "Alquiler" que lleva en su nota la ficha
// (producto, cantidad, precio, cliente y si ya volvió), y dos movimientos del
// libro de inventario: la salida y, al devolverlo, la entrada.
class Alquiler {
  final MovimientoCaja movimiento;
  final String productoId;
  final int cantidad;
  final double precioUnitario;
  final String cliente;
  final String? notas;
  final DateTime? devueltoEl;

  const Alquiler({
    required this.movimiento,
    required this.productoId,
    required this.cantidad,
    required this.precioUnitario,
    required this.cliente,
    this.notas,
    this.devueltoEl,
  });

  String get id => movimiento.id;
  double get monto => movimiento.monto;
  bool get anulado => movimiento.anulado;
  bool get devuelto => devueltoEl != null;
  // Sigue afuera: no se devolvió ni se anuló.
  bool get afuera => !devuelto && !anulado;

  static const _marca = '[ALQ:';
  static final _reMarca = RegExp(r'\[ALQ:([0-9a-fA-F-]{36}):(\d+):([0-9.]+)\]');
  static final _reDev = RegExp(r'\[DEV:([^\]]+)\]');

  // Arma la nota que se guarda en el movimiento de Caja.
  static String codificar({
    required ProductoInventario producto,
    required int cantidad,
    required double precioUnitario,
    required String cliente,
    String? notas,
    DateTime? devueltoEl,
  }) {
    final c = cliente.trim();
    final n = (notas ?? '').trim();
    return [
      'Alquiler: $cantidad× ${producto.nombre}',
      if (c.isNotEmpty) 'Cliente: $c',
      if (n.isNotEmpty) 'Notas: $n',
      '$_marca${producto.id}:$cantidad:${precioUnitario.toStringAsFixed(2)}]',
      if (devueltoEl != null) '[DEV:${devueltoEl.toIso8601String()}]',
    ].join('\n');
  }

  // Lee un movimiento de Caja; null si no es un alquiler.
  static Alquiler? deMovimiento(MovimientoCaja m) {
    final nota = m.nota ?? '';
    final marca = _reMarca.firstMatch(nota);
    if (marca == null) return null;
    String? campo(String prefijo) {
      for (final l in nota.split('\n')) {
        if (l.startsWith(prefijo)) return l.substring(prefijo.length).trim();
      }
      return null;
    }

    final dev = _reDev.firstMatch(nota);
    return Alquiler(
      movimiento: m,
      productoId: marca.group(1)!,
      cantidad: int.tryParse(marca.group(2)!) ?? 1,
      precioUnitario: double.tryParse(marca.group(3)!) ?? 0,
      cliente: campo('Cliente:') ?? '',
      notas: campo('Notas:'),
      devueltoEl: dev == null ? null : DateTime.tryParse(dev.group(1)!),
    );
  }
}

class AlquilerService {
  AlquilerService._();
  static final AlquilerService instance = AlquilerService._();

  final _caja = MovimientoCajaService.instance;
  final _catalogo = CatalogService.instance;

  // Alquileres de los últimos [dias] días, del más reciente al más antiguo.
  Future<List<Alquiler>> listar({int dias = 120}) async {
    final hoy = DateTime.now();
    final movs = await _caja.listarRango(
      hoy.subtract(Duration(days: dias)),
      hoy,
    );
    return [for (final m in movs) ?Alquiler.deMovimiento(m)];
  }

  // Cuántas unidades del producto están afuera ahora mismo.
  static int afueraDe(Iterable<Alquiler> todos, String productoId) => todos
      .where((a) => a.afuera && a.productoId == productoId)
      .fold(0, (s, a) => s + a.cantidad);

  Future<CategoriaMovimiento> _categoria() =>
      _caja.categoriaAsegurada('Alquiler', TipoMovimiento.ingreso);

  // Cobra el alquiler (ingreso en Caja) y saca las unidades del almacén. Si la
  // salida de stock falla, se anula el ingreso para no dejar un cobro a medias.
  Future<Alquiler> registrar({
    required ProductoInventario producto,
    required int cantidad,
    required double precioUnitario,
    required String cliente,
    String? notas,
    required MedioPago medio,
  }) async {
    if (cantidad <= 0) throw Exception('Ingresa una cantidad mayor a 0');
    if (precioUnitario <= 0) throw Exception('Ingresa el precio');
    if (cantidad > producto.stockActual) {
      throw Exception(
        'Solo hay ${producto.stockActual.toStringAsFixed(0)} disponibles de '
        '"${producto.nombre}".',
      );
    }
    final cat = await _categoria();
    final mov = await _caja.registrar(
      categoria: cat,
      monto: cantidad * precioUnitario,
      medio: medio,
      nota: Alquiler.codificar(
        producto: producto,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
        cliente: cliente,
        notas: notas,
      ),
    );
    try {
      await _catalogo.registrarAjusteInventario(
        productoInventarioId: producto.id,
        tipoMovimientoId: movSalidaManualId,
        cantidad: cantidad.toDouble(),
        notas:
            'Alquiler #${mov.id}${cliente.trim().isEmpty ? '' : ' · $cliente'}',
      );
    } catch (e) {
      try {
        await _caja.anular(
          mov,
          motivo: 'No se pudo registrar la salida de stock',
        );
      } catch (_) {}
      rethrow;
    }
    return Alquiler.deMovimiento(mov)!;
  }

  MedioPago _medioDe(MovimientoCaja m) =>
      mediosPago.where((x) => x.id == m.medioPagoId).firstOrNull ??
      mediosPagoActivos.first;

  Future<CategoriaMovimiento> _categoriaDe(MovimientoCaja m) async =>
      categoriasMovimiento.where((c) => c.id == m.categoriaId).firstOrNull ??
      await _categoria();

  // Corrige el cliente, el precio, el medio de pago y las notas. Las unidades
  // no cambian: para eso se anula el alquiler y se registra otro.
  Future<void> editar(
    Alquiler a, {
    required double precioUnitario,
    required String cliente,
    String? notas,
    required MedioPago medio,
  }) async {
    final producto = productosInventario
        .where((p) => p.id == a.productoId)
        .firstOrNull;
    if (producto == null) throw Exception('El producto ya no existe');
    await _caja.editar(
      a.movimiento,
      categoria: await _categoriaDe(a.movimiento),
      monto: a.cantidad * precioUnitario,
      medio: medio,
      nota: Alquiler.codificar(
        producto: producto,
        cantidad: a.cantidad,
        precioUnitario: precioUnitario,
        cliente: cliente,
        notas: notas,
        devueltoEl: a.devueltoEl,
      ),
    );
  }

  // El producto volvió: entran las unidades al almacén y el alquiler queda
  // marcado como devuelto.
  Future<void> devolver(Alquiler a) async {
    final producto = productosInventario
        .where((p) => p.id == a.productoId)
        .firstOrNull;
    if (producto == null) throw Exception('El producto ya no existe');
    await _catalogo.registrarAjusteInventario(
      productoInventarioId: producto.id,
      tipoMovimientoId: movEntradaManualId,
      cantidad: a.cantidad.toDouble(),
      notas: 'Devolución de alquiler #${a.id}',
    );
    await _caja.editar(
      a.movimiento,
      categoria: await _categoriaDe(a.movimiento),
      monto: a.monto,
      medio: _medioDe(a.movimiento),
      nota: Alquiler.codificar(
        producto: producto,
        cantidad: a.cantidad,
        precioUnitario: a.precioUnitario,
        cliente: a.cliente,
        notas: a.notas,
        devueltoEl: DateTime.now(),
      ),
    );
  }

  // Anula el alquiler: revierte la salida (y la entrada, si ya se devolvió) y
  // anula el ingreso de Caja con su motivo. No se borra nada.
  Future<void> anular(Alquiler a, {required String motivo}) async {
    if (motivo.trim().isEmpty) {
      throw Exception('Escribe el motivo de la anulación');
    }
    final todos = await _catalogo.cargarMovimientosInventario();
    final revertidos = {
      for (final m in todos)
        if (m.revierteId != null) m.revierteId,
    };
    final propios = <InventarioMovimiento>[
      for (final m in todos)
        if ((m.notas ?? '').contains('#${a.id}') &&
            m.revierteId == null &&
            !revertidos.contains(m.id))
          m,
    ];
    for (final m in propios) {
      await _catalogo.revertirMovimientoInventario(m.id);
    }
    await _caja.anular(a.movimiento, motivo: motivo);
  }
}
