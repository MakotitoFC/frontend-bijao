import 'dart:math';

import '../models/inventario_movimiento.dart';
import '../models/movimiento_caja.dart';
import '../models/utensilio_roto.dart';
import 'catalog_service.dart';
import 'movimiento_caja_service.dart';

// Las roturas y sus cobros viven en tres sitios (Caja, Inventario y el registro
// de la rotura) y no tienen una columna que los una. Para anularlos de una sola
// vez, a cada rotura se le pone un código corto (ROT-ab12cd) en las notas de
// todo lo que genera. Con ese código se encuentra lo demás.
final RegExp _patronCodigo = RegExp(r'ROT-[0-9a-f]{6}');
final RegExp _patronRef = RegExp(r'\s*·?\s*Ref ROT-[0-9a-f]{6}');

// Código nuevo para una rotura.
String nuevoCodigoRotura() {
  final r = Random.secure();
  final hex = List.generate(6, (_) => r.nextInt(16).toRadixString(16)).join();
  return 'ROT-$hex';
}

// El código que lleva una nota, o null si no tiene.
String? codigoDeRotura(String? texto) =>
    texto == null ? null : _patronCodigo.firstMatch(texto)?.group(0);

// La nota con el código escrito al final.
String notaConCodigo(String base, String codigo) =>
    base.trim().isEmpty ? 'Ref $codigo' : '$base · Ref $codigo';

// La nota sin el código, para mostrarla.
String notaSinCodigo(String? texto) =>
    (texto ?? '').replaceAll(_patronRef, '').trim();

// Los abonos de un mozo se anotan en Caja con "Abono" al final.
bool esAbonoDeRotura(String? nota) => (nota ?? '').contains('· Abono');

// Lo que se hará al anular algo ligado a una rotura (para avisarlo antes).
class EfectoAnulacion {
  // Líneas de stock que vuelven al almacén, ya redactadas ("1 x Vaso").
  final List<String> stock;
  // Ingresos de Caja que se anulan además del que se está anulando.
  final int ingresosCaja;
  final double montoCaja;

  const EfectoAnulacion({
    this.stock = const [],
    this.ingresosCaja = 0,
    this.montoCaja = 0,
  });

  bool get vacio => stock.isEmpty && ingresosCaja == 0;
}

// Resultado de anular: lo que se logró y lo que quedó pendiente.
class ResultadoAnulacion {
  final List<String> avisos;
  const ResultadoAnulacion([this.avisos = const []]);
  bool get completo => avisos.isEmpty;
}

class RoturaService {
  RoturaService._();
  static final RoturaService instance = RoturaService._();

  final CatalogService _catalogo = CatalogService.instance;
  final MovimientoCajaService _caja = MovimientoCajaService.instance;

  static const prefijoAnulada = 'ANULADA: ';

  // Movimientos de stock con el código que aún no se revirtieron.
  Future<List<InventarioMovimiento>> _stockVivo(String codigo) async {
    final todos = await _catalogo.cargarMovimientosInventario();
    final revertidos = {
      for (final m in todos)
        if (m.revierteId != null) m.revierteId,
    };
    return [
      for (final m in todos)
        if ((m.notas ?? '').contains(codigo) &&
            m.revierteId == null &&
            !revertidos.contains(m.id))
          m,
    ];
  }

  String _lineaStock(InventarioMovimiento m) {
    final c = m.cantidad == m.cantidad.roundToDouble()
        ? m.cantidad.toStringAsFixed(0)
        : m.cantidad.toString();
    return '$c x ${m.productoNombre ?? 'producto'}';
  }

  // Qué pasa si se anula el ingreso de Caja [m] (para el aviso del diálogo).
  Future<EfectoAnulacion> efectoDeMovimiento(MovimientoCaja m) async {
    final codigo = codigoDeRotura(m.nota);
    if (codigo == null || esAbonoDeRotura(m.nota)) {
      return const EfectoAnulacion();
    }
    try {
      final stock = await _stockVivo(codigo);
      return EfectoAnulacion(stock: [for (final s in stock) _lineaStock(s)]);
    } catch (_) {
      return const EfectoAnulacion();
    }
  }

