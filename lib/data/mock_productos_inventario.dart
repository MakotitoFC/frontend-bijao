import '../models/producto_inventario.dart';

// Semilla inicial (ver inventario_store.dart para el estado mutable en memoria).
// TODO: reemplazar por `producto_inventario` real del servidor local.
const productosInventarioIniciales = [
  ProductoInventario(
    id: 'prod1',
    nombre: 'Pechuga de pollo',
    descripcion: 'Pechuga de pollo fresca',
    tipoProductoId: 1,
    tipoSeguimientoId: 2,
    unidadProductoId: 1,
    stockActual: 18,
    costoReposicion: 14.5,
  ),
  ProductoInventario(
    id: 'prod2',
    nombre: 'Papa amarilla',
    tipoProductoId: 1,
    tipoSeguimientoId: 2,
    unidadProductoId: 1,
    stockActual: 40,
    costoReposicion: 3.2,
  ),
  ProductoInventario(
    id: 'prod3',
    nombre: 'Ají amarillo',
    tipoProductoId: 1,
    tipoSeguimientoId: 2,
    unidadProductoId: 1,
    stockActual: 4,
    costoReposicion: 8.0,
  ),
  ProductoInventario(
    id: 'prod4',
    nombre: 'Chicha morada (insumo)',
    tipoProductoId: 2,
    tipoSeguimientoId: 1,
    unidadProductoId: 2,
    stockActual: 12,
    costoReposicion: 9.0,
  ),
  ProductoInventario(
    id: 'prod5',
    nombre: 'Vasos descartables 300ml',
    tipoProductoId: 3,
    tipoSeguimientoId: 1,
    unidadProductoId: 4,
    stockActual: 6,
    costoReposicion: 12.0,
    notas: 'Stock bajo, revisar con proveedor',
  ),
];
