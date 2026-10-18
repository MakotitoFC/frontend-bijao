import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Copia en este dispositivo del último logo que se subió para los tickets, para
// mostrarlo en la vista previa de la cuenta. El servidor guarda su propio logo
// (el que se imprime) pero no lo entrega de vuelta, por eso esta copia es solo
// de pantalla: si el logo se cambió desde otro equipo, aquí se ve el último que
// se subió desde este.
const _clave = 'logo_tickets_local';

final ValueNotifier<Uint8List?> logoTicketLocal = ValueNotifier<Uint8List?>(
  null,
);

Future<void> cargarLogoTicketLocal() async {
  try {
    final p = await SharedPreferences.getInstance();
    final b64 = p.getString(_clave);
    logoTicketLocal.value = (b64 == null || b64.isEmpty)
        ? null
        : base64Decode(b64);
  } catch (_) {
    logoTicketLocal.value = null;
  }
}

Future<void> guardarLogoTicketLocal(List<int> bytes) async {
  logoTicketLocal.value = Uint8List.fromList(bytes);
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(_clave, base64Encode(bytes));
  } catch (_) {}
}
