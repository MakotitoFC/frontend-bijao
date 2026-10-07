// Catálogos de referencia (tablas del esquema): unidades,
// tipos de producto, tipos de seguimiento de stock, tipos de movimiento de inventario.

import '../models/tipo_movimiento.dart';
import '../models/tipo_producto.dart';
import '../models/unidad_producto.dart';

// Listas dinámicas sincronizadas con PostgreSQL y el backend Go
final List<UnidadProducto> unidadesProducto = [];
final List<TipoProducto> tiposProducto = [];

// `tipo_movimiento`.
const movEntradaManual = TipoMovimiento(
  id: 1,
  tipoMovimiento: 'Entrada manual',
  esEntrada: true,
);
const movSalidaManual = TipoMovimiento(
  id: 2,
  tipoMovimiento: 'Salida manual',
  esEntrada: false,
);
const movMerma = TipoMovimiento(
  id: 3,
  tipoMovimiento: 'Merma',
  esEntrada: false,
);
const movEntradaCompra = TipoMovimiento(
  id: 4,
  tipoMovimiento: 'Entrada por compra',
  esEntrada: true,
);
const movSalidaVenta = TipoMovimiento(
  id: 5,
  tipoMovimiento: 'Salida por venta',
  esEntrada: false,
);
const tiposMovimiento = [movEntradaManual, movSalidaManual, movMerma];
