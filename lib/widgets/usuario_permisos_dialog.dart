import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/app_role.dart';
import '../models/rbac.dart';
import '../models/usuario.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';

class UsuarioPermisosDialog extends StatefulWidget {
  final Usuario usuario;
  final List<RolModel> roles;
  final List<PermisoModel> permisos;

  const UsuarioPermisosDialog({
    super.key,
    required this.usuario,
    required this.roles,
    required this.permisos,
  });

  @override
  State<UsuarioPermisosDialog> createState() => _UsuarioPermisosDialogState();
}

class _UsuarioPermisosDialogState extends State<UsuarioPermisosDialog> {
  final _busquedaController = TextEditingController();
  UserRBACModel? _detalleUsuario;
  bool _cargando = true;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargarDetalles();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarDetalles() async {
    setState(() => _cargando = true);
    try {
      final usuarios = await CatalogService.instance.cargarUsuariosRBAC();
      final match = usuarios.firstWhere(
        (u) => u.id == widget.usuario.id || u.usuario == widget.usuario.nombre || u.email == widget.usuario.email,
        orElse: () => UserRBACModel(
          id: widget.usuario.id,
          usuario: widget.usuario.nombre,
          email: widget.usuario.email,
          rolId: '',
          rolNombre: widget.usuario.rol.label,
        ),
      );
      if (mounted) {
        setState(() {
          _detalleUsuario = match;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _toggleRolSecundario(RolModel rol, bool asignar) async {
    try {
      final userId = _detalleUsuario?.id ?? widget.usuario.id;
      if (asignar) {
        await CatalogService.instance.asignarRolUsuario(userId, rol.id);
        if (!mounted) return;
        showAppToast(context, 'Rol "${rol.rol}" asignado a ${widget.usuario.nombre}', type: ToastType.success);
      } else {
        await CatalogService.instance.removerRolUsuario(userId, rol.id);
        if (!mounted) return;
        showAppToast(context, 'Rol "${rol.rol}" retirado de ${widget.usuario.nombre}', type: ToastType.info);
      }
      await _cargarDetalles();
    } catch (e) {
      if (mounted) showAppToast(context, 'Error: $e', type: ToastType.error);
    }
  }

  Future<void> _togglePermisoDirecto(PermisoModel permiso, bool asignar) async {
    try {
      final userId = _detalleUsuario?.id ?? widget.usuario.id;
      if (asignar) {
        await CatalogService.instance.asignarPermisoUsuario(userId, permiso.id);
        if (!mounted) return;
        showAppToast(context, 'Permiso "${permiso.permiso}" otorgado', type: ToastType.success);
      } else {
        await CatalogService.instance.removerPermisoUsuario(userId, permiso.id);
        if (!mounted) return;
        showAppToast(context, 'Permiso "${permiso.permiso}" revocado', type: ToastType.info);
      }
      await _cargarDetalles();
    } catch (e) {
      if (mounted) showAppToast(context, 'Error: $e', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final esMobile = ancho < 600;

    final permisosFiltrados = widget.permisos.where((p) {
      if (_filtro.isEmpty) return true;
      return p.permiso.toLowerCase().contains(_filtro.toLowerCase());
    }).toList();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: esMobile ? ancho * 0.95 : 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                    child: const Icon(LucideIcons.shieldCheck, color: AppColors.primaryGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permisos: ${widget.usuario.nombre}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${widget.usuario.email} • Rol Principal: ${widget.usuario.rol.label}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 24),

              if (_cargando)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sección: Roles adicionales asignados en permiso_usuario
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(LucideIcons.users, size: 16, color: Color(0xFF4A5568)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Roles asignados al usuario (permiso_usuario)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'El usuario hereda todos los permisos de sus roles asignados.',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: widget.roles.map((rol) {
                                  final tieneRolSecundario = _detalleUsuario?.rolesSecundarios.any((r) => r.id == rol.id) ?? false;
                                  final esRolPrincipal = _detalleUsuario?.rolId == rol.id || widget.usuario.rol.name.toLowerCase() == rol.rol.toLowerCase();

                                  return FilterChip(
                                    selected: tieneRolSecundario || esRolPrincipal,
                                    label: Text(
                                      rol.rol + (esRolPrincipal ? ' (Principal)' : ''),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: (tieneRolSecundario || esRolPrincipal) ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    selectedColor: AppColors.primaryGreen,
                                    checkmarkColor: Colors.white,
                                    onSelected: esRolPrincipal
                                        ? null
                                        : (selected) => _toggleRolSecundario(rol, selected),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Sección: Permisos directos individuales
                        const Text(
                          'Permisos Directos Individuales',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Otorga o revoca permisos específicos a este usuario en particular.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 10),

                        // Buscador de permisos
                        TextField(
                          controller: _busquedaController,
                          decoration: InputDecoration(
                            hintText: 'Buscar permiso (ej: ZONA, MESA, CARTA)...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (v) => setState(() => _filtro = v.trim()),
                        ),
                        const SizedBox(height: 10),

                        // Lista de permisos con switches
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < permisosFiltrados.length; i++) ...[
                                if (i > 0) Divider(height: 1, color: Colors.grey.shade100),
                                () {
                                  final p = permisosFiltrados[i];
                                  final esDirecto = _detalleUsuario?.permisosDirectos.any((dir) => dir.id == p.id) ?? false;
                                  final esHeredado = (_detalleUsuario?.permisosEfectivos.contains(p.permiso) ?? false) && !esDirecto;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.permiso,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                              ),
                                              if (esHeredado)
                                                const Text(
                                                  'Heredado de rol (Activo)',
                                                  style: TextStyle(fontSize: 11, color: AppColors.primaryGreen, fontWeight: FontWeight.w600),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: esDirecto || esHeredado,
                                          activeThumbColor: Colors.white,
                                          activeTrackColor: AppColors.primaryGreen,
                                          onChanged: (v) => _togglePermisoDirecto(p, v),
                                        ),
                                      ],
                                    ),
                                  );
                                }(),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                  child: const Text('Listo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
