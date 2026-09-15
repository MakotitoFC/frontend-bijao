import '../models/carta_presentacion.dart';
import 'mock_unidades_bebida.dart';

const mockPresentaciones = [
  CartaPresentacion(
    id: 'pres1',
    cartaId: 'carta5',
    unidad: unidadVaso,
    volumenMl: 300,
    precioCliente: 6.0,
  ),
  CartaPresentacion(
    id: 'pres2',
    cartaId: 'carta5',
    unidad: unidadBotella,
    volumenMl: 1000,
    precioCliente: 15.0,
  ),
  CartaPresentacion(
    id: 'pres3',
    cartaId: 'carta6',
    unidad: unidadVaso,
    volumenMl: 300,
    precioCliente: 6.0,
  ),
  CartaPresentacion(
    id: 'pres4',
    cartaId: 'carta6',
    unidad: unidadJarra,
    volumenMl: 1000,
    precioCliente: 16.0,
  ),
];
