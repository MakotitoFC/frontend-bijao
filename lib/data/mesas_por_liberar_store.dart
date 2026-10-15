import 'package:shared_preferences/shared_preferences.dart';

import '../models/mesa.dart';
import 'mesas_store.dart';
import 'pedidos_store.dart';

// Mesas que el mozo debe liberar a mano: su pedido ya se pagó (desaparece de su
// lista) pero la mesa sigue ocupada, porque el pago no la libera (los clientes
// suelen quedarse un rato más). Se recuerdan en el dispositivo.
final Set<String> _ids = {};

const _clavePrefs = 'mesas_por_liberar';

Future<void> cargarMesasPorLiberar() async {
  try {
    final p = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll(p.getStringList(_clavePrefs) ?? const []);
  } catch (_) {
    // Sin almacenamiento: se usa solo lo de esta sesión.
  }
}

Future<void> _guardar() async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_clavePrefs, _ids.toList());
  } catch (_) {}
}

bool get hayMesasPorLiberarPendientes => _ids.isNotEmpty;

// Un pedido de mesa se cobró: su mesa queda por liberar.
void marcarMesaPorLiberar(String mesaId) {
  if (_ids.add(mesaId)) _guardar();
}

void quitarMesaPorLiberar(String mesaId) {
  if (_ids.remove(mesaId)) _guardar();
}

// Mesas ocupadas que no tienen ningún pedido abierto entre los que la app
// conoce y que no están ya en la lista de "por liberar". Solo es fiable para
// quien ve todos los pedidos de la sede (el administrador): un mozo solo ve los
// suyos y esta lista incluiría mesas con pedidos de otros mozos.
List<Mesa> mesasOcupadasSinPedido() {
  final ya = {for (final m in mesasPorLiberar()) m.id};
  final lista = [
    for (final m in mesas)
      if (m.estaOcupada &&
          !ya.contains(m.id) &&
          !pedidos.any((p) => p.abierto && p.todasLasMesas.contains(m.numero)))
        m,
  ]..sort((a, b) => a.numero.compareTo(b.numero));
  return lista;
}

// Mesas marcadas que siguen ocupadas y sin ningún pedido abierto. Las que ya no
// están ocupadas (alguien las liberó) se descartan.
List<Mesa> mesasPorLiberar() {
  final resultado = <Mesa>[];
  final descartar = <String>[];
  for (final id in _ids) {
    final m = mesas.where((x) => x.id == id).firstOrNull;
    if (m == null || !m.estaOcupada) {
      if (m != null) descartar.add(id);
      continue;
    }
    final conPedidoAbierto = pedidos.any(
      (p) => p.abierto && p.todasLasMesas.contains(m.numero),
    );
    if (!conPedidoAbierto) resultado.add(m);
  }
  descartar.forEach(quitarMesaPorLiberar);
  resultado.sort((a, b) => a.numero.compareTo(b.numero));
  return resultado;
}
