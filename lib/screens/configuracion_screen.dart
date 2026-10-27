import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/configuracion_store.dart';
import '../models/app_role.dart';
import '../models/horario.dart';
import '../models/rbac.dart';
import '../models/usuario.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/app_select.dart';
import '../widgets/app_toast.dart';
import '../widgets/cambiar_pin_dialog.dart';
import '../data/disponibilidad_store.dart';
import '../models/medio_pago.dart';
import '../services/api_client.dart';
import '../widgets/campo_texto.dart';
import '../widgets/config_widgets.dart';
import '../widgets/dialogo_app.dart';
import '../widgets/medio_pago_dialog.dart';
import '../widgets/submenu_lateral.dart';
import '../widgets/pestanas_vista.dart';
import '../widgets/impresoras_config.dart';
import '../widgets/sede_fiscal_config.dart';
import '../widgets/logo_tickets_editor.dart';
import '../widgets/promociones_config.dart';
import '../widgets/usuario_permisos_dialog.dart';
import '../widgets/stock_diario_config.dart';
import '../widgets/app_switch.dart';

// Configuración: submódulos Servicio, Restaurantes, Métodos de pago,
// Usuarios y roles, y Negocio.
class ConfiguracionScreen extends StatefulWidget {
  final Usuario usuario;

  const ConfiguracionScreen({super.key, required this.usuario});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  List<RolModel> _rolesRBAC = [];
  List<PermisoModel> _permisosRBAC = [];
  List<UserRBACModel> _usuariosRBAC = [];
  String? _rolSeleccionadoId;
  bool _cargandoRBAC = false;
  // Texto con el que se filtran los permisos de la tabla de roles.
  String _busquedaPermisos = '';
  // Grupos de permisos desplegados (por defecto todos van cerrados).
  final Set<String> _gruposPermisosAbiertos = {};
  // Página elegida en el submenú (escritorio).
  String _paginaClave = 'general';

