import '../data/configuracion_store.dart';
import '../services/auth_service.dart';
import '../services/facturacion_service.dart';
import 'ticket_texto.dart';

// Datos fiscales y de ubicación de la sede del usuario para tickets y comprobantes.
DatosSede datosDeLaSede() {
  final cfg = FacturacionService.instance.cachedConfig;
  if (cfg != null) {
    return (
      nombre: cfg.razonSocial.isNotEmpty ? cfg.razonSocial : 'RESTAURANTE BIJAO',
      direccion: cfg.direccion.isNotEmpty ? cfg.direccion : 'CAL. Los Brillantes 421B',
      telefono: cfg.celular.isNotEmpty ? cfg.celular : '999999999',
      ruc: cfg.ruc.isNotEmpty ? cfg.ruc : '20608543211',
    );
  }
  final sedeId = AuthService.instance.currentUser?.sedeId;
  final sede = sedes.where((s) => s.id == sedeId).firstOrNull ?? sedes.first;
  final celular = (sede.celular ?? '').trim();
  return (
    nombre: negocio.nombre.isNotEmpty && negocio.nombre != 'El Bijao Restaurant' ? negocio.nombre : 'RESTAURANTE BIJAO',
    direccion: sede.direccion.isNotEmpty && sede.direccion != 'Av. Principal 123, San Isidro' ? sede.direccion : 'CAL. Los Brillantes 421B',
    telefono: celular.isNotEmpty && celular != '987654321' ? celular : '999999999',
    ruc: sede.ruc.isNotEmpty && sede.ruc != '20123456789' ? sede.ruc : '20608543211',
  );
}
