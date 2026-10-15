import 'app_role.dart';

/// Modelo de usuario y sesión activa con permisos de seguridad RBAC.
class Usuario {
  final String id;
  final String nombre;
  final String email;
  final String password;
  final AppRole rol;
  final String? sedeId;
  final bool activo;
  final Set<String> permisos;
  // El backend pide cambiar el PIN (sigue siendo el predeterminado).
  final bool debeCambiarPin;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    this.password = '',
    required this.rol,
    this.sedeId,
    this.activo = true,
    this.permisos = const {},
    this.debeCambiarPin = false,
  });

  Usuario copyWith({bool? debeCambiarPin}) => Usuario(
    id: id,
    nombre: nombre,
    email: email,
    password: password,
    rol: rol,
    sedeId: sedeId,
    activo: activo,
    permisos: permisos,
    debeCambiarPin: debeCambiarPin ?? this.debeCambiarPin,
  );

  bool get esAdmin => rol == AppRole.administrador;
  bool get esMozo => rol == AppRole.mesero;
  bool get esCajero => rol == AppRole.cajero;
  bool get esCocina => rol == AppRole.trabajador;

  /// Verifica si el usuario cuenta con un permiso específico.
  /// Si el usuario tiene rol ADMINISTRADOR, tiene bypass automático (acceso total).
  bool tienePermiso(String? permiso) {
    if (permiso == null || permiso.isEmpty) return true;
    if (esAdmin) return true;
    return permisos.contains(permiso.trim().toUpperCase());
  }

  /// Verifica si el usuario cuenta con al menos uno de los permisos dados.
  bool tieneAlgunPermiso(Iterable<String> lista) {
    if (esAdmin) return true;
    for (final p in lista) {
      if (tienePermiso(p)) return true;
    }
    return false;
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    final rawPermisos = json['permisos'];
    final setPermisos = <String>{};
    if (rawPermisos is List) {
      for (final p in rawPermisos) {
        if (p != null) setPermisos.add(p.toString().trim().toUpperCase());
      }
    }

    final rolStr = json['rol']?.toString() ?? '';
    final nombreStr =
        json['usuario']?.toString() ?? json['nombre']?.toString() ?? '';

    return Usuario(
      id: json['usuario_id']?.toString() ?? json['id']?.toString() ?? '',
      nombre: nombreStr,
      email: json['email']?.toString() ?? '$nombreStr@bijao.local',
      password: '',
      rol: AppRoleLabel.fromString(rolStr),
      sedeId: json['sede_id']?.toString(),
      activo: json['estado'] != false,
      permisos: setPermisos,
      debeCambiarPin: json['debe_cambiar_pin'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'usuario': nombre,
    'email': email,
    'rol': rol.valorBd,
    'sede_id': sedeId,
    'estado': activo,
    'permisos': permisos.toList(),
    'debe_cambiar_pin': debeCambiarPin,
  };
}
