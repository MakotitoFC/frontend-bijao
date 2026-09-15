import '../models/medio_pago.dart';

const medioEfectivo = MedioPago(
  id: 'mp1',
  medioPago: 'Efectivo',
  aplicaComision: false,
);
const medioTarjeta = MedioPago(
  id: 'mp2',
  medioPago: 'Tarjeta',
  aplicaComision: true,
  porcentajeComision: 3.5,
);
const medioYapePlin = MedioPago(
  id: 'mp3',
  medioPago: 'Yape/Plin',
  aplicaComision: true,
  porcentajeComision: 1.0,
);

const mockMediosPago = [medioEfectivo, medioTarjeta, medioYapePlin];
