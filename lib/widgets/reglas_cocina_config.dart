import 'dart:async';

import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../data/subcategorias_store.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../models/reglas_cocina.dart';
import '../models/subcategoria.dart';
import '../services/api_client.dart';
import '../services/catalog_service.dart';
import '../services/reglas_cocina_service.dart';
import '../theme/app_theme.dart';
import 'app_switch.dart';
import 'app_tag.dart';
import 'app_toast.dart';

// Configuración (administrador) de qué sale en la comanda de cocina para ahorrar papel:
// - Interruptor general para empaques / tápers.
// - Reglas por subcategoría (bebidas embotelladas, refrescos, segundos, etc.).
// - Excepciones por plato (ej. la subcategoría bebidas no se imprime, pero la
//   limonada o el aguaje sí porque se preparan en cocina).
// - Todo cambio se guarda y aplica inmediatamente en el servidor.
class ReglasCocinaConfig extends StatefulWidget {
  const ReglasCocinaConfig({super.key});

  @override
  State<ReglasCocinaConfig> createState() => _ReglasCocinaConfigState();
}

class _ReglasCocinaConfigState extends State<ReglasCocinaConfig> {
  ReglasCocina _guardadas = const ReglasCocina();
  ReglasCocina _reglas = const ReglasCocina();
  final Set<String> _abiertas = {};
  bool _cargando = true;
  bool _guardando = false;
  String _estadoSync = '';
  Timer? _debounceTimer;

  bool get _cambios => _reglas != _guardadas;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    // Asegurar datos maestros en memoria
    if (categorias.isEmpty) {
      await CatalogService.instance.cargarCategorias();
    }
    if (subcategorias.isEmpty) {
      await CatalogService.instance.cargarSubcategorias();
    }
    if (cartasNotifier.value.isEmpty) {
      await CatalogService.instance.cargarCarta();
    }

