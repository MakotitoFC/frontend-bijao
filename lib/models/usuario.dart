import 'app_role.dart';

// Refleja la tabla `usuario` (usuario, email, password, estado, rol_id, sede_id)
// mientras no hay backend.
class Usuario {
  final String id;
  final String nombre;
  final String email;
  final String password;
  final AppRole rol;
  final String? sedeId;
  final bool activo;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.password,
    required this.rol,
    this.sedeId,
    this.activo = true,
  });
}
