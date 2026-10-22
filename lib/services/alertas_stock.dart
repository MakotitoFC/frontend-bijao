import '../data/inventario_store.dart';
import '../data/notificaciones_store.dart';
import 'catalog_service.dart';

String _cant(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

// Revisa el stock que ya está cargado (productos de inventario y tápers) y
// avisa en la campana de lo que quedó bajo o agotado. Cada producto avisa una
// vez por nivel; si se repone, vuelve a poder avisar. Solo usa los datos y los
// mínimos del servidor.
void revisarAlertasStock() {
  final notif = NotificacionesStore.instance;
  void revisar({
    required String id,
    required String nombre,
    required double stock,
    required double minimo,
    required bool bajo,
    required bool activo,
  }) {
    final agotado = 'stock:$id:agotado';
    final poco = 'stock:$id:bajo';
    if (!activo || !bajo) {
      notif.olvidarStock(agotado);
      notif.olvidarStock(poco);
      return;
    }
    if (stock <= 0) {
      notif.agregar(
        TipoNotificacion.stock,
        'Sin stock',
        '$nombre se agotó.',
        claveStock: agotado,
      );
    } else {
      notif.olvidarStock(agotado);
      notif.agregar(
        TipoNotificacion.stock,
        'Stock bajo',
        '$nombre: quedan ${_cant(stock)} (mínimo ${_cant(minimo)}).',
        claveStock: poco,
      );
    }
  }

  for (final p in productosInventario) {
    revisar(
      id: p.id,
      nombre: p.nombre,
      stock: p.stockActual,
      minimo: p.stockMinimo,
      bajo: p.stockBajo,
      activo: p.estado,
    );
  }
  for (final t in CatalogService.instance.tapers) {
    revisar(
      id: t.id,
      nombre: t.nombre,
      stock: t.stock,
      minimo: t.stockMinimo,
      bajo: t.stockBajo,
      activo: t.estado,
    );
  }
}
