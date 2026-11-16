import 'package:flutter/material.dart';

// Periodo que se está mirando en Inventario (Resumen, Movimientos, Anulaciones y
// Reportes comparten el mismo). Empieza en hoy; al cambiar de pestaña se conserva.
final ValueNotifier<DateTimeRange> periodoInventarioNotifier = ValueNotifier(
  _hoy(),
);

DateTimeRange _hoy() {
  final d = DateUtils.dateOnly(DateTime.now());
  return DateTimeRange(start: d, end: d);
}

// ¿La fecha cae dentro del periodo (ambos días incluidos)?
bool enPeriodo(DateTimeRange p, DateTime f) {
  final d = DateUtils.dateOnly(f);
  return !d.isBefore(DateUtils.dateOnly(p.start)) &&
      !d.isAfter(DateUtils.dateOnly(p.end));
}

String _dos(int n) => n.toString().padLeft(2, '0');

String fechaApi(DateTime d) => '${d.year}-${_dos(d.month)}-${_dos(d.day)}';
