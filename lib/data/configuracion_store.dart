import 'package:flutter/material.dart';

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
  bool propinaHabilitada = true;
  double propinaSugerida = 10;

  // Descuento de empleado (`pedidos.descuento`), en porcentaje.
  bool descuentoEmpleadoHabilitado = false;
  double descuentoEmpleadoPorcentaje = 20;

  // Cobro adicional por delivery (`pedidos.cargo_servicio`), en soles.
  bool cargoDeliveryHabilitado = false;
  double cargoDeliveryMonto = 3;
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

// Efectivo siempre disponible como método de cobro, aunque no se haya
// configurado ninguno todavía (tabla `medio_pago`, valor por defecto).
const medioEfectivo = MedioPago(
  id: 'mp1',
  medioPago: 'Efectivo',
  aplicaComision: false,
);

// Métodos de pago editables (`medio_pago`). Se cargan desde el backend.
final List<MedioPago> mediosPago = [];

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
