import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/boton_actualizar.dart';
import '../widgets/config_widgets.dart';
import '../widgets/inventario/pagina_catalogos.dart';
import '../widgets/inventario/pagina_compras.dart';
import '../widgets/inventario/pagina_productos.dart';
import '../widgets/inventario/pagina_resumen.dart';
import '../widgets/inventario/pagina_tapers.dart';
import '../widgets/inventario/pagina_utensilios.dart';
import '../widgets/inventario/pagina_anulaciones.dart';
import '../widgets/submenu_lateral.dart';
import '../widgets/tabs_texto.dart';

// import '../widgets/tamanos_tab.dart'; // página Tamaños oculta (ver _paginas)

// Inventario (solo administrador). Mismo diseño que Configuración: un submenú
// con las páginas y, a la derecha, la página elegida. Cada cosa vive en un solo
// lugar:
//  - Resumen: cómo está el stock y qué reponer (solo consulta).
//  - Almacén: Productos, Tipos y unidades y Tápers, juntos en una sola vista.
//  - Carta: Tamaños de los platos.
//  - Movimientos: Compras y Utensilios rotos.
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  String _clave = 'resumen';
  // Sube cada vez que se pide actualizar: las páginas se vuelven a montar y
  // leen los datos otra vez.
  int _recarga = 0;

  // Subvista de Almacén que se ve: 'productos' | 'catalogos' | 'tapers'.
  String _subAlmacen = 'catalogos';

  static const _subvistasAlmacen = {'productos', 'catalogos', 'tapers'};

  // Las tres subvistas de Almacén viven en una sola página.
  void _irA(String clave) => setState(() {
    if (_subvistasAlmacen.contains(clave)) {
      _subAlmacen = clave;
      _clave = 'almacen';
    } else {
      _clave = clave;
    }
  });

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
      clave: 'compras',
      etiqueta: 'Compras',
      seccion: 'Movimientos',
      contenido: () => const PaginaCompras(),
    ),
    (
      clave: 'utensilios',
      etiqueta: 'Utensilios rotos',
      seccion: 'Movimientos',
      contenido: () => const PaginaUtensilios(),
    ),
    (
      clave: 'anulaciones',
      etiqueta: 'Anulaciones',
      seccion: 'Movimientos',
      contenido: () => const PaginaAnulaciones(),
    ),
  ];

  Widget _botonActualizar() =>
      BotonActualizar(onTap: () => setState(() => _recarga++));

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

    // Celular: no hay lugar para dos columnas; las subvistas van en la barra
    // oscura de arriba.
    if (AppBreakpoints.esMobile(context)) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SubmenuSuperior(
              entradas: entradas,
              seleccionada: actual.clave,
              onSeleccionar: _irA,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: _botonActualizar(),
              ),
            ),
            Expanded(child: contenido),
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
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 4),
            child: Row(
              children: [
                Expanded(
                  child: EncabezadoRuta(ruta: ['Inventario', actual.etiqueta]),
                ),
                _botonActualizar(),
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
      ('tapers', 'Tápers'),
    ];
    final margen = AppBreakpoints.esMobile(context) ? 16.0 : 32.0;
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
            'tapers' => const PaginaTapers(),
            _ => const PaginaProductos(),
          },
        ),
      ],
    );
  }
}
