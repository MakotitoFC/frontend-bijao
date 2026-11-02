import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Promociones destacadas (se ven en amarillo) y datos de la promoción de
// Cumpleaños. El servidor aún no tiene estos datos: se guardan en este
// dispositivo.
const idCumpleanos = 'cumpleanos';

const _clave = 'promociones_destacadas';
const _claveNombre = 'cumpleanos_nombre';
const _claveDescripcion = 'cumpleanos_descripcion';
const _claveEliminada = 'cumpleanos_eliminada';

const nombreCumpleanosPorDefecto = 'Cumpleaños';
const descripcionCumpleanosPorDefecto =
    'Productos con el precio que se elija (por defecto S/ 0.00)';

// Por defecto, Cumpleaños es una promoción destacada.
final ValueNotifier<Set<String>> promocionesDestacadas = ValueNotifier({
  idCumpleanos,
});

bool esPromocionDestacada(String id) =>
    promocionesDestacadas.value.contains(id);

typedef ConfigCumpleanos = ({
  String nombre,
  String descripcion,
  bool eliminada,
});

// La promoción de Cumpleaños: se puede renombrar, describir, quitar el
// amarillo y eliminar (deja de salir en el registro de pedidos).
final ValueNotifier<ConfigCumpleanos> configCumpleanos = ValueNotifier((
  nombre: nombreCumpleanosPorDefecto,
  descripcion: descripcionCumpleanosPorDefecto,
  eliminada: false,
));

Future<void> cargarPromocionesDestacadas() async {
  try {
    final p = await SharedPreferences.getInstance();
    promocionesDestacadas.value = {
      ...(p.getStringList(_clave) ?? const [idCumpleanos]),
    };
    configCumpleanos.value = (
      nombre: p.getString(_claveNombre) ?? nombreCumpleanosPorDefecto,
      descripcion:
          p.getString(_claveDescripcion) ?? descripcionCumpleanosPorDefecto,
      eliminada: p.getBool(_claveEliminada) ?? false,
    );
  } catch (_) {}
}

Future<void> marcarPromocionDestacada(String id, bool destacada) async {
  final nuevo = {...promocionesDestacadas.value};
  destacada ? nuevo.add(id) : nuevo.remove(id);
  promocionesDestacadas.value = nuevo;
  try {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_clave, nuevo.toList());
  } catch (_) {}
}

Future<void> guardarConfigCumpleanos(ConfigCumpleanos c) async {
  configCumpleanos.value = c;
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(_claveNombre, c.nombre);
    await p.setString(_claveDescripcion, c.descripcion);
    await p.setBool(_claveEliminada, c.eliminada);
  } catch (_) {}
}
