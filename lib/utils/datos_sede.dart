import '../models/sede.dart';
import '../data/configuracion_store.dart';
import '../services/auth_service.dart';
import '../services/facturacion_service.dart';
import 'ticket_texto.dart';

Sede _sedeDelUsuario() {
  final sedeId = AuthService.instance.currentUser?.sedeId;
  return sedes.where((s) => s.id == sedeId).firstOrNull ?? sedes.first;
}

// Datos fiscales y de ubicación de la sede del usuario para tickets y comprobantes.
DatosSede datosDeLaSede() {
  final cfg = FacturacionService.instance.cachedConfig;
  if (cfg != null) {
    return (
      nombre: cfg.razonSocial.isNotEmpty ? cfg.razonSocial : 'SERVICIOS MULTIPLES EL BIJAO E.I.R.L.',
      direccion: cfg.direccion.isNotEmpty ? cfg.direccion : 'CAL.LOS BRILLANTES NRO. 421 URB. SANTA INES LA LIBERTAD - TRUJILLO - TRUJILLO',
      telefono: cfg.celular.isNotEmpty ? cfg.celular : '-',
      ruc: cfg.ruc.isNotEmpty ? cfg.ruc : '20540005371',
    );
  }
  final sede = _sedeDelUsuario();
  final celular = (sede.celular ?? '').trim();
  return (
    nombre: sede.razonSocial.isNotEmpty ? sede.razonSocial : 'SERVICIOS MULTIPLES EL BIJAO E.I.R.L.',
    direccion: sede.direccion.isNotEmpty ? sede.direccion : 'CAL.LOS BRILLANTES NRO. 421 URB. SANTA INES LA LIBERTAD - TRUJILLO - TRUJILLO',
    telefono: celular.isNotEmpty ? celular : '-',
    ruc: sede.ruc.isNotEmpty ? sede.ruc : '20540005371',
  );
}

// Nombre del negocio: la razón social de la sede.
String nombreDelNegocio() {
  final cfg = FacturacionService.instance.cachedConfig;
  if (cfg != null && cfg.razonSocial.trim().isNotEmpty) {
    return cfg.razonSocial.trim();
  }
  return _sedeDelUsuario().razonSocial.trim();
}
