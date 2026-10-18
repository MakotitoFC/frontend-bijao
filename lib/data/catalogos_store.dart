// Catálogos de referencia (tablas del esquema): unidades,
// tipos de producto, tipos de seguimiento de stock, tipos de movimiento de inventario.

import '../models/tipo_movimiento.dart';
import '../models/tipo_producto.dart';
import '../models/unidad_producto.dart';

// Listas dinámicas sincronizadas con PostgreSQL y el backend Go
final List<UnidadProducto> unidadesProducto = [];
final List<TipoProducto> tiposProducto = [];

// `tipo_movimiento`: UUID fijos del backend (migración de inventario).
const movEntradaManualId = '55551111-1111-1111-1111-111111111107';
const movSalidaManualId = '55551111-1111-1111-1111-111111111108';
const movMermaId = '55551111-1111-1111-1111-111111111103';
const movIngresoCompraId = '55551111-1111-1111-1111-111111111101';
const movSalidaVentaId = '55551111-1111-1111-1111-111111111102';

const movEntradaManual = TipoMovimiento(
  id: movEntradaManualId,
  codigo: 'entrada_manual',
  tipoMovimiento: 'Entrada manual',
  signo: 1,
);
const movSalidaManual = TipoMovimiento(
  id: movSalidaManualId,
  codigo: 'salida_manual',
  tipoMovimiento: 'Salida manual',
  signo: -1,
);
const movMerma = TipoMovimiento(
  id: movMermaId,
  codigo: 'merma',
  tipoMovimiento: 'Merma',
  signo: -1,
);
const movEntradaCompra = TipoMovimiento(
  id: movIngresoCompraId,
  codigo: 'ingreso_compra',
  tipoMovimiento: 'Ingreso por compra',
  signo: 1,
);
const movSalidaVenta = TipoMovimiento(
  id: movSalidaVentaId,
  codigo: 'salida_venta',
  tipoMovimiento: 'Salida por venta',
  signo: -1,
);

// Los que se pueden registrar a mano al ajustar el stock.
const codigosMovimientoManual = {'entrada_manual', 'salida_manual', 'merma'};

// Catálogo sincronizado con el backend (arranca con los de uso manual).
final List<TipoMovimiento> tiposMovimiento = [
  movEntradaManual,
  movSalidaManual,
  movMerma,
  movEntradaCompra,
  movSalidaVenta,
];
