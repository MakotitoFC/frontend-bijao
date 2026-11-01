import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/uuid_helper.dart';

// Descuento a medida que el negocio guardó para reutilizarlo en los pedidos.
class DescuentoGuardado {
  final String id;
  final String nombre;
  final bool esPorcentaje;
  final double monto;

  const DescuentoGuardado({
    required this.id,
    required this.nombre,
    required this.esPorcentaje,
    required this.monto,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'esPorcentaje': esPorcentaje,
    'monto': monto,
  };

  factory DescuentoGuardado.fromJson(Map<String, dynamic> j) =>
      DescuentoGuardado(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        esPorcentaje: j['esPorcentaje'] as bool? ?? true,
        monto: (j['monto'] as num).toDouble(),
      );
}

// Descuentos guardados. Por ahora viven en este dispositivo; cuando el backend
// tenga su catálogo de descuentos se cambia solo el almacenamiento.
final descuentosGuardadosNotifier = ValueNotifier<List<DescuentoGuardado>>(
  const [],
);

const _clave = 'descuentos_guardados';

Future<void> cargarDescuentosGuardados() async {
  try {
    final p = await SharedPreferences.getInstance();
    final texto = p.getString(_clave);
    if (texto == null) return;
    descuentosGuardadosNotifier.value = [
      for (final j in jsonDecode(texto) as List)
        DescuentoGuardado.fromJson(Map<String, dynamic>.from(j as Map)),
    ];
  } catch (_) {
    // Sin almacenamiento o datos dañados: queda la lista vacía.
  }
}

Future<void> _persistir() async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _clave,
      jsonEncode([
        for (final d in descuentosGuardadosNotifier.value) d.toJson(),
      ]),
    );
  } catch (_) {}
}

// Crea un descuento nuevo, o actualiza el que tiene el [id] dado.
Future<void> guardarDescuento({
  String? id,
  required String nombre,
  required bool esPorcentaje,
  required double monto,
}) async {
  final nuevo = DescuentoGuardado(
    id: id ?? UuidHelper.v7(),
    nombre: nombre,
    esPorcentaje: esPorcentaje,
    monto: monto,
  );
  final lista = [...descuentosGuardadosNotifier.value];
  final i = lista.indexWhere((d) => d.id == nuevo.id);
  if (i >= 0) {
    lista[i] = nuevo;
  } else {
    lista.add(nuevo);
  }
  descuentosGuardadosNotifier.value = lista;
  await _persistir();
}

Future<void> eliminarDescuentoGuardado(String id) async {
  descuentosGuardadosNotifier.value = [
    for (final d in descuentosGuardadosNotifier.value)
      if (d.id != id) d,
  ];
  await _persistir();
}
