import 'dart:math';

import '../models/mesa.dart';

// Mesas del local (tabla `mesa`). Se cargan desde el backend.
final List<Mesa> mesas = [];

// Una mesa se crea con 2 sillas como mínimo.
const capacidadMinimaMesa = 2;

// Cantidad de clientes que caben en la mesa (define sus sillas). Las mesas
// sin capacidad definida usan 2 o 4, de forma estable según su número.
int capacidadDe(int numero) {
  for (final m in mesas) {
    if (m.numero == numero && m.capacidad > 0) return m.capacidad;
  }
  return Random(numero).nextBool() ? 4 : 2;
}

int siguienteNumeroMesa() => mesas.isEmpty
    ? 1
    : mesas.map((m) => m.numero).reduce((a, b) => a > b ? a : b) + 1;

bool existeMesa(int numero) => mesas.any((m) => m.numero == numero);

// Zonas del local (no existen en la BD todavía: se agrupan solo en memoria).
final List<String> zonasMesas = ['Principal'];

bool existeZona(String nombre) =>
    zonasMesas.any((z) => z.toLowerCase() == nombre.trim().toLowerCase());

void agregarZona(String nombre) => zonasMesas.add(nombre.trim());

// Cambia el nombre de una zona y de las mesas que pertenecen a ella.
void renombrarZona(String actual, String nuevo) {
  final i = zonasMesas.indexOf(actual);
  if (i == -1) return;
  zonasMesas[i] = nuevo.trim();
  for (var j = 0; j < mesas.length; j++) {
    if (mesas[j].zona == actual) {
      mesas[j] = mesas[j].copyWith(zona: nuevo.trim());
    }
  }
}

List<Mesa> mesasDeZona(String zona) =>
    mesas.where((m) => m.zona == zona).toList();

// Una zona se puede eliminar si no tiene mesas ocupadas ni unidas.
bool puedeEliminarZona(String zona) =>
    zonasMesas.length > 1 &&
    mesasDeZona(zona).every((m) => m.estaLibre && !estaUnida(m.numero));

// Elimina la zona y sus mesas.
void eliminarZona(String zona) {
  mesas.removeWhere((m) => m.zona == zona);
  zonasMesas.remove(zona);
}

void actualizarMesa(
  int numero, {
  required int capacidad,
  required String zona,
}) {
  final i = mesas.indexWhere((m) => m.numero == numero);
  if (i != -1) {
    mesas[i] = mesas[i].copyWith(
      capacidad: capacidad < capacidadMinimaMesa
          ? capacidadMinimaMesa
          : capacidad,
      zona: zona,
    );
  }
}

bool puedeEliminarMesa(int numero) {
  final i = mesas.indexWhere((m) => m.numero == numero);
  return i != -1 && mesas[i].estaLibre && !estaUnida(numero);
}

void eliminarMesa(int numero) => mesas.removeWhere((m) => m.numero == numero);

Mesa agregarMesa({
  required int numero,
  required int capacidad,
  String zona = 'Principal',
}) {
  final mesa = Mesa(
    id: 'm$numero',
    numero: numero,
    estado: 'disponible',
    capacidad: capacidad < capacidadMinimaMesa
        ? capacidadMinimaMesa
        : capacidad,
    zona: zona,
  );
  mesas
    ..add(mesa)
    ..sort((a, b) => a.numero.compareTo(b.numero));
  return mesa;
}

void actualizarEstadoMesa(int numero, String estado) {
  final index = mesas.indexWhere((m) => m.numero == numero);
  if (index != -1) mesas[index] = mesas[index].copyWith(estado: estado);
}

// Uniones de mesas (refleja que `mesa_pedido` admite varias mesas por
// pedido): cada grupo son 2 o más mesas libres que comparten cuenta. La
// primera de cada grupo es la "ancla" (la que se dibuja). Solo se unen mesas
// libres; al cobrar el pedido compartido el grupo se separa automáticamente.
final List<List<int>> gruposUnidos = [];

List<int>? _grupoDe(int numero) {
  for (final g in gruposUnidos) {
    if (g.contains(numero)) return g;
  }
  return null;
}

bool estaUnida(int numero) => _grupoDe(numero) != null;

// Todas las mesas del grupo (incluida `numero`), o solo `numero` si no está
// unida.
List<int> grupoDe(int numero) => _grupoDe(numero) ?? [numero];

// Las demás mesas unidas a `numero` (vacío si no está unida).
List<int> otrasUnidas(int numero) =>
    grupoDe(numero).where((n) => n != numero).toList();

// ¿Es la mesa ancla de su grupo (o una mesa suelta)? Solo esa se dibuja.
bool esAnclaDeGrupo(int numero) {
  final g = _grupoDe(numero);
  return g == null || g.first == numero;
}

void unirMesas(List<int> numeros) {
  if (numeros.length < 2) return;
  final ordenadas = List<int>.of(numeros)..sort();
  gruposUnidos.add(ordenadas);
}

void separarMesas(int numero) {
  gruposUnidos.removeWhere((g) => g.contains(numero));
}
