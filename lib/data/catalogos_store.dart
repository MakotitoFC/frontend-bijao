// Catálogos de referencia (tablas pequeñas y fijas del esquema): unidades,
// tipos de producto, tipos de seguimiento de stock, tipos de movimiento de
// inventario.

import '../models/tipo_movimiento.dart';
import '../models/tipo_producto.dart';
import '../models/tipo_seguimiento.dart';
import '../models/unidad_producto.dart';

// `unidad_producto`.
const unidadKg = UnidadProducto(id: 1, unidad: 'Kg');
const unidadLitro = UnidadProducto(id: 2, unidad: 'Litro');
const unidadUnidad = UnidadProducto(id: 3, unidad: 'Unidad');
const unidadPaquete = UnidadProducto(id: 4, unidad: 'Paquete');
const unidadesProducto = [unidadKg, unidadLitro, unidadUnidad, unidadPaquete];

// `tipo_producto`.
const tipoInsumo = TipoProducto(id: 1, tipoProducto: 'Insumo');
const tipoBebida = TipoProducto(id: 2, tipoProducto: 'Bebida');
const tipoDesechable = TipoProducto(id: 3, tipoProducto: 'Desechable');
const tipoMenaje = TipoProducto(id: 4, tipoProducto: 'Menaje');
const tiposProducto = [tipoInsumo, tipoBebida, tipoDesechable, tipoMenaje];

// `tipo_seguimiento`.
const seguimientoUnidad = TipoSeguimiento(id: 1, tipoSeguimiento: 'Por unidad');
const seguimientoPeso = TipoSeguimiento(id: 2, tipoSeguimiento: 'Por peso');
const tiposSeguimiento = [seguimientoUnidad, seguimientoPeso];

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
// Los usa el sistema (no se eligen a mano).
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
