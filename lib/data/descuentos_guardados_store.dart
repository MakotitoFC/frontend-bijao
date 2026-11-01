import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
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
        esPorcentaje: (j['esPorcentaje'] ?? j['es_porcentaje']) as bool? ?? true,
        monto: (j['monto'] as num).toDouble(),
      );
}

// Descuentos guardados en catálogo del servidor con respaldo local en dispositivo.
final descuentosGuardadosNotifier = ValueNotifier<List<DescuentoGuardado>>(
  const [],
);

const _clave = 'descuentos_guardados';

Future<void> cargarDescuentosGuardados() async {
  try {
    final res = await ApiClient.instance.get('/api/v1/descuentos');
    if (res is List) {
      descuentosGuardadosNotifier.value = [
        for (final j in res)
          DescuentoGuardado.fromJson(Map<String, dynamic>.from(j as Map)),
      ];
      await _persistir();
      return;
    }
  } catch (_) {
    // Si falla la red, lee del almacenamiento local.
  }

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
  String? nuevoId = id;
  try {
    final res = await ApiClient.instance.post(
      '/api/v1/descuentos',
      body: {
        'nombre': nombre,
        'es_porcentaje': esPorcentaje,
        'monto': monto,
      },
    );
    if (res is Map && res['id'] != null) {
      nuevoId = res['id'] as String;
    }
  } catch (_) {}

  final nuevo = DescuentoGuardado(
    id: nuevoId ?? UuidHelper.v7(),
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
  try {
    if (UuidHelper.isValid(id)) {
      await ApiClient.instance.delete('/api/v1/descuentos/$id');
    }
  } catch (_) {}

  descuentosGuardadosNotifier.value = [
    for (final d in descuentosGuardadosNotifier.value)
      if (d.id != id) d,
  ];
  await _persistir();
}