  // Anula un ingreso de Caja ligado a una rotura: primero el ingreso (lo que
  // puede rechazar el servidor, por ejemplo con la caja ya cerrada) y luego
  // devuelve el stock. Un movimiento sin código se anula como siempre.
  Future<ResultadoAnulacion> anularMovimiento(
    MovimientoCaja m, {
    required String motivo,
  }) async {
    final codigo = codigoDeRotura(m.nota);
    await _caja.anular(m, motivo: motivo);
    if (codigo == null || esAbonoDeRotura(m.nota)) {
      return const ResultadoAnulacion();
    }
    final avisos = <String>[];
    try {
      for (final s in await _stockVivo(codigo)) {
        try {
          await _catalogo.revertirMovimientoInventario(s.id);
        } catch (_) {
          avisos.add('No se pudo devolver ${_lineaStock(s)} al almacén.');
        }
      }
    } catch (_) {
      avisos.add('No se pudo revisar el stock de la rotura.');
    }
    return ResultadoAnulacion(avisos);
  }

  // Movimientos de Caja vivos (no anulados) con el código, desde el día de la
  // rotura hasta hoy.
  Future<List<MovimientoCaja>> _cajaViva(String codigo, DateTime desde) async {
    final lista = await _caja.listarRango(desde, DateTime.now());
    return [
      for (final m in lista)
        if (!m.anulado && (m.nota ?? '').contains(codigo)) m,
    ];
  }

  // Qué pasa si se anula la rotura [u] (para el aviso del diálogo).
  Future<EfectoAnulacion> efectoDeRotura(UtensilioRoto u) async {
    final codigo = codigoDeRotura(u.notas);
    if (codigo == null) return const EfectoAnulacion();
    try {
      final stock = await _stockVivo(codigo);
      final cajas = await _cajaViva(codigo, u.fecha);
      return EfectoAnulacion(
        stock: [for (final s in stock) _lineaStock(s)],
        ingresosCaja: cajas.length,
        montoCaja: cajas.fold(0.0, (s, m) => s + m.monto),
      );
    } catch (_) {
      return const EfectoAnulacion();
    }
  }

  // Anula una rotura desde Inventario: devuelve el stock, anula sus ingresos
  // de Caja (abonos incluidos) y deja el registro como anulado con su motivo.
  // Nada se borra. Lo que no se pueda hacer (por ejemplo, un ingreso de una
  // caja ya cerrada) vuelve en los avisos.
  Future<ResultadoAnulacion> anularRotura(
    UtensilioRoto u, {
    required String motivo,
  }) async {
    final texto = motivo.trim();
    if (texto.isEmpty) throw Exception('Escribe el motivo de la anulación');
    final codigo = codigoDeRotura(u.notas);
    final avisos = <String>[];
    if (codigo != null) {
      try {
        for (final m in await _cajaViva(codigo, u.fecha)) {
          try {
            await _caja.anular(m, motivo: 'Rotura anulada: $texto');
          } catch (e) {
            avisos.add(
              'No se pudo anular el ingreso de Caja de S/ '
              '${m.monto.toStringAsFixed(2)}: '
              '${e.toString().replaceFirst('Exception: ', '')}',
            );
          }
        }
      } catch (_) {
        avisos.add('No se pudo revisar los ingresos de Caja de la rotura.');
      }
      try {
        for (final s in await _stockVivo(codigo)) {
          try {
            await _catalogo.revertirMovimientoInventario(s.id);
          } catch (_) {
            avisos.add('No se pudo devolver ${_lineaStock(s)} al almacén.');
          }
        }
      } catch (_) {
        avisos.add('No se pudo revisar el stock de la rotura.');
      }
    }
    await _catalogo.actualizarUtensilioRoto(
      u.copyWith(
        done: true,
        notas: '$prefijoAnulada$texto · ${(u.notas ?? '').trim()}',
      ),
    );
    return ResultadoAnulacion(avisos);
  }
}