    final r = await ReglasCocinaService.instance.cargar();
    if (!mounted) return;
    setState(() {
      _guardadas = r ?? const ReglasCocina();
      _reglas = _guardadas.copia();
      _cargando = false;
    });
  }

  void _dispararAutoGuardado() {
    _debounceTimer?.cancel();
    setState(() => _estadoSync = 'Guardando cambios…');
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      await _guardarEnServidor(silencioso: true);
    });
  }

  Future<void> _guardarEnServidor({bool silencioso = false}) async {
    if (!mounted) return;
    setState(() => _guardando = true);
    try {
      await ReglasCocinaService.instance.guardar(_reglas);
      if (!mounted) return;
      setState(() {
        _guardadas = _reglas.copia();
        _guardando = false;
        _estadoSync = '✓ Cambios activos en cocina';
      });
      if (!silencioso) {
        showAppToast(
          context,
          'Listo: la cocina recibirá solo lo que marcaste.',
          type: ToastType.success,
          titulo: 'Impresión en cocina',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _estadoSync = 'Error al sincronizar';
      });
      if (!silencioso) {
        showAppToast(
          context,
          e is ApiException ? e.message : 'No se pudo guardar: $e',
          type: ToastType.error,
        );
      }
    }
  }

  // Interruptor general de tápers
  void _toggleTapers(bool v) {
    setState(() {
      _reglas = _reglas.copia(imprimeTapers: v);
    });
    _dispararAutoGuardado();
  }

  // Regla de una subcategoría: true = vuelve al valor por defecto (sí se imprime).
  void _subcategoria(String subcatId, bool imprime) {
    final c = _reglas.copia();
    final mapa = Map<String, bool>.from(c.subcategorias);
    if (imprime) {
      mapa.remove(subcatId);
    } else {
      mapa[subcatId] = false;
    }
    setState(() {
      _reglas = c.copia(subcategorias: mapa);
    });
    _dispararAutoGuardado();
  }

  // Excepción de un plato: null = sigue la regla de su subcategoría.
  void _plato(String platoId, bool? imprime) {
    final c = _reglas.copia();
    final mapa = Map<String, bool>.from(c.platos);
    if (imprime == null) {
      mapa.remove(platoId);
    } else {
      mapa[platoId] = imprime;
    }
    setState(() {
      _reglas = c.copia(platos: mapa);
    });
    _dispararAutoGuardado();
  }

  List<CartaItem> _platosDeSubcat(String subcatId) =>
      cartasNotifier.value
          .where(
            (p) =>
                p.subcategoriaIds.contains(subcatId) ||
                p.subcategoriaId == subcatId,
          )
          .toList()
        ..sort((a, b) => a.nombrePlato.compareTo(b.nombrePlato));

  List<CartaItem> _platosDeCatSinSubcat(String catId) =>
      cartasNotifier.value
          .where((p) => p.categoriaId == catId && p.subcategoriaIds.isEmpty)
          .toList()
        ..sort((a, b) => a.nombrePlato.compareTo(b.nombrePlato));

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppBreakpoints.esMobile(context) ? 16 : 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ahorro de papel: Impresión en cocina',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_estadoSync.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _estadoSync,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _estadoSync.contains('✓')
                              ? AppColors.primaryGreenDark
                              : (_estadoSync.contains('Error')
                                    ? Colors.red
                                    : Colors.orange.shade800),
                        ),
                      ),
                    ),
                  if (_cambios)
                    FilledButton.icon(
                      onPressed: _guardando ? null : () => _guardarEnServidor(),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(_guardando ? 'Guardando…' : 'Guardar todo'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    ),
                ],
              ),
              if (!AppBreakpoints.esMobile(context)) ...[
                const SizedBox(height: 6),
                Text(
                  'Configura qué elementos se imprimen en la comanda de cocina para ahorrar papel. '
                  'Puedes apagar subcategorías completas (como Bebidas o Helados) y marcar platos individuales '
                  'que sí deben salir porque se preparan en cocina (ej. limonada, aguaje). '
                  'Los cambios se aplican de inmediato en los próximos pedidos.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 18),

              // 1. Interruptor general para Tápers / Empaques
              _tarjetaTapers(),
              const SizedBox(height: 18),

              // 2. Encabezado de subcategorías
              Row(
                children: [
                  const Icon(
                    Icons.restaurant_menu,
                    size: 20,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Subcategorías y platos de la carta',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (categorias.isEmpty && subcategorias.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      'Aún no hay categorías ni subcategorías configuradas.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ),

              // Renderizar categorías y sus subcategorías
              for (final cat in categorias) ...[
                _bloqueCategoria(cat),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaTapers() {
    final imprime = _reglas.imprimeTapers;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      // Con poco ancho, el título (con su interruptor) va arriba y la
      // descripción debajo, a todo el ancho: en una columna angosta el texto
      // se partía en una palabra por línea.
      child: LayoutBuilder(
        builder: (context, c) {
          final angosto = c.maxWidth < 440;
          final icono = Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (imprime ? AppColors.primaryGreen : Colors.grey.shade300)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.takeout_dining_outlined,
              color: imprime
                  ? AppColors.primaryGreenDark
                  : Colors.grey.shade600,
              size: 26,
            ),
          );
          const titulo = Text(
            'Imprimir tápers en comanda de cocina',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          );
          final descripcion = Text(
            imprime
                ? 'Los empaques/tápers agregados se imprimirán en el ticket de cocina.'
                : 'Ahorro de papel activo: los ítems de tápers no se imprimirán en cocina.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          );
          final estado = Text(
            imprime ? 'Se imprime' : 'No se imprime',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: imprime
                  ? AppColors.primaryGreenDark
                  : Colors.grey.shade600,
            ),
          );
          final interruptor = AppSwitch(
            value: imprime,
            onChanged: _toggleTapers,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primaryGreen,
          );
          if (angosto) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    icono,
                    const SizedBox(width: 12),
                    const Expanded(child: titulo),
                    const SizedBox(width: 8),
                    interruptor,
                  ],
                ),
                const SizedBox(height: 10),
                descripcion,
                const SizedBox(height: 6),
                estado,
              ],
            );
          }
          return Row(
            children: [
              icono,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titulo, const SizedBox(height: 3), descripcion],
                ),
              ),
              const SizedBox(width: 12),
              estado,
              const SizedBox(width: 8),
              interruptor,
            ],
          );
        },
      ),
    );
  }

  Widget _bloqueCategoria(CategoriaComida cat) {
    final subs = subcategoriasDe(cat.id);
    final platosSinSub = _platosDeCatSinSubcat(cat.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Text(
                  cat.categoria.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${subs.length} subcategorías)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (subs.isEmpty && platosSinSub.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Sin subcategorías ni platos registrados.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          for (final s in subs) _filaSubcategoria(s),
          if (platosSinSub.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
              child: Text(
                'Platos sin subcategoría asignada:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            for (final p in platosSinSub)
              _filaPlato(p, subcatImprime: true, subcatId: null),
          ],
        ],
      ),
    );
  }

  Widget _filaSubcategoria(Subcategoria s) {
    final imprime = _reglas.imprimeSubcategoria(s.id);
    final platos = _platosDeSubcat(s.id);
    final abierta = _abiertas.contains(s.id);
    final excepciones = platos.where((p) => _reglas.platos.containsKey(p.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    if (!_abiertas.remove(s.id)) _abiertas.add(s.id);
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        AnimatedRotation(
                          turns: abierta ? 0.25 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            s.subcategoria,
                            softWrap: true,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${platos.length} platos'
                          '${excepciones.isNotEmpty ? ' · ${excepciones.length} excepción(es)' : ''}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                imprime ? 'Va a cocina' : 'No va a cocina',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: imprime
                      ? AppColors.primaryGreenDark
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              AppSwitch(
                value: imprime,
                onChanged: (v) => _subcategoria(s.id, v),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primaryGreen,
              ),
            ],
          ),
        ),
        if (abierta) ...[
          Container(
            color: Colors.grey.shade50.withValues(alpha: 0.6),
            child: Column(
              children: [
                Divider(height: 1, color: Colors.grey.shade200),
                if (platos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Esta subcategoría no tiene platos asignados en la carta.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                for (final p in platos)
                  _filaPlato(p, subcatImprime: imprime, subcatId: s.id),
              ],
            ),
          ),
        ],
        Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }

  Widget _filaPlato(
    CartaItem p, {
    required bool subcatImprime,
    required String? subcatId,
  }) {
    final excepcion = _reglas.platos[p.id];
    final sale = excepcion ?? subcatImprime;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 7, 12, 7),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 6,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160, maxWidth: 300),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                p.nombrePlato,
                softWrap: true,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sale ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
            ),
          ),
          AppTag(
            etiqueta: 'Como la subcategoría',
            activo: excepcion == null,
            onTap: () => _plato(p.id, null),
          ),
          const SizedBox(width: 4),
          AppTag(
            etiqueta: 'Sí sale a cocina',
            activo: excepcion == true,
            onTap: () => _plato(p.id, true),
          ),
          const SizedBox(width: 4),
          AppTag(
            etiqueta: 'No sale a cocina',
            activo: excepcion == false,
            onTap: () => _plato(p.id, false),
          ),
        ],
      ),
    );
  }
}
