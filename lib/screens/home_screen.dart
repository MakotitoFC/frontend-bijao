import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/nav_items.dart';
import '../models/categoria_comida.dart';
import '../models/app_role.dart';
import '../models/mock_user.dart';
import '../models/nav_item.dart';
import '../models/sede.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'carta_screen.dart';
import 'cocina_screen.dart';
import 'configuracion_screen.dart';
import 'inventario_screen.dart';
import 'login_screen.dart';
import 'pagos_screen.dart';
import 'pedidos_screen.dart';
import 'reportes_screen.dart';

// Shell principal: navbar lateral + header global + contenido según la
// vista elegida. Ver nav_items.dart para las vistas disponibles.
class HomeScreen extends StatefulWidget {
  final Sede sede;
  final MockUser usuario;

  const HomeScreen({super.key, required this.sede, required this.usuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _colapsado = false;
  String _seleccionado = 'inicio';
  // Grupos del navbar (ej. "Ventas") desplegados.
  final Set<String> _gruposAbiertos = {};
  final ValueNotifier<CategoriaComida?> _categoriaProductos = ValueNotifier(
    null,
  );
  final ValueNotifier<String> _busquedaProductos = ValueNotifier('');

  @override
  void dispose() {
    _categoriaProductos.dispose();
    _busquedaProductos.dispose();
    super.dispose();
  }

  // Título y descripción breve de cada vista, que muestra el header global.
  static const _titulos = <String, ({String titulo, String descripcion})>{
    'inicio': (titulo: 'Inicio', descripcion: 'Resumen de tu restaurante'),
    'pedidos': (
      titulo: 'Pedidos',
      descripcion: 'Toma pedidos, elige mesa o delivery y sigue la cola',
    ),
    'productos': (
      titulo: 'Productos',
      descripcion: 'Administra tu carta, precios y categorías',
    ),
    'cocina': (
      titulo: 'Cocina',
      descripcion: 'Comandas pendientes por preparar',
    ),
    'historial_pedidos': (
      titulo: 'Historial de pedidos',
      descripcion: 'Pedidos y su estado de pago',
    ),
    'caja': (
      titulo: 'Caja',
      descripcion: 'Caja actual y cierres de caja',
    ),
    'reportes': (titulo: 'Reportes', descripcion: 'Ventas y reportes'),
    'finanzas': (
      titulo: 'Finanzas',
      descripcion: 'Resumen financiero del negocio',
    ),
    'inventario': (
      titulo: 'Inventario',
      descripcion: 'Productos, compras y utensilios rotos',
    ),
    'configuracion': (
      titulo: 'Configuración',
      descripcion:
          'Servicio, restaurantes, métodos de pago, usuarios y negocio',
    ),
  };

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _contenidoDe(String clave) {
    switch (clave) {
      case 'pedidos':
        return PedidosScreen(usuario: widget.usuario);
      case 'productos':
        return CartaScreen(
          esAdmin: widget.usuario.rol == AppRole.administrador,
          seleccion: _categoriaProductos,
          busqueda: _busquedaProductos,
          cabeceraPropia: true,
        );
      // Vistas aún sin desarrollar: comparten el mismo placeholder.
      case 'inicio':
        return _InicioContent(
          usuario: widget.usuario,
          sede: widget.sede,
          nombreVista: 'Inicio',
        );
      case 'cocina':
        return const CocinaScreen();
      case 'historial_pedidos':
        return HistorialPedidosScreen(usuario: widget.usuario);
      case 'caja':
        return CajaScreen(usuario: widget.usuario);
      case 'reportes':
        return const ReportesScreen();
      case 'finanzas':
        return _InicioContent(
          usuario: widget.usuario,
          sede: widget.sede,
          nombreVista: 'Finanzas',
        );
      case 'inventario':
        return const InventarioScreen();
      case 'configuracion':
        return ConfiguracionScreen(usuario: widget.usuario);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = navItems
        .where((i) => i.rolesPermitidos.contains(widget.usuario.rol))
        .toList();

    if (AppBreakpoints.esMobile(context)) {
      // Mobile: navbar inferior en vez de lateral (ver _BottomNav).
      final individuales = items.where((i) => !i.esGrupo).toList();
      final grupos = items.where((i) => i.esGrupo).toList();
      final caben = grupos.isEmpty && individuales.length <= 4;
      final principales = caben ? individuales : individuales.take(3).toList();
      final restantes = <NavItem>[
        if (!caben) ...individuales.skip(3),
        ...grupos,
      ];
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _GlobalHeader(
              usuario: widget.usuario,
              mostrarLogo: true,
              onConfiguracion: () =>
                  setState(() => _seleccionado = 'configuracion'),
              onLogout: () => _logout(context),
            ),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(_seleccionado),
                child: _contenidoDe(_seleccionado),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          principales: principales,
          restantes: restantes,
          seleccionado: _seleccionado,
          onSeleccionar: (clave) => setState(() => _seleccionado = clave),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _Sidebar(
            usuario: widget.usuario,
            onConfiguracion: () =>
                setState(() => _seleccionado = 'configuracion'),
            onLogout: () => _logout(context),
            colapsado: _colapsado,
            items: items,
            seleccionado: _seleccionado,
            gruposAbiertos: _gruposAbiertos,
            onToggle: () => setState(() => _colapsado = !_colapsado),
            onSeleccionar: (clave) => setState(() => _seleccionado = clave),
            onAlternarGrupo: (clave) => setState(() {
              if (!_gruposAbiertos.remove(clave)) _gruposAbiertos.add(clave);
            }),
          ),
          Expanded(
            child: Column(
              children: [
                _GlobalHeader(
                  usuario: widget.usuario,
                  barraFija: true,
                  titulo: _titulos[_seleccionado]?.titulo,
                  descripcion: _titulos[_seleccionado]?.descripcion,
                  onConfiguracion: () =>
                      setState(() => _seleccionado = 'configuracion'),
                  onLogout: () => _logout(context),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(_seleccionado),
                    child: _contenidoDe(_seleccionado),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Header global: campana + usuario (menú de Configuración/Cerrar sesión).
class _GlobalHeader extends StatelessWidget {
  final MockUser usuario;
  final bool mostrarLogo;
  final bool barraFija;
  final String? titulo;
  final String? descripcion;
  final VoidCallback onConfiguracion;
  final VoidCallback onLogout;

  const _GlobalHeader({
    required this.usuario,
    this.mostrarLogo = false,
    this.barraFija = false,
    this.titulo,
    this.descripcion,
    required this.onConfiguracion,
    required this.onLogout,
  });

  // Botón cuadrado de esquinas redondeadas con el trazo del ícono en gris.
  Widget _botonIcono(IconData icono, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Icon(icono, size: 20, color: Colors.grey.shade600),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final derecha = Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...[
            const Icon(LucideIcons.bellDot, size: 22, color: Colors.black87),
            const SizedBox(width: 20),
            _MenuUsuario(
              usuario: usuario,
              mostrarNombre: !mostrarLogo,
              mostrarFlecha: true,
              onConfiguracion: onConfiguracion,
              onLogout: onLogout,
            ),
          ],
        ],
      ),
    );

    if (barraFija) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        decoration: BoxDecoration(
          color: AppColors.header,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (descripcion != null)
                        Text(
                          descripcion!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _botonIcono(LucideIcons.bell, 'Notificaciones', () {}),
                const SizedBox(width: 10),
                _botonIcono(
                  LucideIcons.settings,
                  'Configuración',
                  onConfiguracion,
                ),
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(mostrarLogo ? 16 : 24, 12, 16, 12),
      child: Row(
        children: [if (mostrarLogo) const _Logo(), const Spacer(), derecha],
      ),
    );
  }
}

// Avatar del usuario con su menú (Configuración / Cerrar sesión).
class _MenuUsuario extends StatelessWidget {
  final MockUser usuario;
  final bool mostrarNombre;
  final bool mostrarFlecha;
  final VoidCallback onConfiguracion;
  final VoidCallback onLogout;

  const _MenuUsuario({
    required this.usuario,
    required this.mostrarNombre,
    this.mostrarFlecha = false,
    required this.onConfiguracion,
    required this.onLogout,
  });

  String get _iniciales {
    final partes = usuario.nombre.trim().split(RegExp(r'\s+'));
    final letras = partes.take(2).map((p) => p.isEmpty ? '' : p[0]).join();
    return letras.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      onSelected: (value) {
        if (value == 'configuracion') onConfiguracion();
        if (value == 'logout') onLogout();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'configuracion',
          child: Row(
            children: const [
              Icon(LucideIcons.settings, size: 18, color: Colors.black87),
              SizedBox(width: 12),
              Text('Configuración'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: const [
              Icon(LucideIcons.logOut, size: 18, color: Colors.black87),
              SizedBox(width: 12),
              Text('Cerrar sesión'),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(36 * 0.2),
            ),
            child: Text(
              _iniciales,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (mostrarNombre) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuario.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    usuario.rol.label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
          if (mostrarFlecha) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: Colors.grey.shade500,
            ),
          ],
        ],
      ),
    );
  }
}

// Navbar inferior (mobile): vistas principales + "Más" con el resto.
class _BottomNav extends StatelessWidget {
  final List<NavItem> principales;
  final List<NavItem> restantes;
  final String seleccionado;
  final ValueChanged<String> onSeleccionar;

  const _BottomNav({
    required this.principales,
    required this.restantes,
    required this.seleccionado,
    required this.onSeleccionar,
  });

  bool get _masActivo => restantes.any(
    (i) => i.clave == seleccionado || i.hijos.any((h) => h.clave == seleccionado),
  );

  Future<void> _abrirMas(BuildContext context) async {
    final elegido = await showBlurDialog<String>(
      context: context,
      builder: (_) => _HojaMas(items: restantes, seleccionado: seleccionado),
    );
    if (elegido != null) onSeleccionar(elegido);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final item in principales)
              Expanded(
                child: _botonNav(
                  icono: item.icono,
                  etiqueta: item.label,
                  activo: seleccionado == item.clave,
                  onTap: () => onSeleccionar(item.clave),
                ),
              ),
            if (restantes.isNotEmpty)
              Expanded(
                child: _botonNavMas(
                  activo: _masActivo,
                  onTap: () => _abrirMas(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _botonNav({
    required IconData icono,
    required String etiqueta,
    required bool activo,
    required VoidCallback onTap,
  }) {
    final color = activo ? AppColors.primaryGreen : Colors.grey.shade500;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonNavMas({required bool activo, required VoidCallback onTap}) {
    final color = activo ? AppColors.primaryGreen : Colors.grey.shade500;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              'Más',
              style: TextStyle(
                fontSize: 11,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Hoja inferior con las vistas que no caben en la barra inferior.
class _HojaMas extends StatelessWidget {
  final List<NavItem> items;
  final String seleccionado;

  const _HojaMas({required this.items, required this.seleccionado});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadii.sheet),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Más opciones',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            for (final item in items) ...[
              if (item.esGrupo) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      Icon(item.icono, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 10),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final hijo in item.hijos) _fila(context, hijo, indentado: true),
              ] else
                _fila(context, item),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _fila(BuildContext context, NavItem item, {bool indentado = false}) {
    final activo = seleccionado == item.clave;
    return ListTile(
      contentPadding: EdgeInsets.only(left: indentado ? 36 : 16, right: 16),
      leading: Icon(
        item.icono,
        size: 22,
        color: activo ? AppColors.primaryGreen : Colors.black87,
      ),
      title: Text(
        item.label,
        style: TextStyle(
          fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
          color: activo ? AppColors.primaryGreen : Colors.black87,
        ),
      ),
      onTap: () => Navigator.of(context).pop(item.clave),
    );
  }
}

// Placeholder de "página en construcción" para vistas sin contenido real.
class _InicioContent extends StatelessWidget {
  final MockUser usuario;
  final Sede sede;
  final String nombreVista;

  const _InicioContent({
    required this.usuario,
    required this.sede,
    required this.nombreVista,
  });

  @override
  Widget build(BuildContext context) {
    final esInicio = nombreVista == 'Inicio';
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sede.direccion,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.construction,
                    size: 44,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Hola, ${usuario.nombre}',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                usuario.rol.label,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.primaryGreen),
              ),
              const SizedBox(height: 20),
              Text(
                esInicio
                    ? 'El dashboard está en construcción'
                    : 'El módulo de $nombreVista está en construcción',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                esInicio
                    ? 'Pronto verás aquí un resumen de ventas, mesas y pedidos.'
                    : 'Pronto podrás usar $nombreVista desde aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Navbar lateral: contraído solo íconos, expandido íconos + nombre.
class _Sidebar extends StatelessWidget {
  final bool colapsado;
  final List<NavItem> items;
  final String seleccionado;
  final Set<String> gruposAbiertos;
  final MockUser usuario;
  final VoidCallback onConfiguracion;
  final VoidCallback onLogout;
  final VoidCallback onToggle;
  final ValueChanged<String> onSeleccionar;
  final ValueChanged<String> onAlternarGrupo;

  const _Sidebar({
    required this.usuario,
    required this.onConfiguracion,
    required this.onLogout,
    required this.colapsado,
    required this.items,
    required this.seleccionado,
    required this.gruposAbiertos,
    required this.onToggle,
    required this.onSeleccionar,
    required this.onAlternarGrupo,
  });

  static const double _anchoExpandido = 212;
  static const double _anchoContraido = 96;

  List<NavItem> _hijosPermitidos(NavItem item) =>
      item.hijos.where((h) => h.rolesPermitidos.contains(usuario.rol)).toList();

  List<Widget> _construirTiles() {
    final tiles = <Widget>[];
    for (final item in items) {
      if (item.esGrupo) {
        final hijos = _hijosPermitidos(item);
        tiles.add(_navTile(item, hijos: hijos));
        if (!colapsado && gruposAbiertos.contains(item.clave)) {
          for (final hijo in hijos) {
            tiles.add(_navTile(hijo, indentado: true));
          }
        }
      } else {
        tiles.add(_navTile(item));
      }
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: colapsado ? _anchoContraido : _anchoExpandido,
      color: AppColors.navbar,
      clipBehavior: Clip.hardEdge,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: colapsado ? _anchoContraido : _anchoExpandido,
        maxWidth: colapsado ? _anchoContraido : _anchoExpandido,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cabecera(),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: _construirTiles(),
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            _pie(),
          ],
        ),
      ),
    );
  }

  // Cabecera: solo el botón para contraer/expandir (un ">" que gira).
  Widget _cabecera() {
    return Container(
      height: 68,
      alignment: colapsado ? Alignment.center : Alignment.centerRight,
      padding: EdgeInsets.only(right: colapsado ? 0 : 14),
      child: _botonToggle(),
    );
  }

  Widget _botonToggle() {
    return Tooltip(
      message: colapsado ? 'Expandir menú' : 'Contraer menú',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onToggle,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: AnimatedRotation(
              turns: colapsado ? 0 : 0.5,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: const Icon(
                LucideIcons.chevronRight,
                size: 22,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _opcionesUsuario() => const [
    PopupMenuItem(
      value: 'configuracion',
      child: Row(
        children: [
          Icon(LucideIcons.settings, size: 18),
          SizedBox(width: 12),
          Text('Configuración'),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'logout',
      child: Row(
        children: [
          Icon(LucideIcons.logOut, size: 18),
          SizedBox(width: 12),
          Text('Cerrar sesión'),
        ],
      ),
    ),
  ];

  void _onSeleccionarOpcionUsuario(String v) {
    if (v == 'configuracion') onConfiguracion();
    if (v == 'logout') onLogout();
  }

  // Pie del navbar: usuario + menú (Configuración/Cerrar sesión).
  Widget _pie() {
    final avatar = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(LucideIcons.user, size: 20, color: Colors.white),
    );
    if (colapsado) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
        child: PopupMenuButton<String>(
          tooltip: 'Opciones',
          padding: EdgeInsets.zero,
          offset: const Offset(48, 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          onSelected: _onSeleccionarOpcionUsuario,
          itemBuilder: (_) => _opcionesUsuario(),
          child: avatar,
        ),
      );
    }
    final menu = PopupMenuButton<String>(
      tooltip: 'Opciones',
      padding: EdgeInsets.zero,
      offset: const Offset(0, -110),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      onSelected: _onSeleccionarOpcionUsuario,
      itemBuilder: (_) => _opcionesUsuario(),
      child: const SizedBox(
        width: 28,
        height: 38,
        child: Icon(
          LucideIcons.ellipsisVertical,
          size: 20,
          color: Colors.white70,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  usuario.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  usuario.rol.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          menu,
        ],
      ),
    );
  }

  // `hijos` solo en un ítem grupo (ej. "Ventas"): despliega su lista.
  Widget _navTile(NavItem item, {List<NavItem>? hijos, bool indentado = false}) {
    final esGrupo = hijos != null;
    final abierto = esGrupo && gruposAbiertos.contains(item.clave);
    final activo = esGrupo
        ? hijos.any((h) => h.clave == seleccionado)
        : seleccionado == item.clave;
    final color = activo ? AppColors.primaryGreen : Colors.white70;
    final icono = Icon(item.icono, size: indentado ? 18 : 22, color: color);
    void onTap() {
      if (!esGrupo) {
        onSeleccionar(item.clave);
      } else if (colapsado) {
        // Colapsado: el ícono del grupo lleva directo a su primer hijo.
        if (hijos.isNotEmpty) onSeleccionar(hijos.first.clave);
      } else {
        onAlternarGrupo(item.clave);
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(indentado ? 20 : 12, 3, 12, 3),
      child: Tooltip(
        message: colapsado ? item.label : '',
        child: Material(
          color: activo
              ? AppColors.primaryGreen.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.button),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: colapsado ? 0 : 16,
                vertical: indentado ? 9 : 12,
              ),
              child: colapsado
                  ? Center(child: icono)
                  : Row(
                      children: [
                        icono,
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: indentado ? 13 : null,
                              fontWeight: activo
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (esGrupo)
                          AnimatedRotation(
                            turns: abierto ? 0.25 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              LucideIcons.chevronRight,
                              size: 16,
                              color: color,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_bijao.png',
      height: 36,
      fit: BoxFit.contain,
    );
  }
}
