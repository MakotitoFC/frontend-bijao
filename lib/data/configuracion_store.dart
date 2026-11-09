import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/horario.dart';
import '../models/medio_pago.dart';
import '../models/sede.dart';

// Configuración del negocio en memoria. Cada valor se guarda al instante desde
// Configuración (con switches y campos simples) y lo leen Pedidos y Pagos.
// TODO: reemplazar por `restaurantes`, `horarios` y demás tablas reales.
class Configuracion {
  // Tipos de servicio que se ofrecen al tomar un pedido (`pedidos.tipo_servicio`).
  bool servicioLocal = true;
  bool servicioDelivery = true;

  // Propina al cobrar (`pedidos.propina`): con esto apagado, la pantalla de
  // pagar no ofrece la propina. El porcentaje sugerido es el del botón de
  // propina de los pedidos.
  bool propinaHabilitada = true;
  double propinaSugerida = 10;

  // Precio de cada tamaño de tupper (editable al agregarlo al pedido).
  double tupperGrande = 2.0;
  double tupperMediano = 1.5;

  static const _prefijo = 'config_';

  // Lee lo guardado en este dispositivo (si no hay nada, quedan los valores
  // por defecto). Se llama al iniciar la app.
  Future<void> cargar() async {
    try {
      final p = await SharedPreferences.getInstance();
      bool b(String k, bool d) => p.getBool('$_prefijo$k') ?? d;
      double n(String k, double d) => p.getDouble('$_prefijo$k') ?? d;
      servicioLocal = b('servicioLocal', servicioLocal);
      servicioDelivery = b('servicioDelivery', servicioDelivery);
      propinaHabilitada = b('propinaHabilitada', propinaHabilitada);
      propinaSugerida = n('propinaSugerida', propinaSugerida);
      tupperGrande = n('tupperGrande', tupperGrande);
      tupperMediano = n('tupperMediano', tupperMediano);
    } catch (_) {
      // Sin almacenamiento disponible: se usan los valores por defecto.
    }
  }

  // Guarda los valores en este dispositivo. Se llama al cambiar un ajuste.
  Future<void> guardar() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('${_prefijo}servicioLocal', servicioLocal);
      await p.setBool('${_prefijo}servicioDelivery', servicioDelivery);
      await p.setBool('${_prefijo}propinaHabilitada', propinaHabilitada);
      await p.setDouble('${_prefijo}propinaSugerida', propinaSugerida);
      await p.setDouble('${_prefijo}tupperGrande', tupperGrande);
      await p.setDouble('${_prefijo}tupperMediano', tupperMediano);
    } catch (_) {
      // Si no se puede guardar, el ajuste vale solo mientras la app esté abierta.
    }
  }
}

final Configuracion config = Configuracion();

// Horario de atención (`horarios`), de lunes a domingo.
final List<Horario> horarios = [
  for (final dia in [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ])
    Horario(
      dia: dia,
      inicio: const TimeOfDay(hour: 11, minute: 0),
      fin: const TimeOfDay(hour: 22, minute: 0),
    ),
];

// Métodos de pago editables (`medio_pago`). Se cargan desde el backend.
final List<MedioPago> mediosPago = [];

// Solo los que trae el servidor y están activos; sin conexión puede ser vacía.
List<MedioPago> get mediosPagoActivos =>
    mediosPago.where((m) => m.activo).toList();

// Restaurantes / sedes (`restaurantes.direccion`, `telefono`, `activo`). Se
// cargan desde el backend. Mientras no llegan queda una sede vacía (sin datos de
// ejemplo) para que la app no falle.
final List<Sede> sedes = [const Sede(id: '', ruc: '', direccion: '')];
