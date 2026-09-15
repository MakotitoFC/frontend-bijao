import '../models/tipo_movimiento.dart';

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
// Generados automáticamente por otros módulos (no seleccionables a mano).
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

const mockTiposMovimiento = [movEntradaManual, movSalidaManual, movMerma];
