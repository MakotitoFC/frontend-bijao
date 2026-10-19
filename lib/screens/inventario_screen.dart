import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/app_tag.dart';
import '../widgets/config_widgets.dart';
import '../widgets/inventario/pagina_catalogos.dart';
import '../widgets/inventario/pagina_compras.dart';
import '../widgets/inventario/pagina_productos.dart';
import '../widgets/inventario/pagina_resumen.dart';
import '../widgets/inventario/pagina_tapers.dart';
import '../widgets/inventario/pagina_utensilios.dart';
import '../widgets/submenu_lateral.dart';
import '../widgets/tabs_desplazables.dart';

// import '../widgets/tamanos_tab.dart'; // página Tamaños oculta (ver _paginas)

// Inventario (solo administrador). Mismo diseño que Configuración: un submenú
// con las páginas y, a la derecha, la página elegida. Cada cosa vive en un solo
// lugar:
//  - Resumen: cómo está el stock y qué reponer (solo consulta).
//  - Almacén: Productos, Tipos y unidades, Tápers.
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

  void _irA(String clave) => setState(() => _clave = clave);

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
      clave: 'productos',
      etiqueta: 'Productos',
      seccion: 'Almacén',
      contenido: () => const PaginaProductos(),
    ),
    (
      clave: 'catalogos',
      etiqueta: 'Tipos y unidades',
      seccion: 'Almacén',
      contenido: () => const PaginaCatalogos(),
    ),
    (
      clave: 'tapers',
      etiqueta: 'Tápers',
      seccion: 'Almacén',
      contenido: () => const PaginaTapers(),
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
  ];

  Widget _botonActualizar() {
    return Tooltip(
      message: 'Actualizar datos',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() => _recarga++),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(
            LucideIcons.refreshCw,
            size: 16,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginas = _paginas;
    final actual =
        paginas.where((p) => p.clave == _clave).firstOrNull ?? paginas.first;
    final contenido = KeyedSubtree(
      key: ValueKey('${actual.clave}-$_recarga'),
      child: actual.contenido(),
    );

    // Celular: no hay lugar para dos columnas; las páginas van en pestañas.
    if (AppBreakpoints.esMobile(context)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TabsDesplazables(
                      child: Row(
                        children: [
                          for (final p in paginas)
                            AppTag(
                              etiqueta: p.etiqueta,
                              activo: p.clave == actual.clave,
                              onTap: () => _irA(p.clave),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _botonActualizar(),
                ],
              ),
            ),
            Expanded(child: contenido),
          ],
        ),
      );
    }

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
      body: Row(
        children: [
          SubmenuLateral(
            entradas: entradas,
            seleccionada: actual.clave,
            onSeleccionar: _irA,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: EncabezadoRuta(
                          ruta: ['Inventario', actual.etiqueta],
                        ),
                      ),
                      _botonActualizar(),
                    ],
                  ),
                ),
                Expanded(child: contenido),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
