class PermisoModel {
  final String id;
  final String permiso;
  final bool estado;

  const PermisoModel({
    required this.id,
    required this.permiso,
    this.estado = true,
  });

  factory PermisoModel.fromJson(Map<String, dynamic> json) => PermisoModel(
    id: json['id'] as String,
    permiso: json['permiso'] as String? ?? '',
    estado: json['estado'] as bool? ?? true,
  );
}

class RolModel {
  final String id;
  final String rol;
  final bool estado;
  final String? sedeId;
  final List<PermisoModel> permisos;

  const RolModel({
    required this.id,
    required this.rol,
    this.estado = true,
    this.sedeId,
    this.permisos = const [],
  });

  bool tienePermiso(String nombrePermiso) =>
      permisos.any((p) => p.permiso == nombrePermiso);

  factory RolModel.fromJson(Map<String, dynamic> json) => RolModel(
    id: json['id'] as String,
    rol: json['rol'] as String? ?? '',
    estado: json['estado'] as bool? ?? true,
    sedeId: json['sede_id'] as String?,
    permisos: (json['permisos'] as List<dynamic>?)
            ?.map((e) => PermisoModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

class UserRBACModel {
  final String id;
  final String usuario;
  final String email;
  final bool estado;
  final String rolId;
  final String rolNombre;
  final List<RolModel> rolesSecundarios;
  final List<PermisoModel> permisosDirectos;
  final List<String> permisosEfectivos;

  const UserRBACModel({
    required this.id,
    required this.usuario,
    required this.email,
    this.estado = true,
    required this.rolId,
    required this.rolNombre,
    this.rolesSecundarios = const [],
    this.permisosDirectos = const [],
    this.permisosEfectivos = const [],
  });

  bool tienePermiso(String p) => permisosEfectivos.contains(p);

  factory UserRBACModel.fromJson(Map<String, dynamic> json) => UserRBACModel(
    id: json['id'] as String,
    usuario: json['usuario'] as String? ?? '',
    email: json['email'] as String? ?? '',
    estado: json['estado'] as bool? ?? true,
    rolId: json['rol_id'] as String? ?? '',
    rolNombre: json['rol_nombre'] as String? ?? '',
    rolesSecundarios: (json['roles_secundarios'] as List<dynamic>?)
            ?.map((e) => RolModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    permisosDirectos: (json['permisos_directos'] as List<dynamic>?)
            ?.map((e) => PermisoModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    permisosEfectivos: (json['permisos_efectivos'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
  );

  UserRBACModel copyWith({
    String? id,
    String? usuario,
    String? email,
    bool? estado,
    String? rolId,
    String? rolNombre,
    List<RolModel>? rolesSecundarios,
    List<PermisoModel>? permisosDirectos,
    List<String>? permisosEfectivos,
  }) => UserRBACModel(
    id: id ?? this.id,
    usuario: usuario ?? this.usuario,
    email: email ?? this.email,
    estado: estado ?? this.estado,
    rolId: rolId ?? this.rolId,
    rolNombre: rolNombre ?? this.rolNombre,
    rolesSecundarios: rolesSecundarios ?? this.rolesSecundarios,
    permisosDirectos: permisosDirectos ?? this.permisosDirectos,
    permisosEfectivos: permisosEfectivos ?? this.permisosEfectivos,
  );
}
