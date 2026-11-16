import 'package:flutter/material.dart' show DateUtils;

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
  // Primer día del periodo (si es un solo día, ese día).
  final DateTime dia;
  // Último día del periodo.
  final DateTime hasta;
  // Movimientos del periodo, del más antiguo al más nuevo.
  final List<InventarioMovimiento> movimientos;
  final List<FilaReporteProducto> productos;
  // Entradas y salidas reales: no cuentan las reversas ni lo que ya se revirtió
  // (una salida revertida y su reversa se anulan entre sí).
  final int cantidadEntradas;
  final int cantidadSalidas;
  // Lo gastado en las entradas reales del periodo (compras), sin lo revertido.
  final double costoEntradas;
  // Cuántos movimientos hubo de cada tipo ("Compra", "Consumo"…).
  final Map<String, int> porTipo;

  const ReporteInventarioDia({
    required this.dia,
    DateTime? hasta,
    required this.movimientos,
    required this.productos,
    required this.cantidadEntradas,
    required this.cantidadSalidas,
    required this.costoEntradas,
    required this.porTipo,
  }) : hasta = hasta ?? dia;

  bool get vacio => movimientos.isEmpty;
  bool get esUnDia => DateUtils.isSameDay(dia, hasta);
}

// Reporte de un día ([dia]) o de un periodo ([desde]–[hasta], ambos incluidos).
// [movimientos] debe traer, además de los del periodo, los posteriores hasta hoy:
// con ellos se llega al stock final de cada producto.
ReporteInventarioDia calcularReporteInventario({
  DateTime? dia,
  DateTime? desde,
  DateTime? hasta,
  required Iterable<InventarioMovimiento> movimientos,
  required List<ProductoInventario> productos,
}) {
  final inicioPeriodo = soloDia(desde ?? dia!);
  final ultimoDia = soloDia(hasta ?? desde ?? dia!);
  final finPeriodo = ultimoDia.add(const Duration(days: 1));

  bool delPeriodo(InventarioMovimiento m) =>
      !m.fecha.isBefore(inicioPeriodo) && m.fecha.isBefore(finPeriodo);

  final delPeriodoLista = movimientos.where(delPeriodo).toList()
    ..sort((a, b) => a.fecha.compareTo(b.fecha));

  // Lo que se movió después del periodo, por producto (para llegar al stock final).
  final despues = <String, double>{};
  // Movimientos ya revertidos (por id), para no contarlos como entradas o salidas
  // reales.
  final revertidos = <String>{};
  for (final m in movimientos) {
    if (m.revierteId != null) revertidos.add(m.revierteId!);
    if (!m.fecha.isBefore(finPeriodo)) {
      despues[m.productoInventarioId] =
          (despues[m.productoInventarioId] ?? 0) + efectoEnStock(m);
    }
  }

  final porProducto = <String, List<InventarioMovimiento>>{};
  for (final m in delPeriodoLista) {
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
  for (final m in delPeriodoLista) {
    porTipo.update(
      m.tipoMovimiento.tipoMovimiento,
      (n) => n + 1,
      ifAbsent: () => 1,
    );
    final esReal = m.revierteId == null && !revertidos.contains(m.id);
    if (!esReal) continue;
    if (m.tipoMovimiento.esEntrada) {
      cantEntradas++;
      costo += m.costoTotal;
    } else {
      cantSalidas++;
    }
  }

  return ReporteInventarioDia(
    dia: inicioPeriodo,
    hasta: ultimoDia,
    movimientos: delPeriodoLista,
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
