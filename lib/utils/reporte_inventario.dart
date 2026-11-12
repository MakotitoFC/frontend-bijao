import '../models/inventario_movimiento.dart';
import '../models/producto_inventario.dart';

// Reporte de inventario de un día: qué entró, qué salió y cómo quedó el stock de
// cada producto. Se arma con el libro de inventario (los movimientos) y el stock
// actual: el stock al final de un día es el actual menos lo que se movió
// después, y el del inicio es el final menos lo del propio día.

// Cuánto suma (+) o resta (−) un movimiento al stock.
double efectoEnStock(InventarioMovimiento m) =>
    m.tipoMovimiento.esEntrada ? m.cantidad : -m.cantidad;

DateTime soloDia(DateTime d) => DateTime(d.year, d.month, d.day);

// Una fila del reporte: un producto con movimientos ese día.
class FilaReporteProducto {
  final String productoId;
  final String nombre;
  final String unidadId;
  final double inicio;
  final double entradas;
  final double salidas;
  final double fin;

  const FilaReporteProducto({
    required this.productoId,
    required this.nombre,
    required this.unidadId,
    required this.inicio,
    required this.entradas,
    required this.salidas,
    required this.fin,
  });

  double get neto => entradas - salidas;
}

class ReporteInventarioDia {
  final DateTime dia;
  // Movimientos del día, del más antiguo al más nuevo.
  final List<InventarioMovimiento> movimientos;
  final List<FilaReporteProducto> productos;
  final int cantidadEntradas;
  final int cantidadSalidas;
  // Lo gastado en lo que entró ese día (compras).
  final double costoEntradas;
  // Cuántos movimientos hubo de cada tipo ("Compra", "Consumo"…).
  final Map<String, int> porTipo;

  const ReporteInventarioDia({
    required this.dia,
    required this.movimientos,
    required this.productos,
    required this.cantidadEntradas,
    required this.cantidadSalidas,
    required this.costoEntradas,
    required this.porTipo,
  });

  bool get vacio => movimientos.isEmpty;
}

ReporteInventarioDia calcularReporteInventario({
  required DateTime dia,
  required List<InventarioMovimiento> movimientos,
  required List<ProductoInventario> productos,
}) {
  final inicioDia = soloDia(dia);
  final finDia = inicioDia.add(const Duration(days: 1));

  bool delDia(InventarioMovimiento m) =>
      !m.fecha.isBefore(inicioDia) && m.fecha.isBefore(finDia);

  final delDiaLista = movimientos.where(delDia).toList()
    ..sort((a, b) => a.fecha.compareTo(b.fecha));

  // Lo que se movió después del día, por producto (para llegar al stock final).
  final despues = <String, double>{};
  for (final m in movimientos) {
    if (!m.fecha.isBefore(finDia)) {
      despues[m.productoInventarioId] =
          (despues[m.productoInventarioId] ?? 0) + efectoEnStock(m);
    }
  }

  final porProducto = <String, List<InventarioMovimiento>>{};
  for (final m in delDiaLista) {
    porProducto.putIfAbsent(m.productoInventarioId, () => []).add(m);
  }

  final filas = <FilaReporteProducto>[];
  for (final e in porProducto.entries) {
    final producto = productos.where((p) => p.id == e.key).firstOrNull;
    var entradas = 0.0;
    var salidas = 0.0;
    for (final m in e.value) {
      if (m.tipoMovimiento.esEntrada) {
        entradas += m.cantidad;
      } else {
        salidas += m.cantidad;
      }
    }
    final fin = (producto?.stockActual ?? 0) - (despues[e.key] ?? 0);
    filas.add(
      FilaReporteProducto(
        productoId: e.key,
        nombre: producto?.nombre ?? e.value.first.productoNombre ?? 'Producto',
        unidadId: producto?.unidadProductoId ?? '',
        inicio: fin - (entradas - salidas),
        entradas: entradas,
        salidas: salidas,
        fin: fin,
      ),
    );
  }
  filas.sort((a, b) => a.nombre.compareTo(b.nombre));

  final porTipo = <String, int>{};
  var cantEntradas = 0;
  var cantSalidas = 0;
  var costo = 0.0;
  for (final m in delDiaLista) {
    porTipo.update(
      m.tipoMovimiento.tipoMovimiento,
      (n) => n + 1,
      ifAbsent: () => 1,
    );
    if (m.tipoMovimiento.esEntrada) {
      cantEntradas++;
      costo += m.costoTotal;
    } else {
      cantSalidas++;
    }
  }

  return ReporteInventarioDia(
    dia: inicioDia,
    movimientos: delDiaLista,
    productos: filas,
    cantidadEntradas: cantEntradas,
    cantidadSalidas: cantSalidas,
    costoEntradas: costo,
    porTipo: porTipo,
  );
}

String _dos(int n) => n.toString().padLeft(2, '0');

String fechaIso(DateTime d) => '${d.year}-${_dos(d.month)}-${_dos(d.day)}';

String horaCorta(DateTime d) => '${_dos(d.hour)}:${_dos(d.minute)}';
