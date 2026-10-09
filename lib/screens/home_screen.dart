import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/nav_items.dart';
import '../models/categoria_comida.dart';
import '../models/app_role.dart';
import '../models/usuario.dart';
import '../models/nav_item.dart';
import '../models/sede.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/deferred_loader.dart';
import 'carta_screen.dart' deferred as carta;
import 'cocina_screen.dart' deferred as cocina;
import 'configuracion_screen.dart' deferred as configuracion;
import 'inventario_screen.dart' deferred as inventario;
import 'login_screen.dart';
import 'mesas_screen.dart';
import 'pagos_screen.dart' deferred as pagos;
import 'pedidos_screen.dart';
import 'reportes_screen.dart' deferred as reportes;

// Shell principal: navbar lateral + header global + contenido según la
// vista elegida. Ver nav_items.dart para las vistas disponibles.
class HomeScreen extends StatefulWidget {
  final Sede sede;
  final Usuario usuario;

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
  void initState() {
    super.initState();
    CatalogService.instance.cargarCatalogos();
  }

  @override
  void dispose() {
    _categoriaProductos.dispose();
    _busquedaProductos.dispose();
    super.dispose();
  }

  // Título y descripción breve de cada vista, que muestra el header global.
  static const _titulos = <String, ({String titulo, String descripcion})>{
    'inicio': (titulo: 'Inicio', descripcion: 'Resumen de tu restaurante'),
    'mesas': (
      titulo: 'Mesas',
      descripcion:
          'Visualiza salas, mesas, ocupación y administra el plano del local',
    ),
    'pedidos': (
      titulo: 'Pedidos',
      descripcion: 'Toma pedidos, elige mesa o delivery y sigue la cola',
    ),
    'productos': (
      titulo: 'Carta',
      descripcion: 'Administra tu carta de platos, precios y categorías',
    ),
    'cocina': (
      titulo: 'Cocina',
      descripcion: 'Comandas pendientes por preparar',
    ),
    'historial_pedidos': (
      titulo: 'Historial de pedidos',
      descripcion: 'Pedidos y su estado de pago',
    ),
    'caja': (titulo: 'Caja', descripcion: 'Caja actual y cierres de caja'),
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

  void _logout(BuildContext context) async {
    await AuthService.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _contenidoDe(String clave) {
    switch (clave) {
      case 'mesas':
        return MesasScreen(usuario: widget.usuario);
      case 'pedidos':
        return PedidosScreen(usuario: widget.usuario);
      case 'productos':
        return DeferredWidget(
          loader: carta.loadLibrary,
          builder: () => carta.CartaScreen(
            esAdmin: widget.usuario.rol == AppRole.administrador,
            seleccion: _categoriaProductos,
            busqueda: _busquedaProductos,
            cabeceraPropia: true,
          ),
        );
      // Vistas aún sin desarrollar: comparten el mismo placeholder.
      case 'inicio':
        return _InicioContent(
          usuario: widget.usuario,
          sede: widget.sede,
          nombreVista: 'Inicio',
        );
      case 'cocina':
        return DeferredWidget(
          loader: cocina.loadLibrary,
          builder: () => cocina.CocinaScreen(),
        );
      case 'historial_pedidos':
        return DeferredWidget(
          loader: pagos.loadLibrary,
          builder: () => pagos.HistorialPedidosScreen(usuario: widget.usuario),
        );
      case 'caja':
        return DeferredWidget(
          loader: pagos.loadLibrary,
          builder: () => pagos.CajaScreen(usuario: widget.usuario),
        );
      case 'reportes':
        return DeferredWidget(
          loader: reportes.loadLibrary,
          builder: () => reportes.ReportesScreen(),
        );
      case 'finanzas':
        return _InicioContent(
          usuario: widget.usuario,
          sede: widget.sede,
          nombreVista: 'Finanzas',
        );
      case 'inventario':
        return DeferredWidget(
          loader: inventario.loadLibrary,
          builder: () => inventario.InventarioScreen(),
        );
      case 'configuracion':
        return DeferredWidget(
          loader: configuracion.loadLibrary,
          builder: () => configuracion.ConfiguracionScreen(usuario: widget.usuario),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = navItems.where((i) => i.tieneAcceso(widget.usuario)).toList();

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

// Header global: campana + usuario (menú de Cerrar sesión).
class _GlobalHeader extends StatelessWidget {
  final Usuario usuario;
  final bool mostrarLogo;
  final bool barraFija;
  final String? titulo;
  final String? descripcion;
  final VoidCallback onLogout;

  const _GlobalHeader({
    required this.usuario,
    this.mostrarLogo = false,
    this.barraFija = false,
    this.titulo,
    this.descripcion,
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

// Avatar del usuario con su menú (Cerrar sesión).
class _MenuUsuario extends StatelessWidget {
  final Usuario usuario;
  final bool mostrarNombre;
  final bool mostrarFlecha;
  final VoidCallback onLogout;

  const _MenuUsuario({
    required this.usuario,
    required this.mostrarNombre,
    this.mostrarFlecha = false,
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
        if (value == 'logout') onLogout();
      },
      itemBuilder: (context) => [
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
    (i) =>
        i.clave == seleccionado || i.hijos.any((h) => h.clave == seleccionado),
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
                for (final hijo in item.hijos)
                  _fila(context, hijo, indentado: true),
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
  final Usuario usuario;
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
  final Usuario usuario;
  final VoidCallback onLogout;
  final VoidCallback onToggle;
  final ValueChanged<String> onSeleccionar;
  final ValueChanged<String> onAlternarGrupo;

  const _Sidebar({
    required this.usuario,
    required this.onLogout,
    required this.colapsado,
    required this.items,
    required this.seleccionado,
    required this.gruposAbiertos,
    required this.onToggle,
    required this.onSeleccionar,
    required this.onAlternarGrupo,
  });

  static const double _anchoExpandido = 256;
  static const double _anchoContraido = 68;

  List<NavItem> _hijosPermitidos(NavItem item) =>
      item.hijos.where((h) => h.tieneAcceso(usuario)).toList();

  static const _claveConfiguracion = 'configuracion';

  List<Widget> _construirTiles() {
    final tiles = <Widget>[];
    for (final item in items) {
      if (item.clave == _claveConfiguracion) continue;
      if (item.esGrupo) {
        final hijos = _hijosPermitidos(item);
        tiles.add(_navTile(item, hijos: hijos));
        if (!colapsado && gruposAbiertos.contains(item.clave)) {
          for (final hijo in hijos) {
            tiles.add(
              KeyedSubtree(
                key: _claveNav(hijo.clave),
                child: _navTile(hijo),
              ),
            );
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      width: colapsado ? _anchoContraido : _anchoExpandido,
      color: AppColors.navbar,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: const Interval(0.3, 1, curve: Curves.easeOut),
        switchOutCurve: const Interval(0.3, 1, curve: Curves.easeIn),
        layoutBuilder: (actual, anteriores) => Stack(
          fit: StackFit.expand,
          alignment: Alignment.topLeft,
          children: [...anteriores, ?actual],
        ),
        child: OverflowBox(
          key: ValueKey(colapsado),
          alignment: Alignment.topLeft,
          minWidth: colapsado ? _anchoContraido : _anchoExpandido,
          maxWidth: colapsado ? _anchoContraido : _anchoExpandido,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cabecera(),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: _ListaNav(
                  gruposAbiertos: Set.of(gruposAbiertos),
                  ultimoHijoPorGrupo: {
                    for (final i in items)
                      if (i.esGrupo && _hijosPermitidos(i).isNotEmpty)
                        i.clave: _hijosPermitidos(i).last.clave,
                  },
                  children: _construirTiles(),
                ),
              ),
              _seccionCuenta(),
              const Divider(height: 1, color: Colors.white12),
              _pie(),
            ],
          ),
        ),
      ),
    );
  }

  static const double _altoCabecera = 80;

  // Cabecera. Expandido: logo centrado y botón "<" para contraer. Contraído:
  // solo la hoja del logo, que al tocarla expande el menú.
  Widget _cabecera() {
    if (colapsado) {
      return SizedBox(
        height: _altoCabecera,
        child: Center(
          child: Tooltip(
            message: 'Expandir menú',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: _hojaLogo(),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: _altoCabecera,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // La imagen trae margen transparente: se muestra más grande y se
          // recorta al área visible.
          ClipRect(
            child: SizedBox(
              width: 120,
              height: 56,
              child: OverflowBox(
                maxWidth: 124,
                maxHeight: 82,
                child: Image.asset(
                  'assets/images/el_bijao_blanco.png',
                  height: 82,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(right: 8, child: _botonToggle()),
        ],
      ),
    );
  }

  // Ícono de la hoja (el mismo del tab del navegador).
  Widget _hojaLogo() {
    return Image.asset(
      'assets/images/icono_bijao.png',
      width: 40,
      height: 40,
      fit: BoxFit.contain,
    );
  }

  Widget _botonToggle() {
    return Tooltip(
      message: 'Contraer menú',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onToggle,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: AnimatedRotation(
              turns: 0.5,
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

  // Sección CUENTA (arriba del separador): Configuración y Cerrar sesión.
  Widget _seccionCuenta() {
    final configuracion = items
        .where((i) => i.clave == _claveConfiguracion)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (colapsado)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Divider(height: 1, color: Colors.white12),
            )
          else
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 6, 16, 6),
              child: Text(
                'CUENTA',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ),
          if (configuracion != null) _navTile(configuracion),
          _tile(
            icono: LucideIcons.logOut,
            etiqueta: 'Cerrar sesión',
            activo: false,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }

  // Pie del navbar: avatar circular, nombre y rol del usuario.
  Widget _pie() {
    final avatar = Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: AppColors.primaryGreen,
        shape: BoxShape.circle,
      ),
      child: const Icon(LucideIcons.user, size: 20, color: Colors.white),
    );
    if (colapsado) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
        child: Center(
          child: Tooltip(
            message: '${usuario.nombre} · ${usuario.rol.label}',
            child: avatar,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
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
        ],
      ),
    );
  }

  // Ítem del menú. En un módulo contenedor (`esGrupo`) la flecha va al inicio,
  // antes del nombre; todos los ítems reservan ese espacio para que los íconos
  // queden alineados. Módulos y submódulos tienen el mismo tamaño.
  Widget _tile({
    required IconData icono,
    required String etiqueta,
    required bool activo,
    required VoidCallback onTap,
    bool esGrupo = false,
    bool abierto = false,
  }) {
    final color = activo ? AppColors.primaryGreen : Colors.white70;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
      child: Tooltip(
        message: colapsado ? etiqueta : '',
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
                horizontal: colapsado ? 0 : 10,
                vertical: 12,
              ),
              child: colapsado
                  ? Center(child: Icon(icono, size: 24, color: color))
                  : Row(
                      children: [
                        SizedBox(
                          width: 18,
                          child: esGrupo
                              ? AnimatedRotation(
                                  turns: abierto ? 0.25 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    LucideIcons.chevronRight,
                                    size: 16,
                                    color: color,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Icon(icono, size: 24, color: color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            etiqueta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontWeight: activo
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
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

  // `hijos` solo en un ítem grupo (ej. "Ventas"): despliega su lista.
  Widget _navTile(NavItem item, {List<NavItem>? hijos}) {
    final esGrupo = hijos != null;
    final activo = esGrupo
        ? hijos.any((h) => h.clave == seleccionado)
        : seleccionado == item.clave;
    return _tile(
      icono: item.icono,
      etiqueta: item.label,
      activo: activo,
      esGrupo: esGrupo,
      abierto: esGrupo && gruposAbiertos.contains(item.clave),
      onTap: () {
        if (!esGrupo) {
          onSeleccionar(item.clave);
        } else if (colapsado) {
          // Colapsado: el ícono del grupo lleva directo a su primer hijo.
          if (hijos.isNotEmpty) onSeleccionar(hijos.first.clave);
        } else {
          onAlternarGrupo(item.clave);
        }
      },
    );
  }
}

// Claves globales de los submódulos, para poder desplazar la lista hasta ellos.
final _clavesNav = <String, GlobalKey>{};
GlobalKey _claveNav(String clave) =>
    _clavesNav.putIfAbsent(clave, () => GlobalKey(debugLabel: 'nav-$clave'));

// Lista de módulos del menú. Al expandir un módulo contenedor se desplaza sola
// lo justo para que se vean sus submódulos y el usuario note que se abrió.
class _ListaNav extends StatefulWidget {
  final List<Widget> children;
  final Set<String> gruposAbiertos;
  // Clave del último submódulo de cada módulo contenedor.
  final Map<String, String> ultimoHijoPorGrupo;

  const _ListaNav({
    required this.children,
    required this.gruposAbiertos,
    required this.ultimoHijoPorGrupo,
  });

  @override
  State<_ListaNav> createState() => _ListaNavState();
}

class _ListaNavState extends State<_ListaNav> {
  @override
  void didUpdateWidget(covariant _ListaNav old) {
    super.didUpdateWidget(old);
    final nuevos = widget.gruposAbiertos.difference(old.gruposAbiertos);
    if (nuevos.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final grupo in nuevos) {
        final ultimo = widget.ultimoHijoPorGrupo[grupo];
        final contexto = ultimo == null
            ? null
            : _claveNav(ultimo).currentContext;
        if (contexto != null && contexto.mounted) {
          Scrollable.ensureVisible(
            contexto,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(children: widget.children),
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
