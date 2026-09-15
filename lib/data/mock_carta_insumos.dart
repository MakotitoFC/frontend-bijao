import '../models/carta_insumo.dart';

// Recetas de ejemplo (simula `carta_insumo`), usando los productos ya
// definidos en mock_productos_inventario.dart.
const mockCartaInsumos = [
  // Causa Limeña: papa + pollo, cantidad fija.
  CartaInsumo(
    id: 'ci1',
    cartaId: 'carta1',
    productoInventarioId: 'prod2',
    cantidadEstandar: 0.4,
    esVariable: false,
  ),
  CartaInsumo(
    id: 'ci2',
    cartaId: 'carta1',
    productoInventarioId: 'prod1',
    cantidadEstandar: 0.15,
    esVariable: false,
  ),
  // Lomo Saltado: papas fritas, cantidad fija.
  CartaInsumo(
    id: 'ci3',
    cartaId: 'carta3',
    productoInventarioId: 'prod2',
    cantidadEstandar: 0.3,
    esVariable: false,
  ),
  // Ají de Gallina: pollo + ají amarillo, cantidad fija.
  CartaInsumo(
    id: 'ci4',
    cartaId: 'carta4',
    productoInventarioId: 'prod1',
    cantidadEstandar: 0.3,
    esVariable: false,
  ),
  CartaInsumo(
    id: 'ci5',
    cartaId: 'carta4',
    productoInventarioId: 'prod3',
    cantidadEstandar: 0.05,
    esVariable: false,
  ),
  // Chicha Morada: el insumo líquido varía según la presentación (vaso/botella),
  // el vaso descartable siempre es 1 unidad.
  CartaInsumo(
    id: 'ci6',
    cartaId: 'carta5',
    productoInventarioId: 'prod4',
    esVariable: true,
  ),
  CartaInsumo(
    id: 'ci7',
    cartaId: 'carta5',
    productoInventarioId: 'prod5',
    cantidadEstandar: 1,
    esVariable: false,
  ),
  // Limonada: solo se trazabiliza el vaso descartable.
  CartaInsumo(
    id: 'ci8',
    cartaId: 'carta6',
    productoInventarioId: 'prod5',
    cantidadEstandar: 1,
    esVariable: false,
  ),
];
