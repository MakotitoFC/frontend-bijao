import '../models/medio_pago.dart';
import '../models/movimiento_caja.dart';
import 'configuracion_store.dart';
import 'pagos_store.dart';

// Ingresos y salidas de caja en memoria; lo que vive en el servidor
// (`movimiento`) se trae al abrir Caja.
final List<MovimientoCaja> movimientosCaja = [];

// Categorías que trae el servidor (`categoria_movimiento`).
final List<CategoriaMovimiento> categoriasMovimiento = [];

// Notas escritas en este equipo. El servidor todavía no guarda la nota; así no
// desaparece al volver a leer la lista.
final Map<String, String> notasMovimientoLocales = {};

// Categorías de partida para cuando el servidor no tiene ninguna, de modo que
// el cajero siempre encuentra dónde clasificar el movimiento.
const categoriasMovimientoBase = [
  CategoriaMovimiento(
    id: 'cm-i-otros',
    nombre: 'Otros ingresos',
    tipo: TipoMovimiento.ingreso,
  ),
  CategoriaMovimiento(
    id: 'cm-i-sencillo',
    nombre: 'Cambio / sencillo',
    tipo: TipoMovimiento.ingreso,
  ),
  CategoriaMovimiento(
    id: 'cm-e-insumos',
    nombre: 'Compra de insumos',
    tipo: TipoMovimiento.egreso,
  ),
  CategoriaMovimiento(
    id: 'cm-e-gastos',
    nombre: 'Gasto operativo',
    tipo: TipoMovimiento.egreso,
  ),
  CategoriaMovimiento(
    id: 'cm-e-retiro',
    nombre: 'Retiro de efectivo',
    tipo: TipoMovimiento.egreso,
  ),
];

// Las categorías activas de un tipo; si el servidor no tiene ninguna de ese
// tipo, las de partida.
List<CategoriaMovimiento> categoriasDeTipo(TipoMovimiento tipo) {
  final delServidor = categoriasMovimiento
      .where((c) => c.activo && c.tipo == tipo)
      .toList();
  if (delServidor.isNotEmpty) return delServidor;
  return categoriasMovimientoBase.where((c) => c.tipo == tipo).toList();
}

// Los movimientos de la caja actual, del más reciente al más antiguo.
List<MovimientoCaja> movimientosDesde(DateTime desde) =>
    movimientosCaja.where((m) => !m.fecha.isBefore(desde)).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

// 'efectivo', 'digital' (Yape y Plin) o 'tarjeta' (lo demás), igual que agrupa
// el servidor los totales de la caja.
String grupoDeMedio(String nombre) {
  final n = nombre.trim().toLowerCase();
  // El grupo que eligió el administrador para ese medio; si no está en la
  // lista, el que se supone por el nombre.
  final medio = mediosPago.where((m) => m.medioPago.trim().toLowerCase() == n);
  return medio.isNotEmpty ? medio.first.grupo : grupoPorNombre(nombre);
}

// Una fila del resumen de caja: lo que entró por ventas, los ingresos y las
// salidas de un medio de pago.
class FilaResumenMedio {
  final String medio;
  // Grupo del medio si el servidor lo manda (efectivo, tarjeta o digital).
  final String? grupoServidor;
  double ventas;
  double ingresos;
  double egresos;

  FilaResumenMedio(
    this.medio, {
    this.grupoServidor,
    this.ventas = 0,
    this.ingresos = 0,
    this.egresos = 0,
  });

  double get neto => ventas + ingresos - egresos;

  // Grupo para sumar en las tarjetas de Caja.
  String get grupo => grupoServidor ?? grupoDeMedio(medio);
}

// Resumen de la caja desde [desde]: una fila por medio de pago con actividad
// (efectivo primero). Las ventas son lo cobrado (cuenta más recargo); los
// movimientos anulados no cuentan.
List<FilaResumenMedio> resumenPorMedio(DateTime desde) {
  final filas = <String, FilaResumenMedio>{};
  FilaResumenMedio fila(String nombre) => filas.putIfAbsent(
    nombre.trim().toLowerCase(),
    () => FilaResumenMedio(nombre.trim()),
  );

  for (final p in pagos.where((p) => !p.fechaPago.isBefore(desde))) {
    fila(p.medioPago.medioPago).ventas += p.montoCobrado;
  }
  for (final m in movimientosDesde(desde).where((m) => !m.anulado)) {
    final f = fila(m.medioPagoNombre);
    if (m.tipo == TipoMovimiento.ingreso) {
      f.ingresos += m.monto;
    } else {
      f.egresos += m.monto;
    }
  }
  // Los medios activos aparecen aunque no hayan tenido movimiento, para que la
  // tabla siempre muestre dónde puede entrar dinero.
  for (final m in mediosPagoActivos) {
    fila(m.medioPago);
  }

  final orden = [
    for (final m in mediosPagoActivos) m.medioPago.trim().toLowerCase(),
  ];
  int peso(String clave) {
    if (clave == 'efectivo') return -1;
    final i = orden.indexOf(clave);
    return i < 0 ? orden.length : i;
  }

  final claves = filas.keys.toList()
    ..sort((a, b) {
      final c = peso(a).compareTo(peso(b));
      return c != 0 ? c : a.compareTo(b);
    });
  return [for (final c in claves) filas[c]!];
}

// Lo que debería haber por grupo (efectivo, tarjeta, digital) desde [desde]:
// ventas más ingresos menos salidas. Sirve para el cierre de caja.
({double efectivo, double tarjeta, double digital}) netoPorGrupo(
  DateTime desde,
) {
  var efectivo = 0.0, tarjeta = 0.0, digital = 0.0;
  for (final f in resumenPorMedio(desde)) {
    switch (f.grupo) {
      case 'efectivo':
        efectivo += f.neto;
      case 'digital':
        digital += f.neto;
      default:
        tarjeta += f.neto;
    }
  }
  return (efectivo: efectivo, tarjeta: tarjeta, digital: digital);
}

({double ingresos, double egresos}) totalesMovimientos(DateTime desde) {
  var ingresos = 0.0, egresos = 0.0;
  for (final m in movimientosDesde(desde).where((m) => !m.anulado)) {
    if (m.tipo == TipoMovimiento.ingreso) {
      ingresos += m.monto;
    } else {
      egresos += m.monto;
    }
  }
  return (ingresos: ingresos, egresos: egresos);
}
