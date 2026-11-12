import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import 'package:lucide_flutter/lucide_flutter.dart';

import '../widgets/config_widgets.dart';
import '../widgets/indice_subvistas.dart';
import '../widgets/inventario/pagina_catalogos.dart';
import '../widgets/inventario/pagina_movimientos.dart';
import '../widgets/inventario/pagina_productos.dart';
import '../widgets/inventario/pagina_resumen.dart';
import '../widgets/inventario/pagina_anulaciones.dart';
import '../widgets/inventario/pagina_reportes.dart';
import '../widgets/submenu_lateral.dart';
import '../widgets/tabs_texto.dart';

// import '../widgets/tamanos_tab.dart'; // página Tamaños oculta (ver _paginas)

// Inventario (solo administrador). Mismo diseño que Configuración: un submenú
// con las páginas y, a la derecha, la página elegida. Cada cosa vive en un solo
// lugar:
//  - Resumen: cómo está el stock y qué reponer (solo consulta).
//  - Almacén: Productos, Tipos y unidades y Tápers, juntos en una sola vista.
//  - Carta: Tamaños de los platos.
//  - Movimientos: compras, mermas y ajustes, y roturas en una sola vista, con
//    filtros.
//  - Anulaciones: consulta aparte; no mueve el stock.
//  - Reportes: lo que entró y salió cada día y cómo quedó el stock; se descarga
//    en CSV.
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  String _clave = 'resumen';
  // Celular: subvista abierta desde el índice (null = el índice).
  String? _abierta;
  // Sube cada vez que se pide actualizar: las páginas se vuelven a montar y
  // leen los datos otra vez.
  int _recarga = 0;

  // Subvista de Almacén que se ve: 'productos' | 'catalogos' | 'tapers'.
  String _subAlmacen = 'catalogos';

  static const _subvistasAlmacen = {'productos', 'catalogos', 'tapers'};

  // Filtro de Movimientos: 'todos' | 'compras' | 'ajustes' | 'roturas'.
  String _filtroMovimientos = 'todos';

  // Las tres subvistas de Almacén viven en una sola página, y Compras y
  // Utensilios rotos son filtros de la página Movimientos.
  void _irA(String clave) => setState(() {
    if (_subvistasAlmacen.contains(clave)) {
      // Los tápers viven ahora en Productos.
      _subAlmacen = clave == 'tapers' ? 'productos' : clave;
      _clave = 'almacen';
    } else if (clave == 'compras' || clave == 'utensilios') {
      _filtroMovimientos = clave == 'compras' ? 'compras' : 'roturas';
      _clave = 'movimientos';
    } else {
      _clave = clave;
    }
    _abierta = _clave;
  });

  // Icono de cada subvista en el índice de celular.
  static const _iconos = {
    'resumen': LucideIcons.layoutDashboard,
    'almacen': LucideIcons.warehouse,
    'movimientos': LucideIcons.arrowLeftRight,
    'anulaciones': LucideIcons.ban,
    'reportes': LucideIcons.fileText,
  };

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
      clave: 'resumen',
      etiqueta: 'Resumen',
      seccion: null,
      contenido: () => PaginaResumen(irA: _irA),
    ),
    (
      clave: 'almacen',
      etiqueta: 'Almacén',
      seccion: null,
      contenido: () => _PaginaAlmacen(
        sub: _subAlmacen,
        onSub: (s) => setState(() => _subAlmacen = s),
      ),
    ),
    // Página "Tamaños" oculta por ahora: los tamaños se crean y editan desde la
    // Carta (interruptor "Tiene tamaños" y botón "+ Tamaño"). Para volver a
    // mostrarla, descomentar esto y el import de `tamanos_tab.dart`.
    // (
    //   clave: 'tamanos',
    //   etiqueta: 'Tamaños',
    //   seccion: 'Carta',
    //   contenido: () => const TamanosTab(),
    // ),
    (
      clave: 'movimientos',
      etiqueta: 'Movimientos',
      seccion: null,
      contenido: () => PaginaMovimientos(
        filtro: _filtroMovimientos,
        onFiltro: (f) => setState(() => _filtroMovimientos = f),
      ),
    ),
    (
      clave: 'anulaciones',
      etiqueta: 'Anulaciones',
      seccion: null,
      contenido: () => const PaginaAnulaciones(),
    ),
    (
      clave: 'reportes',
      etiqueta: 'Reportes',
      seccion: null,
      contenido: () => const PaginaReportes(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final paginas = _paginas;
    final actual =
        paginas.where((p) => p.clave == _clave).firstOrNull ?? paginas.first;
    final contenido = KeyedSubtree(
      key: ValueKey('${actual.clave}-$_recarga'),
      child: actual.contenido(),
    );

    final entradas = <SubmenuEntrada>[];
    String? ultimaSeccion;
    for (final p in paginas) {
      if (p.seccion != null && p.seccion != ultimaSeccion) {
        entradas.add(SubmenuEntrada.seccion(p.seccion!));
      }
      ultimaSeccion = p.seccion;
      entradas.add(SubmenuEntrada.item(p.clave, p.etiqueta));
    }

    // Celular: un índice con las subvistas (sin la barra oscura); cada fila abre
    // la suya a pantalla completa.
    if (AppBreakpoints.esMobile(context)) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: IndiceSubvistas(
          titulo: 'Inventario',
          descripcion: 'Stock, compras y registros del almacén.',
          abierta: _abierta,
          onAbrir: (c) => c == null ? setState(() => _abierta = null) : _irA(c),
          subvistas: [
            for (final p in paginas)
              (
                clave: p.clave,
                etiqueta: p.etiqueta,
                icono: _iconos[p.clave] ?? LucideIcons.circle,
                grupo: p.seccion ?? 'Stock',
                contenido: (_) => KeyedSubtree(
                  key: ValueKey('${p.clave}-$_recarga'),
                  child: p.contenido(),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      // Las subvistas van en una barra horizontal bajo el header, como en
      // Ventas.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SubmenuSuperior(
            entradas: entradas,
            seleccionada: actual.clave,
            onSeleccionar: _irA,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
            child: Row(
              children: [
                Expanded(
                  child: EncabezadoRuta(ruta: ['Inventario', actual.etiqueta]),
                ),
              ],
            ),
          ),
          Expanded(child: contenido),
        ],
      ),
    );
  }
}

// Almacén: Productos, Tipos y unidades y Tápers en una sola vista, con las tres
// subvistas como pestañas arriba.
class _PaginaAlmacen extends StatelessWidget {
  final String sub;
  final ValueChanged<String> onSub;

  const _PaginaAlmacen({required this.sub, required this.onSub});

  @override
  Widget build(BuildContext context) {
    const subvistas = [
      ('catalogos', 'Tipos y unidades'),
      ('productos', 'Productos'),
    ];
    final margen = AppBreakpoints.esMobile(context) ? 16.0 : 24.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(margen, 8, margen, 4),
          child: TabsTexto(
            tabs: [
              for (final s in subvistas)
                TabTexto(
                  etiqueta: s.$2,
                  activa: s.$1 == sub,
                  onTap: () => onSub(s.$1),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (sub) {
            'catalogos' => const PaginaCatalogos(),
            _ => const PaginaProductos(),
          },
        ),
      ],
    );
  }
}
