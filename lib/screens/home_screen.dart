import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../data/nav_items.dart';
import '../models/app_role.dart';
import '../models/mock_user.dart';
import '../models/nav_item.dart';
import '../models/sede.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'carta_screen.dart';
import 'login_screen.dart';
import 'mesas_screen.dart';

// Shell de escritorio: navbar lateral flotante/redondeado (ícono de hojas +
// ítems) + header global (campana + usuario, con menú de configuración/salir)
// + área de contenido que cambia según el ítem seleccionado (sin apilar
// pantallas). Ver nav_items.dart para el mapeo de ítems.
class HomeScreen extends StatefulWidget {
  final Sede sede;
  final MockUser usuario;

  const HomeScreen({super.key, required this.sede, required this.usuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _colapsado = true;
  String _seleccionado = 'inicio';

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _contenidoDe(String clave) {
    switch (clave) {
      case 'pedidos':
        return const MesasScreen();
      case 'productos':
        return CartaScreen(
          esAdmin: widget.usuario.rol == AppRole.administrador,
        );
      // Inicio, Cocina, Pagos, Caja, Informes y Configuración comparten el
      // mismo placeholder de "página en construcción" mientras se desarrolla
      // cada módulo; cada una muestra su propio nombre en el mensaje.
      case 'inicio':
        return _InicioContent(
          usuario: widget.usuario,
          sede: widget.sede,
          nombreVista: 'Inicio',
        );
      case 'cocina':
        return _InicioContent(
          usuario: widget.usuario,
          sede: widget.sede,
          nombreVista: 'Cocina',
        );
      case 'pagos':
        return _InicioContent(
          usuario: widget.usuario,
          sede: widget.sede,
          nombreVista: 'Pagos',
        );
      case 'caja':
        return _InicioContent(
          usuario: widget.usuario,
          sede: widget.sede,
          nombreVista: 'Caja',
        );
      case 'informes':
        return _InicioContent(
          usuario: widget.usuario,
          sede: widget.sede,
          nombreVista: 'Informes',
        );
      case 'configuracion':
        return _InicioContent(
          usuario: widget.usuario,
          sede: widget.sede,
          nombreVista: 'Configuración',
        );
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
      // Mobile: sin navbar lateral. El logo vive en el mismo header que la
      // campana/usuario y la navegación pasa a una barra inferior con hasta
      // 3 vistas + "Más" (ver _BottomNav).
      final principales = items.length <= 4 ? items : items.take(3).toList();
      final restantes = items.length <= 4
          ? const <NavItem>[]
          : items.skip(3).toList();
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
      body: Stack(
        children: [
          // El contenido ocupa TODO el ancho: el navbar ya no reserva una
          // columna propia, flota encima como overlay (ver _Sidebar).
          Column(
            children: [
              _GlobalHeader(
                usuario: widget.usuario,
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
          _Sidebar(
            colapsado: _colapsado,
            items: items,
            seleccionado: _seleccionado,
            onToggle: () => setState(() => _colapsado = !_colapsado),
            onSeleccionar: (clave) => setState(() {
              _seleccionado = clave;
              _colapsado = true;
            }),
          ),
        ],
      ),
    );
  }
}

// Header global (mismo en todas las pantallas del shell): tarjeta flotante y
// redondeada que contiene la campana y el usuario (con menú de
// Configuración/Cerrar sesión). Reemplaza el AppBar propio que tenía cada
// pantalla. En escritorio el logo vive en el navbar lateral; en mobile
// (mostrarLogo) se fusiona en este mismo contenedor, ya que el navbar pasa a
// ser la barra inferior (ver _BottomNav) y el logo deja de ser un control de
// navegación, solo la marca.
class _GlobalHeader extends StatelessWidget {
  final MockUser usuario;
  final bool mostrarLogo;
  final VoidCallback onConfiguracion;
  final VoidCallback onLogout;

  const _GlobalHeader({
    required this.usuario,
    this.mostrarLogo = false,
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
    return Padding(
      padding: EdgeInsets.fromLTRB(mostrarLogo ? 16 : 24, 12, 16, 12),
      child: Row(
        children: [
          if (mostrarLogo) const _Logo(),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedBellDot,
                  size: 22,
                  color: Colors.black87,
                ),
                const SizedBox(width: 20),
                PopupMenuButton<String>(
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
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedSettings01,
                            size: 18,
                            color: Colors.black87,
                          ),
                          SizedBox(width: 12),
                          Text('Configuración'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: const [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedLogout01,
                            size: 18,
                            color: Colors.black87,
                          ),
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
                      if (!mostrarLogo) ...[
                        const SizedBox(width: 10),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              usuario.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              usuario.rol.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: Colors.grey.shade500,
                      ),
                    ],
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

// Navbar inferior (mobile): hasta 3 vistas principales + una 4ta pestaña
// "Más" (solo si sobran vistas) que abre una hoja inferior con el resto.
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

  bool get _masActivo => restantes.any((i) => i.clave == seleccionado);

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
    required List<List<dynamic>> icono,
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
            HugeIcon(icon: icono, size: 22, color: color),
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
            for (final item in items)
              ListTile(
                leading: HugeIcon(
                  icon: item.icono,
                  size: 22,
                  color: seleccionado == item.clave
                      ? AppColors.primaryGreen
                      : Colors.black87,
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: seleccionado == item.clave
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: seleccionado == item.clave
                        ? AppColors.primaryGreen
                        : Colors.black87,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(item.clave),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// Placeholder de "página en construcción" compartido por todas las vistas
// que aún no tienen contenido real (Inicio, Cocina, Pagos, Caja, Informes,
// Configuración); el mensaje usa el nombre de cada vista en vez de siempre
// decir "dashboard".
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
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedConstruction,
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

// Navbar lateral flotante/redondeado. Por defecto solo se ve el logo y el
// contenedor se ajusta a su tamaño; el ícono de expandir/contraer solo
// aparece al pasar el cursor por encima (o si la lista ya está expandida).
// Solo la lista de ítems de navegación aparece/desaparece con una
// transición suave (AnimatedCrossFade). Sin usuario/logout: eso vive en el
// menú del header global.
class _Sidebar extends StatefulWidget {
  final bool colapsado;
  final List<NavItem> items;
  final String seleccionado;
  final VoidCallback onToggle;
  final ValueChanged<String> onSeleccionar;

  const _Sidebar({
    required this.colapsado,
    required this.items,
    required this.seleccionado,
    required this.onToggle,
    required this.onSeleccionar,
  });

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final mostrarChevron = _hover || !widget.colapsado;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.topLeft,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: mostrarChevron ? 200 : 96,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  // Mismo alto que la tarjeta de campana+usuario del header
                  // global (10 de padding vertical + 36 de contenido = 56).
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: mostrarChevron
                      ? Row(
                          children: [
                            const SizedBox(width: 28),
                            const Expanded(child: Center(child: _Logo())),
                            _botonToggle(),
                          ],
                        )
                      : const Center(child: _Logo()),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 280),
                  sizeCurve: Curves.easeInOut,
                  firstCurve: Curves.easeInOut,
                  secondCurve: Curves.easeInOut,
                  crossFadeState: widget.colapsado
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: widget.items
                              .map((item) => _navTile(item))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _botonToggle() {
    return SizedBox(
      width: 28,
      height: 28,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onToggle,
          child: Center(
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              turns: widget.colapsado ? 0 : 0.5,
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navTile(NavItem item) {
    final activo = widget.seleccionado == item.clave;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: activo
            ? AppColors.primaryGreen.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.button),
          onTap: () => widget.onSeleccionar(item.clave),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                HugeIcon(
                  icon: item.icono,
                  size: 22,
                  color: activo ? AppColors.primaryGreen : Colors.black87,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: activo ? AppColors.primaryGreen : Colors.black87,
                      fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
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
