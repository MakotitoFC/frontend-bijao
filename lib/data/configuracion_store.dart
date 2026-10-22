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

  // Propina al cobrar (`pedidos.propina`) y porcentaje sugerido.
  double propinaSugerida = 10;

  // Precio de cada tamaño de tupper (editable al agregarlo al pedido).
  double tupperGrande = 2.0;
  double tupperMediano = 1.5;

  // Descuento de empleado (`pedidos.descuento`), en porcentaje.
  bool descuentoEmpleadoHabilitado = false;
  double descuentoEmpleadoPorcentaje = 20;

  // Cobro adicional por delivery (`pedidos.cargo_servicio`), en soles.
  bool cargoDeliveryHabilitado = false;
  double cargoDeliveryMonto = 3;

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
      propinaSugerida = n('propinaSugerida', propinaSugerida);
      tupperGrande = n('tupperGrande', tupperGrande);
      tupperMediano = n('tupperMediano', tupperMediano);
      descuentoEmpleadoHabilitado = b(
        'descuentoEmpleadoHabilitado',
        descuentoEmpleadoHabilitado,
      );
      descuentoEmpleadoPorcentaje = n(
        'descuentoEmpleadoPorcentaje',
        descuentoEmpleadoPorcentaje,
      );
      cargoDeliveryHabilitado = b(
        'cargoDeliveryHabilitado',
        cargoDeliveryHabilitado,
      );
      cargoDeliveryMonto = n('cargoDeliveryMonto', cargoDeliveryMonto);
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
      await p.setDouble('${_prefijo}propinaSugerida', propinaSugerida);
      await p.setDouble('${_prefijo}tupperGrande', tupperGrande);
      await p.setDouble('${_prefijo}tupperMediano', tupperMediano);
      await p.setBool(
        '${_prefijo}descuentoEmpleadoHabilitado',
        descuentoEmpleadoHabilitado,
      );
      await p.setDouble(
        '${_prefijo}descuentoEmpleadoPorcentaje',
        descuentoEmpleadoPorcentaje,
      );
      await p.setBool(
        '${_prefijo}cargoDeliveryHabilitado',
        cargoDeliveryHabilitado,
      );
      await p.setDouble('${_prefijo}cargoDeliveryMonto', cargoDeliveryMonto);
    } catch (_) {
      // Si no se puede guardar, el ajuste vale solo mientras la app esté abierta.
    }
  }
}

final Configuracion config = Configuracion();

// Información del negocio (`restaurantes`).
class ConfigNegocio {
  String nombre = 'El Bijao Restaurant';
  String telefono = '987654321';
  String direccion = 'Av. Principal 123, San Isidro';
  String emailContacto = 'contacto@elbijao.com';
  String moneda = 'PEN';
  String idioma = 'es';
  String pais = 'PE';
  String zonaHoraria = 'America/Lima';
}

final ConfigNegocio negocio = ConfigNegocio();

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
// cargan desde el backend; queda 1 de prueba para que el login funcione.
final List<Sede> sedes = [
  const Sede(
    id: '1',
    ruc: '20123456789',
    direccion: 'Av. Principal 123, San Isidro',
    celular: '987654321',
  ),
];
