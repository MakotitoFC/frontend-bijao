import '../data/configuracion_store.dart';
import '../services/auth_service.dart';
import 'ticket_texto.dart';

// Dirección, teléfono y RUC de la sede del usuario, para la boleta. Si la sede
// no tiene teléfono propio, se usa el del negocio.
DatosSede datosDeLaSede() {
  final sedeId = AuthService.instance.currentUser?.sedeId;
  final sede = sedes.where((s) => s.id == sedeId).firstOrNull ?? sedes.first;
  final celular = (sede.celular ?? '').trim();
  return (
    direccion: sede.direccion.isNotEmpty ? sede.direccion : negocio.direccion,
    telefono: celular.isNotEmpty ? celular : negocio.telefono,
    ruc: sede.ruc,
  );
}
