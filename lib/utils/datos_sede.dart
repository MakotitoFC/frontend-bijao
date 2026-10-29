import '../models/sede.dart';
import '../data/configuracion_store.dart';
import '../services/auth_service.dart';
import 'ticket_texto.dart';

Sede _sedeDelUsuario() {
  final sedeId = AuthService.instance.currentUser?.sedeId;
  return sedes.where((s) => s.id == sedeId).firstOrNull ?? sedes.first;
}

// Dirección, teléfono y RUC de la sede del usuario, para la boleta (todo sale
// de la tabla `sede`).
DatosSede datosDeLaSede() {
  final sede = _sedeDelUsuario();
  return (
    direccion: sede.direccion,
    telefono: (sede.celular ?? '').trim(),
    ruc: sede.ruc,
  );
}

// Nombre del negocio: la razón social de la sede.
String nombreDelNegocio() => _sedeDelUsuario().razonSocial.trim();
