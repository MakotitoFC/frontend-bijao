import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mesa.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'mesas_store.dart';
import 'pedidos_store.dart';

// Mesas que el mozo debe liberar: su pedido ya se cobró (estado `pagado`) pero la
// mesa sigue ocupada, porque el pago no la libera (los clientes suelen quedarse
// un rato más). La lista la da el backend, ya filtrada: a un mozo solo le
// devuelve las mesas que atendió él; al administrador, todas las de la sede.
// No se deduce en la app ni se guarda en el dispositivo.
final ValueNotifier<List<Mesa>> mesasPorLiberarNotifier =
    ValueNotifier<List<Mesa>>([]);

List<Mesa> mesasPorLiberar() => mesasPorLiberarNotifier.value;

bool get hayMesasPorLiberarPendientes =>
    mesasPorLiberarNotifier.value.isNotEmpty;

// Usuario al que pertenece la lista que hay en memoria.
String? _duenoDeLaLista;

bool _limpiadoLoViejo = false;

// Versiones anteriores guardaban esta lista en el dispositivo, sin distinguir
// al usuario. Ese dato ya no se usa: se borra una vez.
Future<void> _borrarLoGuardadoAntes() async {
  if (_limpiadoLoViejo) return;
  _limpiadoLoViejo = true;
  try {
    final p = await SharedPreferences.getInstance();
    await p.remove('mesas_por_liberar');
  } catch (_) {}
}

// Pide al backend las mesas por liberar del usuario actual.
//
// Además de lo que filtra el backend, la app se protege de mostrar mesas de
// otro: descarta la lista si cambió el usuario mientras se pedía, ignora las
// filas de otro mozo y no ofrece una mesa que tiene un pedido abierto que la
// app conoce.
Future<void> recargarMesasPorLiberar() async {
  await _borrarLoGuardadoAntes();
  final usuario = AuthService.instance.currentUser;
  if (usuario == null) {
    limpiarMesasPorLiberar();
    return;
  }
  // Lo que había era de otro usuario: no se conserva ni siquiera si falla la
  // lectura.
  if (_duenoDeLaLista != usuario.id) {
    mesasPorLiberarNotifier.value = [];
    _duenoDeLaLista = usuario.id;
  }
  try {
    final res = await ApiClient.instance.get('/api/v1/mozo/mesas/por-liberar');
    if (res is! List) return;
    // Cerró sesión o entró otro usuario mientras llegaba la respuesta.
    if (AuthService.instance.currentUser?.id != usuario.id) return;
    final lista = <Mesa>[];
    for (final item in res) {
      if (item is! Map<String, dynamic>) continue;
      final mesaId = item['mesa_id']?.toString() ?? '';
      if (mesaId.isEmpty) continue;
      // El mozo solo ve las mesas de sus pedidos.
      final mozoId = item['mozo_id']?.toString();
      if (!usuario.esAdmin && mozoId != null && mozoId != usuario.id) continue;
      final numero = (item['mesa_numero'] as num?)?.toInt() ?? 0;
      // Una mesa con un pedido abierto (que la app conoce) no está lista para
      // liberarse.
      if (numero > 0 &&
          pedidos.any((p) => p.abierto && p.todasLasMesas.contains(numero))) {
        continue;
      }
      final local = mesas.where((m) => m.id == mesaId).firstOrNull;
      lista.add(
        local ??
            Mesa(
              id: mesaId,
              numero: numero,
              estado: 'ocupada',
              zonaId: item['zona_id']?.toString() ?? '',
              zona: item['zona_nombre']?.toString() ?? 'Salón Principal',
            ),
      );
    }
    lista.sort((a, b) => a.numero.compareTo(b.numero));
    mesasPorLiberarNotifier.value = lista;
  } catch (_) {
    // Sin conexión o sin permiso: se conserva lo último que se leyó para este
    // mismo usuario.
  }
}

// Al liberar una mesa deja de estar en la lista sin esperar otra lectura.
void quitarMesaPorLiberar(String mesaId) {
  final lista = mesasPorLiberarNotifier.value;
  if (!lista.any((m) => m.id == mesaId)) return;
  mesasPorLiberarNotifier.value = [
    for (final m in lista)
      if (m.id != mesaId) m,
  ];
}

// Al cerrar sesión: lo que se leyó era de otro usuario.
void limpiarMesasPorLiberar() {
  _duenoDeLaLista = null;
  mesasPorLiberarNotifier.value = [];
}

// Solo para pruebas: deja una lista como si la hubiera leído [usuarioId].
@visibleForTesting
void fijarMesasPorLiberar(String usuarioId, List<Mesa> lista) {
  _duenoDeLaLista = usuarioId;
  mesasPorLiberarNotifier.value = lista;
}
