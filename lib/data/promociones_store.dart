import '../models/carta_item.dart';
import '../models/carta_presentacion.dart';
import '../models/promocion.dart';
import '../models/promocion_componente.dart';
import 'cartas_store.dart';
import 'presentaciones_store.dart';
import 'variantes_store.dart';

// Promociones (`promocion`), sus componentes (`promocion_componente`) y las
// opciones de cada componente (`promocion_componente_opcion`). El admin las
// configura; el mozo solo las vende y, si el cliente lo pide, cambia un
// producto por otra opción registrada.
// TODO: reemplazar por la carga y el guardado reales cuando el backend exponga
// estas tablas.
final List<Promocion> promociones = [];
final List<PromocionComponente> promocionComponentes = [];
final List<PromocionOpcion> promocionOpciones = [];

// ---------- consulta ----------

List<PromocionComponente> componentesDe(String promocionId) =>
    promocionComponentes.where((c) => c.promocionId == promocionId).toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));

// Opciones de un componente en el orden en que se registraron; la primera
// activa es la que viene incluida.
List<PromocionOpcion> opcionesDe(
  String componenteId, {
  bool soloActivas = false,
}) => promocionOpciones
    .where((o) => o.componenteId == componenteId && (!soloActivas || o.estado))
    .toList();

PromocionOpcion? opcionIncluida(String componenteId) {
  final activas = opcionesDe(componenteId, soloActivas: true);
  return activas.isEmpty ? null : activas.first;
}

// Una promoción se puede vender si tiene componentes y todos tienen al menos
// una opción activa.
bool promocionLista(Promocion p) {
  final componentes = componentesDe(p.id);
  return componentes.isNotEmpty &&
      componentes.every((c) => opcionIncluida(c.id) != null);
}

// Vigentes y completas: las que ve el mozo.
List<Promocion> promocionesDisponibles() =>
    promociones.where((p) => p.vigente && promocionLista(p)).toList();

// Promoción en la que participa un plato (para mostrarlo en la carta).
Promocion? promocionDeCarta(String cartaId) {
  for (final o in promocionOpciones.where(
    (o) => o.cartaId == cartaId && o.estado,
  )) {
    final componente = promocionComponentes
        .where((c) => c.id == o.componenteId)
        .firstOrNull;
    if (componente == null) continue;
    final promo = promociones
        .where((p) => p.id == componente.promocionId && p.vigente)
        .firstOrNull;
    if (promo != null) return promo;
  }
  return null;
}

// ---------- altas, cambios y bajas ----------

void agregarPromocion(Promocion p) => promociones.insert(0, p);

void actualizarPromocion(Promocion p) {
  final i = promociones.indexWhere((x) => x.id == p.id);
  if (i != -1) promociones[i] = p;
}

void eliminarPromocion(String id) {
  for (final c in componentesDe(id)) {
    eliminarComponente(c.id);
  }
  promociones.removeWhere((p) => p.id == id);
}

void agregarComponente(PromocionComponente c) {
  final existentes = componentesDe(c.promocionId);
  final orden = existentes.isEmpty ? 1 : existentes.last.orden + 1;
  promocionComponentes.add(c.copyWith(orden: orden));
}

void actualizarComponente(PromocionComponente c) {
  final i = promocionComponentes.indexWhere((x) => x.id == c.id);
  if (i != -1) promocionComponentes[i] = c;
}

void eliminarComponente(String id) {
  promocionOpciones.removeWhere((o) => o.componenteId == id);
  promocionComponentes.removeWhere((c) => c.id == id);
}

void agregarOpcion(PromocionOpcion o) => promocionOpciones.add(o);

void actualizarOpcion(PromocionOpcion o) {
  final i = promocionOpciones.indexWhere((x) => x.id == o.id);
  if (i != -1) promocionOpciones[i] = o;
}

void eliminarOpcion(String id) =>
    promocionOpciones.removeWhere((o) => o.id == id);

// El admin decide cuál es el producto incluido: pasa a ser la primera opción
// de su componente.
void hacerIncluida(String opcionId) {
  final i = promocionOpciones.indexWhere((o) => o.id == opcionId);
  if (i == -1) return;
  final opcion = promocionOpciones[i];
  final primera = promocionOpciones.indexWhere(
    (o) => o.componenteId == opcion.componenteId,
  );
  if (primera == -1 || primera == i) return;
  promocionOpciones
    ..removeAt(i)
    ..insert(primera, opcion);
}

// ---------- precios ----------

CartaItem? _cartaDe(String id) =>
    cartasNotifier.value.where((c) => c.id == id).firstOrNull;

CartaPresentacion? _presentacionDe(String? id) =>
    id == null ? null : presentaciones.where((p) => p.id == id).firstOrNull;

// Nombre de una opción: plato y, si es bebida, su presentación.
String nombreDeOpcion(PromocionOpcion o) {
  final nombre = _cartaDe(o.cartaId)?.nombrePlato ?? 'Producto eliminado';
  final pres = _presentacionDe(o.cartaPresentacionId);
  if (pres == null) return nombre;
  return '$nombre · ${pres.unidad.unidadPresentacion} ${pres.volumenMl} ml';
}

// Precio normal (fuera de promoción) del producto de la opción.
double precioNormalDeOpcion(PromocionOpcion o) {
  final pres = _presentacionDe(o.cartaPresentacionId);
  if (pres != null) return pres.precioCliente;
  final item = _cartaDe(o.cartaId);
  return item?.precioCliente ?? precioMinimoDeVariantes(o.cartaId) ?? 0;
}

// Precio de la opción dentro de la promoción: el suyo si lo tiene, o el normal
// con el descuento de la promoción.
double precioPromocionalDeOpcion(Promocion p, PromocionOpcion o) {
  if (o.precio > 0) return o.precio;
  final normal = precioNormalDeOpcion(o);
  final descuento = p.porcentajeDescuento ?? 0;
  return normal * (1 - descuento / 100);
}

// Resultado de elegir [o] en el componente [c]. Si no es el producto incluido
// es un cambio: con "se mantiene" conserva el precio de promoción; si no, el
// producto cambiado se cobra a su precio normal.
ComponenteElegido elegirOpcion(
  Promocion p,
  PromocionComponente c,
  PromocionOpcion o,
) {
  final incluida = opcionIncluida(c.id);
  final esCambio = incluida != null && incluida.id != o.id;
  final unitario = (esCambio && !p.seMantiene)
      ? precioNormalDeOpcion(o)
      : precioPromocionalDeOpcion(p, o);
  final precio = unitario * c.cantidad;
  final base = incluida == null
      ? precio
      : precioPromocionalDeOpcion(p, incluida) * c.cantidad;
  return ComponenteElegido(
    componenteId: c.id,
    opcionId: o.id,
    cartaId: o.cartaId,
    cartaPresentacionId: o.cartaPresentacionId,
    nombre: nombreDeOpcion(o),
    cantidad: c.cantidad,
    esCambio: esCambio,
    precio: precio,
    precioAjuste: esCambio ? precio - base : 0,
  );
}

// Selección de salida: cada componente con su producto incluido.
List<ComponenteElegido> seleccionInicial(Promocion p) => [
  for (final c in componentesDe(p.id))
    if (opcionIncluida(c.id) != null)
      elegirOpcion(p, c, opcionIncluida(c.id)!),
];

double totalDeSeleccion(List<ComponenteElegido> seleccion) =>
    seleccion.fold(0.0, (suma, e) => suma + e.precio);
