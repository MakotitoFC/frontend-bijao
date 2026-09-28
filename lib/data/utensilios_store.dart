import '../models/inventario_movimiento.dart';
import '../models/utensilio_roto.dart';
import 'inventario_store.dart';
import 'catalogos_store.dart';

// Estado en memoria de utensilios/menaje roto. Registrar una rotura también
// descuenta el stock del producto como merma (ver inventario_store.dart).
// TODO: reemplazar por `utensilio_roto` real al conectar el backend.
final List<UtensilioRoto> utensiliosRotos = [];

void registrarUtensilioRoto(UtensilioRoto utensilio) {
  utensiliosRotos.insert(0, utensilio);
  registrarMovimientoInventario(
    InventarioMovimiento(
      productoInventarioId: utensilio.productoInventarioId,
      tipoMovimiento: movMerma,
      cantidad: utensilio.cantidad.toDouble(),
      notas:
          'Utensilio roto${utensilio.notas != null ? ': ${utensilio.notas}' : ''}',
      fecha: utensilio.fecha,
    ),
  );
}

void actualizarUtensilioRoto(UtensilioRoto utensilio) {
  final index = utensiliosRotos.indexWhere((u) => u.id == utensilio.id);
  if (index != -1) utensiliosRotos[index] = utensilio;
}
