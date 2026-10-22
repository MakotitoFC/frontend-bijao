import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TipoNotificacion { exito, error, aviso, info, stock }

class Notificacion {
  final String id;
  final TipoNotificacion tipo;
  final String titulo;
  final String mensaje;
  final DateTime fecha;
  final bool leida;

  const Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.fecha,
    this.leida = false,
  });

  Notificacion conLeida(bool v) => Notificacion(
    id: id,
    tipo: tipo,
    titulo: titulo,
    mensaje: mensaje,
    fecha: fecha,
    leida: v,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name,
    'titulo': titulo,
    'mensaje': mensaje,
    'fecha': fecha.toIso8601String(),
    'leida': leida,
  };

  static Notificacion? desdeJson(Map<String, dynamic> j) {
    final fecha = DateTime.tryParse('${j['fecha']}');
    if (fecha == null) return null;
    return Notificacion(
      id: '${j['id']}',
      tipo: TipoNotificacion.values.firstWhere(
        (t) => t.name == j['tipo'],
        orElse: () => TipoNotificacion.info,
      ),
      titulo: '${j['titulo'] ?? ''}',
      mensaje: '${j['mensaje'] ?? ''}',
      fecha: fecha,
      leida: j['leida'] == true,
    );
  }
}

// Notificaciones del día: los avisos (éxito, error, actualización, info) que
// salen como toast y las alertas de stock. Se guardan en el dispositivo y solo
// duran ese día: al día siguiente se descartan.
class NotificacionesStore {
  NotificacionesStore._();
  static final NotificacionesStore instance = NotificacionesStore._();

  static const _clave = 'notificaciones_del_dia';

  final ValueNotifier<List<Notificacion>> lista = ValueNotifier(const []);
  // Alertas de stock ya avisadas hoy (para no repetirlas).
  final Set<String> _clavesStock = {};
  bool _cargado = false;

  int get sinLeer => lista.value.where((n) => !n.leida).length;

  static String _dia(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // Lee lo guardado hoy; lo de otros días se descarta.
  Future<void> cargar() async {
    if (_cargado) return;
    _cargado = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_clave);
      if (crudo == null) return;
      final j = jsonDecode(crudo) as Map<String, dynamic>;
      if (j['dia'] != _dia(DateTime.now())) {
        await prefs.remove(_clave);
        return;
      }
      final guardadas = [
        for (final x in (j['items'] as List? ?? const []))
          if (Notificacion.desdeJson(x as Map<String, dynamic>) case final n?)
            n,
      ];
      final ids = lista.value.map((n) => n.id).toSet();
      lista.value = [
        ...lista.value,
        ...guardadas.where((n) => !ids.contains(n.id)),
      ]..sort((a, b) => b.fecha.compareTo(a.fecha));
      _clavesStock.addAll([
        for (final c in (j['claves'] as List? ?? const [])) '$c',
      ]);
    } catch (_) {}
  }

  // Quita lo de días anteriores (por si la app quedó abierta pasada la
  // medianoche).
  void _depurar() {
    final hoy = _dia(DateTime.now());
    final vigentes = [
      for (final n in lista.value)
        if (_dia(n.fecha) == hoy) n,
    ];
    if (vigentes.length != lista.value.length) {
      lista.value = vigentes;
      _clavesStock.clear();
    }
  }

  void agregar(
    TipoNotificacion tipo,
    String titulo,
    String mensaje, {
    String? claveStock,
  }) {
    _depurar();
    if (claveStock != null) {
      if (_clavesStock.contains(claveStock)) return;
      _clavesStock.add(claveStock);
    }
    final ahora = DateTime.now();
    // El mismo aviso repetido en pocos segundos se cuenta una sola vez.
    final repetida = lista.value.any(
      (n) =>
          n.tipo == tipo &&
          n.titulo == titulo &&
          n.mensaje == mensaje &&
          ahora.difference(n.fecha).inSeconds < 4,
    );
    if (repetida) return;
    lista.value = [
      Notificacion(
        id: '${ahora.microsecondsSinceEpoch}',
        tipo: tipo,
        titulo: titulo,
        mensaje: mensaje,
        fecha: ahora,
      ),
      ...lista.value,
    ];
    _guardar();
  }

  // El producto ya no está bajo: si vuelve a bajar, se avisa de nuevo.
  void olvidarStock(String claveStock) {
    if (_clavesStock.remove(claveStock)) _guardar();
  }

  void marcarLeidas() {
    lista.value = [for (final n in lista.value) n.conLeida(true)];
    _guardar();
  }

  void limpiar() {
    lista.value = const [];
    _guardar();
  }

  Future<void> _guardar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _clave,
        jsonEncode({
          'dia': _dia(DateTime.now()),
          'items': [for (final n in lista.value) n.toJson()],
          'claves': _clavesStock.toList(),
        }),
      );
    } catch (_) {}
  }

  // Solo para pruebas.
  @visibleForTesting
  void reiniciar() {
    lista.value = const [];
    _clavesStock.clear();
    _cargado = false;
  }
}