  @override
  void initState() {
    super.initState();
    _cargarRBAC();
    CatalogService.instance.cargarMediosPago().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _cargarRBAC() async {
    setState(() => _cargandoRBAC = true);
    try {
      final roles = await CatalogService.instance.cargarRoles();
      final permisos = await CatalogService.instance.cargarPermisos();
      final usuarios = await CatalogService.instance.cargarUsuariosRBAC();
      if (mounted) {
        setState(() {
          _rolesRBAC = roles;
          _permisosRBAC = permisos;
          _usuariosRBAC = usuarios;
          if ((_rolSeleccionadoId == null ||
                  !_rolesRBAC.any((r) => r.id == _rolSeleccionadoId)) &&
              _rolesRBAC.isNotEmpty) {
            _rolSeleccionadoId = _rolesRBAC.first.id;
          }
          _cargandoRBAC = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoRBAC = false);
    }
  }

  Future<void> _togglePermisoRol(
    RolModel rol,
    PermisoModel permiso,
    bool asignar,
  ) async {
    try {
      if (asignar) {
        await CatalogService.instance.asignarPermisoRol(rol.id, permiso.id);
        if (!mounted) return;
        showAppToast(
          context,
          'Permiso asignado al rol ${rol.rol}',
          type: ToastType.success,
        );
      } else {
        await CatalogService.instance.removerPermisoRol(rol.id, permiso.id);
        if (!mounted) return;
        showAppToast(
          context,
          'Permiso revocado del rol ${rol.rol}',
          type: ToastType.info,
        );
      }
      await _cargarRBAC();
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'Error actualizando permiso: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _gestionarPermisosUsuario(UserRBACModel u) async {
    final usuarioModel = Usuario(
      id: u.id,
      nombre: u.usuario,
      email: u.email,
      password: '',
      rol: AppRoleLabel.fromString(u.rolNombre),
      sedeId: widget.usuario.sedeId,
      activo: u.estado,
    );
    await showBlurDialog(
      context: context,
      builder: (_) => UsuarioPermisosDialog(
        usuario: usuarioModel,
        roles: _rolesRBAC,
        permisos: _permisosRBAC,
      ),
    );
    await _cargarRBAC();
  }

  // Páginas de Configuración, agrupadas por sección en el submenú.
  List<
    ({
      String clave,
      String etiqueta,
      String? seccion,
      Widget Function() contenido,
    })
  >
  get _paginas => [
    (
      clave: 'general',
      etiqueta: 'General',
      seccion: null,
      contenido: () => _pagina(_general()),
    ),
    (
      clave: 'servicio',
      etiqueta: 'Servicio',
      seccion: null,
      contenido: () => _pagina(_servicio()),
    ),
    (
      clave: 'restaurantes',
      etiqueta: 'Restaurantes',
      seccion: null,
      contenido: () => _pagina(_restaurantes()),
    ),
    (
      clave: 'pagos',
      etiqueta: 'Métodos de pago',
      seccion: null,
      contenido: () => _pagina(_metodosPago()),
    ),
    if (widget.usuario.tienePermiso('LEER.USUARIO') || widget.usuario.esAdmin)
      (
        clave: 'usuarios',
        etiqueta: 'Usuarios y roles',
        seccion: 'Equipo',
        contenido: () => _pagina(_usuarios()),
      ),
    (
      clave: 'promociones',
      etiqueta: 'Promociones',
      seccion: 'Carta y stock',
      contenido: () => const PromocionesConfig(),
    ),
    if (widget.usuario.esAdmin ||
        widget.usuario.tienePermiso('UPDATE.SEDE_CONFIG_STOCK'))
      (
        clave: 'stock',
        etiqueta: 'Stock diario',
        seccion: 'Carta y stock',
        contenido: () => const StockDiarioConfig(),
      ),
    if (widget.usuario.esAdmin)
      (
        clave: 'impresoras',
        etiqueta: 'Impresoras',
        seccion: 'Negocio',
        contenido: () => const ImpresorasConfig(),
      ),
    if (widget.usuario.esAdmin)
      (
        clave: 'sede_fiscal',
        etiqueta: 'Sede y Facturación',
        seccion: 'Negocio',
        contenido: () => const SedeFiscalConfig(),
      ),
    (
      clave: 'negocio',
      etiqueta: 'Negocio',
      seccion: 'Negocio',
      contenido: () => _pagina(_negocio()),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final paginas = _paginas;
    final actual =
        paginas.where((p) => p.clave == _paginaClave).firstOrNull ??
        paginas.first;

    // Celular: no hay lugar para dos columnas; se mantienen las pestañas.
    if (AppBreakpoints.esMobile(context)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: PestanasVista(
          pestanas: [
            for (final p in paginas)
              (etiqueta: p.etiqueta, contenido: (_) => p.contenido()),
          ],
        ),
      );
    }

    // Subvistas agrupadas por sección, en una barra horizontal bajo el header.
    final entradas = <SubmenuEntrada>[];
    String? ultimaSeccion;
    for (final p in paginas) {
      if (p.seccion != null && p.seccion != ultimaSeccion) {
        entradas.add(SubmenuEntrada.seccion(p.seccion!));
      }
      ultimaSeccion = p.seccion;
      entradas.add(SubmenuEntrada.item(p.clave, p.etiqueta));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SubmenuSuperior(
            entradas: entradas,
            seleccionada: actual.clave,
            onSeleccionar: (c) => setState(() => _paginaClave = c),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 4),
            child: EncabezadoRuta(ruta: ['Configuración', actual.etiqueta]),
          ),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(actual.clave),
              child: actual.contenido(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagina(List<Widget> secciones) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppBreakpoints.esMobile(context) ? 16 : 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < secciones.length; i++) ...[
                if (i > 0) const SizedBox(height: 32),
                secciones[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- General (solo consulta) ----------------

  String _siNo(bool v) => v ? 'Activado' : 'Desactivado';

  List<Widget> _general() {
    final sede =
        sedes.where((s) => s.id == widget.usuario.sedeId).firstOrNull ??
        sedes.first;
    final stock = configStockNotifier.value;
    final servicios = [
      if (config.servicioLocal) 'En local',
      if (config.servicioDelivery) 'Delivery',
    ].join(' y ');
    final pagos = mediosPago.where((m) => m.activo).map((m) => m.medioPago);
    return [
      SeccionConfig(
        titulo: 'Resumen del negocio',
        descripcion: 'Datos del local. Se editan en Restaurantes y Negocio.',
        filas: [
          FilaDato(etiqueta: 'Negocio', valor: negocio.nombre),
          FilaDato(etiqueta: 'Dirección', valor: sede.direccion),
          FilaDato(etiqueta: 'RUC', valor: sede.ruc),
          FilaDato(
            etiqueta: 'Teléfono',
            valor: (sede.celular ?? '').isEmpty
                ? negocio.telefono
                : sede.celular!,
          ),
          FilaDato(
            etiqueta: 'Moneda y zona horaria',
            valor: '${negocio.moneda} · ${negocio.zonaHoraria}',
          ),
        ],
      ),
      SeccionConfig(
        titulo: 'Sesión y conexión',
        filas: [
          FilaDato(etiqueta: 'Usuario', valor: widget.usuario.nombre),
          FilaDato(etiqueta: 'Rol', valor: widget.usuario.rol.label),
          FilaDato(etiqueta: 'Servidor', valor: ApiClient.instance.baseUrl),
        ],
      ),
      SeccionConfig(
        titulo: 'Cómo está configurado',
        descripcion: 'Un vistazo a los ajustes activos.',
        filas: [
          FilaDato(
            etiqueta: 'Tipos de servicio',
            valor: servicios.isEmpty ? 'Ninguno' : servicios,
          ),
          FilaDato(
            etiqueta: 'Propina sugerida',
            valor: '${config.propinaSugerida.toStringAsFixed(0)} %',
          ),
          FilaDato(
            etiqueta: 'Descuento de empleado',
            valor: config.descuentoEmpleadoHabilitado
                ? '${config.descuentoEmpleadoPorcentaje.toStringAsFixed(0)} %'
                : 'Desactivado',
          ),
          FilaDato(
            etiqueta: 'Cobro por delivery',
            valor: config.cargoDeliveryHabilitado
                ? 'S/ ${config.cargoDeliveryMonto.toStringAsFixed(2)}'
                : 'Desactivado',
          ),
          FilaDato(
            etiqueta: 'Métodos de pago activos',
            valor: pagos.isEmpty ? 'Ninguno' : pagos.join(', '),
          ),
          FilaDato(
            etiqueta: 'Apertura diaria obligatoria',
            valor: _siNo(stock?.requiereAperturaDiaria ?? false),
          ),
          FilaDato(
            etiqueta: 'Venta con stock en cero',
            valor: _siNo(stock?.permiteSobreventa ?? false),
          ),
        ],
      ),
    ];
  }

  // ---------------- Servicio ----------------

  List<Widget> _servicio() {
    return [
      SeccionConfig(
        titulo: 'Tipos de servicio',
        descripcion: 'Qué tipos de pedido se pueden tomar (tipo de servicio).',
        filas: [
          FilaSwitch(
            titulo: 'Servicio en local',
            descripcion: 'Pedidos para comer en las mesas',
            valor: config.servicioLocal,
            onChanged: (v) {
              if (!v && !config.servicioDelivery) return _minimoUno();
              setState(() => config.servicioLocal = v);
              config.guardar();
            },
          ),
          FilaSwitch(
            titulo: 'Delivery',
            descripcion: 'Pedidos con entrega a domicilio',
            valor: config.servicioDelivery,
            onChanged: (v) {
              if (!v && !config.servicioLocal) return _minimoUno();
              setState(() => config.servicioDelivery = v);
              config.guardar();
            },
          ),
        ],
      ),
      SeccionConfig(
        titulo: 'Propinas',
        filas: [
          CampoNumeroConfig(
            etiqueta: 'Propina sugerida (botón Propina de los pedidos)',
            valor: config.propinaSugerida,
            sufijo: '%',
            onChanged: (n) {
              config.propinaSugerida = n;
              config.guardar();
            },
          ),
        ],
      ),
      SeccionConfig(
        titulo: 'Mi PIN de supervisor',
        filas: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Código para autorizar descuentos cuando otro usuario lo '
                    'necesita.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _cambiarPin,
                  icon: const Icon(LucideIcons.keyRound, size: 16),
                  label: const Text('Cambiar mi PIN'),
                ),
              ],
            ),
          ),
        ],
      ),
      SeccionConfig(
        titulo: 'Descuento de empleado',
        filas: [
          FilaSwitch(
            titulo: 'Permitir descuento de empleado',
            descripcion: 'Aparece como opción al tomar el pedido',
            valor: config.descuentoEmpleadoHabilitado,
            onChanged: (v) {
              setState(() => config.descuentoEmpleadoHabilitado = v);
              config.guardar();
            },
            extra: CampoNumeroConfig(
              etiqueta: 'Descuento',
              valor: config.descuentoEmpleadoPorcentaje,
              sufijo: '%',
              onChanged: (n) {
                config.descuentoEmpleadoPorcentaje = n;
                config.guardar();
              },
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _cambiarPin() async {
    final ok = await showBlurDialog<bool>(
      context: context,
      builder: (_) => const CambiarPinDialog(),
    );
    if (ok == true && mounted) {
      showAppToast(context, 'Tu PIN se actualizó.', type: ToastType.success);
    }
  }

  void _minimoUno() => showAppToast(
    context,
    'Debe quedar al menos un tipo de servicio activo.',
    type: ToastType.info,
  );

  // ---------------- Restaurantes ----------------

  List<Widget> _restaurantes() {
    return [
      for (var i = 0; i < sedes.length; i++)
        SeccionConfig(
          titulo: 'Restaurante ${i + 1}',
          filas: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  CampoTextoConfig(
                    etiqueta: 'Dirección',
                    valor: sedes[i].direccion,
                    onChanged: (v) =>
                        sedes[i] = sedes[i].copyWith(direccion: v),
                  ),
                  const SizedBox(height: 12),
                  CampoTextoConfig(
                    etiqueta: 'Teléfono',
                    valor: sedes[i].celular ?? '',
                    teclado: TextInputType.phone,
                    onChanged: (v) => sedes[i] = sedes[i].copyWith(celular: v),
                  ),
                ],
              ),
            ),
            FilaSwitch(
              titulo: 'Activo',
              descripcion: 'Si se apaga, el local deja de operar en el sistema',
              valor: sedes[i].activo,
              onChanged: (v) =>
                  setState(() => sedes[i] = sedes[i].copyWith(activo: v)),
            ),
          ],
        ),
    ];
  }

  // ---------------- Métodos de pago ----------------

  Future<void> _editarMedioPago([MedioPago? medio]) async {
    final guardado = await showBlurDialog<bool>(
      context: context,
      builder: (_) => MedioPagoDialog(medio: medio),
    );
    if (guardado == true && mounted) {
      setState(() {});
      showAppToast(
        context,
        medio == null
            ? 'Método de pago creado.'
            : 'Método de pago actualizado.',
        type: ToastType.success,
      );
    }
  }

  Future<void> _eliminarMedioPago(MedioPago m) async {
    if (mediosPago.where((x) => x.activo && x.id != m.id).isEmpty) {
      showAppToast(
        context,
        'Debe quedar al menos un método de pago activo.',
        type: ToastType.info,
      );
      return;
    }
    final confirmar = await showBlurDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertaApp(
        title: const Text('Eliminar método de pago'),
        content: Text(
          '¿Eliminar "${m.medioPago}"? Si ya se usó en pagos, no se podrá '
          'borrar: en ese caso apágalo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await CatalogService.instance.eliminarMedioPago(m.id);
      if (!mounted) return;
      setState(() {});
      showAppToast(
        context,
        '"${m.medioPago}" se eliminó.',
        type: ToastType.info,
      );
    } catch (e) {
      if (!mounted) return;
      final texto = e is ApiException ? e.message : e.toString();
      final enUso =
          texto.contains('llave for') || texto.contains('foreign key');
      showAppToast(
        context,
        enUso
            ? 'No se puede eliminar: ya tiene pagos registrados. Apágalo para '
                  'dejar de ofrecerlo.'
            : 'No se pudo eliminar: $texto',
        type: ToastType.error,
      );
    }
  }

  Future<void> _alternarMedioPago(MedioPago m, bool activo) async {
    if (!activo && mediosPago.where((x) => x.activo).length <= 1) {
      showAppToast(
        context,
        'Debe quedar al menos un método de pago activo.',
        type: ToastType.info,
      );
      return;
    }
    try {
      await CatalogService.instance.actualizarMedioPago(m.id, activo: activo);
      if (!mounted) return;
      setState(() {});
      showAppToast(
        context,
        '"${m.medioPago}" ${activo ? 'activado' : 'desactivado'}.',
        type: activo ? ToastType.success : ToastType.info,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'No se pudo actualizar: ${e is ApiException ? e.message : e}',
        type: ToastType.error,
      );
    }
  }

  Widget _filaMedioPago(MedioPago m) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.medioPago,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: m.activo ? Colors.black87 : Colors.grey.shade500,
                  ),
                ),
                Text(
                  [
                    if (m.descripcion != null && m.descripcion!.isNotEmpty)
                      m.descripcion!,
                    if (m.aplicaComision)
                      'Recargo ${m.porcentajeComision.toStringAsFixed(m.porcentajeComision.truncateToDouble() == m.porcentajeComision ? 0 : 2)} %',
                    if (!m.activo) 'No se ofrece al cobrar',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar',
            onPressed: () => _editarMedioPago(m),
            icon: Icon(
              LucideIcons.pencil,
              size: 16,
              color: Colors.grey.shade700,
            ),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: () => _eliminarMedioPago(m),
            icon: const Icon(
              LucideIcons.trash2,
              size: 16,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: 4),
          AppSwitch(
            value: m.activo,
            onChanged: (v) => _alternarMedioPago(m, v),
          ),
        ],
      ),
    );
  }

  List<Widget> _metodosPago() {
    return [
      SeccionConfig(
        titulo: 'Métodos de pago',
        descripcion:
            'Los que se ofrecen al cobrar. Si uno ya se usó en pagos no se puede '
            'borrar: apágalo para dejar de ofrecerlo.',
        accion: FilledButton.icon(
          onPressed: () => _editarMedioPago(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Método'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
          ),
        ),
        filas: [
          if (mediosPago.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No hay métodos de pago registrados. Crea el primero con '
                '"Método".',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            for (final m in mediosPago) _filaMedioPago(m),
        ],
      ),
      SeccionConfig(
        titulo: 'Cobro adicional por delivery',
        filas: [
          FilaSwitch(
            titulo: 'Cobrar un monto extra en pedidos delivery',
            descripcion: 'Se sugiere al tomar un pedido de delivery',
            valor: config.cargoDeliveryHabilitado,
            onChanged: (v) {
              setState(() => config.cargoDeliveryHabilitado = v);
              config.guardar();
            },
            extra: CampoNumeroConfig(
              etiqueta: 'Monto',
              valor: config.cargoDeliveryMonto,
              prefijo: 'S/ ',
              onChanged: (n) {
                config.cargoDeliveryMonto = n;
                config.guardar();
              },
            ),
          ),
        ],
      ),
    ];
  }

  // ---------------- Usuarios y roles ----------------

  List<Widget> _usuarios() {
    return [
      SeccionConfig(
        titulo: 'Usuarios',
        descripcion: 'Quién usa el sistema, con qué rol y si está activo.',
        accion: FilledButton.icon(
          onPressed: _nuevoUsuario,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Usuario'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
          ),
        ),
        filas: [
          if (_cargandoRBAC && _usuariosRBAC.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_usuariosRBAC.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No hay usuarios registrados.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            for (final u in _usuariosRBAC) _filaUsuario(u),
        ],
      ),
      SeccionConfig(
        titulo: 'Permisos por rol',
        descripcion: 'Marca qué puede hacer cada rol del sistema.',
        filas: [
          if (_cargandoRBAC && _rolesRBAC.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rolesRBAC.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No se pudieron cargar los roles del sistema.'),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              // El buscador llega hasta donde empiezan las columnas de roles.
              child: LayoutBuilder(
                builder: (context, c) {
                  final columnas = _rolesRBAC.length * 104.0;
                  final ancho = (c.maxWidth - columnas - 16).clamp(
                    c.maxWidth < 220 ? c.maxWidth : 220.0,
                    c.maxWidth,
                  );
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: ancho,
                      child: CampoTexto(
                        onChanged: (v) => setState(() => _busquedaPermisos = v),
                        decoration: const InputDecoration(
                          hintText: 'Buscar permiso...',
                          prefixIcon: Icon(Icons.search, size: 20),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            _tablaPermisos(),
          ],
        ],
      ),
    ];
  }

  // Tabla de permisos: una fila por permiso (agrupadas por tema) y una columna
  // con casilla por cada rol.
  Widget _tablaPermisos() {
    final categorias = <String, List<PermisoModel>>{
      'Mesas y Zonas': [],
      'Carta y Menú': [],
      'Pedidos y Propinas': [],
      'Caja y Pagos': [],
      'Seguridad y Usuarios': [],
    };
    final termino = _busquedaPermisos.trim().toUpperCase();
    for (final p in _permisosRBAC) {
      final perm = p.permiso.toUpperCase();
      if (termino.isNotEmpty && !perm.contains(termino)) continue;
      if (perm.contains('ZONA') || perm.contains('MESA')) {
        categorias['Mesas y Zonas']!.add(p);
      } else if (perm.contains('CARTA') ||
          perm.contains('CATEGORIA') ||
          perm.contains('TAPER') ||
          perm.contains('MODIFICADOR')) {
        categorias['Carta y Menú']!.add(p);
      } else if (perm.contains('PEDIDO') || perm.contains('PROPINA')) {
        categorias['Pedidos y Propinas']!.add(p);
      } else if (perm.contains('PAGO') ||
          perm.contains('MOVIMIENTO') ||
          perm.contains('MEDIO')) {
        categorias['Caja y Pagos']!.add(p);
      } else {
        categorias['Seguridad y Usuarios']!.add(p);
      }
    }

    if (categorias.values.every((l) => l.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Ningún permiso coincide con la búsqueda.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    // En el celular las columnas de roles son más angostas para que quepan más.
    final movil = AppBreakpoints.esMobile(context);
    final anchoRol = movil ? 74.0 : 104.0;
    final estiloCabecera = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade700,
    );
    Table tablaDe(List<TableRow> filas) => Table(
      columnWidths: {
        0: const FlexColumnWidth(),
        for (var i = 0; i < _rolesRBAC.length; i++)
          i + 1: FixedColumnWidth(anchoRol),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade200),
      ),
      children: filas,
    );

    // Cabecera de un grupo: al tocarla se despliegan sus permisos. Cerrada,
    // muestra cuántos permisos del grupo tiene cada rol.
    Widget cabeceraGrupo(
      String titulo,
      List<PermisoModel> lista,
      bool abierto,
      bool forzado,
    ) => InkWell(
      onTap: forzado
          ? null
          : () => setState(() {
              if (!_gruposPermisosAbiertos.remove(titulo)) {
                _gruposPermisosAbiertos.add(titulo);
              }
            }),
      child: Container(
        color: Colors.grey.shade50,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    abierto ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      titulo,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${lista.length} permisos',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            for (final r in _rolesRBAC)
              SizedBox(
                width: anchoRol,
                child: Center(
                  child: Text(
                    '${lista.where((p) => r.tienePermiso(p.permiso)).length}/'
                    '${lista.length}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final buscando = termino.isNotEmpty;
    final tabla = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tablaDe([
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Permiso', style: estiloCabecera),
              ),
              for (final r in _rolesRBAC)
                Center(
                  child: Text(
                    r.rol,
                    textAlign: TextAlign.center,
                    style: estiloCabecera.copyWith(fontSize: movil ? 11 : 12.5),
                  ),
                ),
            ],
          ),
        ]),
        for (final entry in categorias.entries)
          if (entry.value.isNotEmpty) ...[
            cabeceraGrupo(
              entry.key,
              entry.value,
              buscando || _gruposPermisosAbiertos.contains(entry.key),
              buscando,
            ),
            if (buscando || _gruposPermisosAbiertos.contains(entry.key))
              tablaDe([
                for (final p in entry.value)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 0, 4),
                        // Sin recortar: el nombre del permiso baja de línea.
                        child: Text(
                          p.permiso,
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      for (final r in _rolesRBAC)
                        Center(
                          child: AppCheck(
                            value: r.tienePermiso(p.permiso),
                            onChanged: (v) => _togglePermisoRol(r, p, v),
                          ),
                        ),
                    ],
                  ),
              ]),
          ],
      ],
    );

    // Con muchos roles la tabla se desplaza hacia el lado.
    return LayoutBuilder(
      builder: (context, c) {
        final minimo = (movil ? 200 : 260) + _rolesRBAC.length * anchoRol;
        if (c.maxWidth >= minimo) return tabla;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: minimo, child: tabla),
        );
      },
    );
  }

  Widget _filaUsuario(UserRBACModel u) {
    final soyYo = u.id == widget.usuario.id;
    final rolActual =
        _rolesRBAC.where((r) => r.id == u.rolId).firstOrNull ??
        RolModel(
          id: u.rolId,
          rol: u.rolNombre.isNotEmpty ? u.rolNombre : 'Sin rol',
        );

    final identidad = [
      CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
        child: Text(
          u.usuario.isEmpty ? '?' : u.usuario[0].toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              u.usuario + (soyYo ? ' (tú)' : ''),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              u.email,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    ];
    // El selector de rol, sin ancho propio: lo da el diseño según el espacio.
    final selectorRol = IgnorePointer(
      ignoring: soyYo,
      child: Opacity(
        opacity: soyYo ? 0.6 : 1,
        child: AppSelect<String>(
          value: rolActual.id,
          items: [
            for (final r in _rolesRBAC)
              AppSelectItem(value: r.id, label: r.rol),
          ],
          onChanged: (id) async {
            if (id == null || id == u.rolId) return;
            try {
              await CatalogService.instance.actualizarRolUsuario(u.id, id);
              if (!mounted) return;
              final nombre = _rolesRBAC.firstWhere((r) => r.id == id).rol;
              showAppToast(
                context,
                'Rol de ${u.usuario} actualizado a $nombre',
                type: ToastType.success,
              );
              await _cargarRBAC();
            } catch (e) {
              if (!mounted) return;
              showAppToast(
                context,
                'Error actualizando rol: $e',
                type: ToastType.error,
              );
            }
          },
        ),
      ),
    );
    final interruptor = Tooltip(
      message: soyYo
          ? 'No puedes desactivarte'
          : (u.estado ? 'Desactivar usuario' : 'Activar usuario'),
      child: AppSwitch(
        value: u.estado,
        onChanged: soyYo
            ? null
            : (v) async {
                try {
                  await CatalogService.instance.actualizarEstadoUsuario(
                    u.id,
                    v,
                  );
                  if (!mounted) return;
                  showAppToast(
                    context,
                    v
                        ? 'Usuario "${u.usuario}" activado'
                        : 'Usuario "${u.usuario}" desactivado',
                    type: v ? ToastType.success : ToastType.info,
                  );
                  await _cargarRBAC();
                } catch (e) {
                  if (!mounted) return;
                  showAppToast(
                    context,
                    'Error actualizando estado: $e',
                    type: ToastType.error,
                  );
                }
              },
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primaryGreen,
      ),
    );
    final permisos = Tooltip(
      message: 'Gestionar permisos directos y roles',
      child: IconButton(
        icon: const Icon(
          LucideIcons.shieldCheck,
          color: AppColors.primaryGreen,
          size: 20,
        ),
        onPressed: () => _gestionarPermisosUsuario(u),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, c) {
          // En un ancho chico los controles bajan a una segunda línea.
          if (c.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: identidad),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: selectorRol),
                    const SizedBox(width: 8),
                    interruptor,
                    const SizedBox(width: 4),
                    permisos,
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              ...identidad,
              SizedBox(width: 190, child: selectorRol),
              const SizedBox(width: 8),
              interruptor,
              const SizedBox(width: 8),
              permisos,
            ],
          );
        },
      ),
    );
  }

  Future<void> _nuevoUsuario() async {
    if (_rolesRBAC.isEmpty) {
      showAppToast(
        context,
        'No se pudieron cargar los roles. Revisa la conexión e inténtalo otra '
        'vez.',
        type: ToastType.error,
      );
      _cargarRBAC();
      return;
    }
    final usuario = TextEditingController();
    final nombre = TextEditingController();
    final apellidos = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final dni = TextEditingController();
    final sueldo = TextEditingController();
    final pin = TextEditingController();
    // Rol por defecto: el de mozo si existe.
    var rolId =
        (_rolesRBAC.where((r) => r.rol.toUpperCase() == 'MOZO').firstOrNull ??
                _rolesRBAC.first)
            .id;
    String? error;
    var guardando = false;

    // Valida los datos y devuelve el primer problema, o null si está todo bien.
    String? validar() {
      final u = usuario.text.trim();
      if (u.isEmpty) return 'Escribe el nombre de usuario.';
      if (u.length > 30) return 'El usuario admite máximo 30 caracteres.';
      if (!email.text.contains('@') || !email.text.contains('.')) {
        return 'Escribe un correo válido.';
      }
      if (password.text.length < 4) {
        return 'La contraseña debe tener al menos 4 caracteres.';
      }
      if (dni.text.trim().length > 9) {
        return 'El documento admite máximo 9 caracteres.';
      }
      final s = sueldo.text.trim();
      if (s.isNotEmpty && double.tryParse(s.replaceAll(',', '.')) == null) {
        return 'El sueldo no es un número válido.';
      }
      final p = pin.text.trim();
      if (p.isNotEmpty && !RegExp(r'^\d{4,10}$').hasMatch(p)) {
        return 'El PIN debe tener de 4 a 10 dígitos.';
      }
      return null;
    }

    final creado = await showBlurDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> crear() async {
            final problema = validar();
            if (problema != null) {
              setLocal(() => error = problema);
              return;
            }
            setLocal(() {
              guardando = true;
              error = null;
            });
            try {
              final nuevo = await CatalogService.instance.crearUsuario(
                usuario: usuario.text.trim(),
                email: email.text.trim(),
                password: password.text,
                rolId: rolId,
                nombre: nombre.text.trim(),
                apellidos: apellidos.text.trim(),
                identificacion: dni.text.trim(),
                sueldo: double.tryParse(
                  sueldo.text.trim().replaceAll(',', '.'),
                ),
                pin: pin.text.trim(),
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(nuevo.usuario);
              }
            } catch (e) {
              setLocal(() {
                guardando = false;
                error = e is ApiException
                    ? e.message
                    : e.toString().replaceFirst('Exception: ', '');
              });
            }
          }

          return DialogoApp(
            titulo: 'Nuevo usuario',
            acciones: [
              TextButton(
                onPressed: guardando
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: guardando ? null : crear,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Crear'),
              ),
            ],
            children: [
              CampoDialogo(
                etiqueta: 'Usuario',
                controller: usuario,
                hint: 'Con el que inicia sesión (ej. carlos1)',
                autofocus: true,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CampoDialogo(
                      etiqueta: 'Nombre (opcional)',
                      controller: nombre,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CampoDialogo(
                      etiqueta: 'Apellidos (opcional)',
                      controller: apellidos,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CampoDialogo(
                etiqueta: 'Correo',
                controller: email,
                hint: 'correo@ejemplo.com',
                teclado: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              CampoDialogo(
                etiqueta: 'Contraseña',
                controller: password,
                hint: 'Mínimo 4 caracteres',
                oculto: true,
              ),
              const SizedBox(height: 14),
              AppSelect<String>(
                label: 'Rol',
                value: rolId,
                items: [
                  for (final r in _rolesRBAC)
                    AppSelectItem(value: r.id, label: r.rol),
                ],
                onChanged: (v) => setLocal(() => rolId = v ?? rolId),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CampoDialogo(
                      etiqueta: 'DNI (opcional)',
                      controller: dni,
                      teclado: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CampoDialogo(
                      etiqueta: 'Sueldo S/ (opcional)',
                      controller: sueldo,
                      teclado: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CampoDialogo(
                etiqueta: 'PIN (opcional)',
                controller: pin,
                hint: 'Si lo dejas vacío, será 1234 y se pedirá cambiarlo',
                teclado: TextInputType.number,
                oculto: true,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ],
            ],
          );
        },
      ),
    );
    for (final c in [
      usuario,
      nombre,
      apellidos,
      email,
      password,
      dni,
      sueldo,
      pin,
    ]) {
      c.dispose();
    }
    if (creado == null || !mounted) return;
    await _cargarRBAC();
    if (!mounted) return;
    showAppToast(
      context,
      'Usuario "$creado" creado.',
      type: ToastType.success,
      titulo: 'Usuario creado',
    );
  }

  // ---------------- Negocio ----------------

  List<Widget> _negocio() {
    Widget par(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );
    return [
      SeccionConfig(
        titulo: 'Información del negocio',
        filas: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                CampoTextoConfig(
                  etiqueta: 'Nombre',
                  valor: negocio.nombre,
                  onChanged: (v) => negocio.nombre = v,
                ),
                const SizedBox(height: 12),
                par(
                  CampoTextoConfig(
                    etiqueta: 'Teléfono',
                    valor: negocio.telefono,
                    teclado: TextInputType.phone,
                    onChanged: (v) => negocio.telefono = v,
                  ),
                  CampoTextoConfig(
                    etiqueta: 'Correo de contacto',
                    valor: negocio.emailContacto,
                    teclado: TextInputType.emailAddress,
                    onChanged: (v) => negocio.emailContacto = v,
                  ),
                ),
                const SizedBox(height: 12),
                CampoTextoConfig(
                  etiqueta: 'Dirección',
                  valor: negocio.direccion,
                  onChanged: (v) => negocio.direccion = v,
                ),
                const SizedBox(height: 12),
                par(
                  CampoTextoConfig(
                    etiqueta: 'Moneda',
                    valor: negocio.moneda,
                    onChanged: (v) => negocio.moneda = v,
                  ),
                  CampoTextoConfig(
                    etiqueta: 'Idioma',
                    valor: negocio.idioma,
                    onChanged: (v) => negocio.idioma = v,
                  ),
                ),
                const SizedBox(height: 12),
                par(
                  CampoTextoConfig(
                    etiqueta: 'País',
                    valor: negocio.pais,
                    onChanged: (v) => negocio.pais = v,
                  ),
                  CampoTextoConfig(
                    etiqueta: 'Zona horaria',
                    valor: negocio.zonaHoraria,
                    onChanged: (v) => negocio.zonaHoraria = v,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      _seccionHorario(),
      // El logo que sale en los tickets de caja (lo cambia el administrador).
      if (widget.usuario.esAdmin)
        const SeccionConfig(
          titulo: 'Logo de los tickets',
          descripcion:
              'Sale arriba de las cuentas que se imprimen en caja. En blanco '
              'y negro: el sistema lo convierte para la ticketera.',
          filas: [LogoTicketsEditor()],
        ),
    ];
  }

  // ---------------- Horario de atención ----------------

  String _hora12(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '${h.toString().padLeft(2, '0')}:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  // Horas cada media hora; si el horario guardado cae fuera, se agrega.
  List<AppSelectItem<TimeOfDay>> _opcionesHora(TimeOfDay? actual) {
    final horas = <TimeOfDay>[
      for (var h = 0; h < 24; h++)
        for (final m in const [0, 30]) TimeOfDay(hour: h, minute: m),
    ];
    if (actual != null && !horas.contains(actual)) {
      horas.add(actual);
      horas.sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
    }
    return [for (final t in horas) AppSelectItem(value: t, label: _hora12(t))];
  }

  Widget _seccionHorario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Horario de atención',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Enciende los días que abre el local y elige su horario.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            const aire = 16.0;
            final columnas = c.maxWidth >= 820
                ? 3
                : (c.maxWidth >= 520 ? 2 : 1);
            final ancho = (c.maxWidth - aire * (columnas - 1)) / columnas;
            return Wrap(
              spacing: aire,
              runSpacing: aire,
              children: [
                for (var i = 0; i < horarios.length; i++)
                  SizedBox(width: ancho, child: _tarjetaHorario(i)),
              ],
            );
          },
        ),
      ],
    );
  }

  // Un día: encabezado con el interruptor y, debajo, día / desde / hasta.
  Widget _tarjetaHorario(int i) {
    final Horario h = horarios[i];
    Widget fila(String etiqueta, Widget campo) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              etiqueta,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(child: campo),
        ],
      ),
    );
    final dia = Container(
      height: AppSizes.control,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.tag),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        h.dia,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Icon(LucideIcons.clock, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Horario',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
                Text(
                  h.abierto ? 'Abierto' : 'Cerrado',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                AppSwitch(
                  value: h.abierto,
                  onChanged: (v) =>
                      setState(() => horarios[i] = h.copyWith(abierto: v)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.all(16),
            child: IgnorePointer(
              ignoring: !h.abierto,
              child: Opacity(
                opacity: h.abierto ? 1 : 0.5,
                child: Column(
                  children: [
                    fila('Día', dia),
                    fila(
                      'Desde',
                      AppSelect<TimeOfDay>(
                        hint: '--:--',
                        value: h.inicio,
                        items: _opcionesHora(h.inicio),
                        onChanged: (t) =>
                            setState(() => horarios[i] = h.copyWith(inicio: t)),
                      ),
                    ),
                    fila(
                      'Hasta',
                      AppSelect<TimeOfDay>(
                        hint: '--:--',
                        value: h.fin,
                        items: _opcionesHora(h.fin),
                        onChanged: (t) =>
                            setState(() => horarios[i] = h.copyWith(fin: t)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
