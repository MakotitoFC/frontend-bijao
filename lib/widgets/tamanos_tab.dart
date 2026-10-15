import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cartas_store.dart';
import '../data/variantes_store.dart';
import '../models/carta_item.dart';
import '../models/carta_variante.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'app_toast.dart';
import 'inventario/inventario_comun.dart';
import 'tamano_form_dialog.dart';

// Inventario > Tamaños: aquí se registran los tamaños con precio propio de los
// platos que se venden por tamaño (por ejemplo, el pescado). En el formulario del
// plato solo se muestran.
class TamanosTab extends StatefulWidget {
  const TamanosTab({super.key});

  @override
  State<TamanosTab> createState() => _TamanosTabState();
}

class _TamanosTabState extends State<TamanosTab> {
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    await Future.wait([
      CatalogService.instance.cargarVariantes(),
      CatalogService.instance.cargarCarta(),
    ]);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _abrirFormulario({
    CartaVariante? tamano,
    String? cartaId,
  }) async {
    await showBlurDialog<CartaVariante>(
      context: context,
      builder: (_) => TamanoFormDialog(tamano: tamano, cartaIdInicial: cartaId),
    );
    if (mounted) setState(() {});
  }

  Future<void> _eliminar(CartaVariante t) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar tamaño',
      mensaje: '¿Eliminar "${t.nombre}"?',
    );
    if (!ok) return;
    try {
      await CatalogService.instance.eliminarVariante(t.id);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      final texto = e.toString();
      final enUso =
          texto.contains('llave for') || texto.contains('foreign key');
      showAppToast(
        context,
        enUso
            ? 'No se puede eliminar: el tamaño ya se usó en pedidos. '
                  'Márcalo como inactivo.'
            : 'Error al eliminar: $texto',
        type: ToastType.error,
      );
    }
  }

  String _pesos(CartaVariante t) {
    String n(double v) => v.toString();
    if (t.pesoMinKg != null && t.pesoMaxKg != null) {
      return '${n(t.pesoMinKg!)} – ${n(t.pesoMaxKg!)} kg';
    }
    if (t.pesoMinKg != null) return 'desde ${n(t.pesoMinKg!)} kg';
    if (t.pesoMaxKg != null) return 'hasta ${n(t.pesoMaxKg!)} kg';
    return 'Sin rango de peso';
  }

  Widget _fila(CartaVariante t) {
    return FilaInventario(
      titulo: tituloConEtiquetas(t.nombre, [
        if (!t.estado) const EtiquetaFila('Inactivo'),
      ], activo: t.estado),
      detalle:
          '${_pesos(t)} · cliente S/ ${t.precioCliente.toStringAsFixed(2)} · '
          'personal S/ ${t.precioPersonal.toStringAsFixed(2)}',
      controles: [
        IconButton(
          tooltip: 'Editar',
          onPressed: () => _abrirFormulario(tamano: t),
          icon: Icon(LucideIcons.pencil, size: 16, color: Colors.grey.shade700),
        ),
        IconButton(
          tooltip: 'Eliminar',
          onPressed: () => _eliminar(t),
          icon: const Icon(
            LucideIcons.trash2,
            size: 16,
            color: AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _grupo(CartaItem plato) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                plato.nombrePlato,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _abrirFormulario(cartaId: plato.id),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tamaño'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TarjetaFilas(
          filas: [for (final t in variantesDeCarta(plato.id)) _fila(t)],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CartaItem>>(
      valueListenable: cartasNotifier,
      builder: (context, cartas, _) {
        final conTamanos = [
          for (final c in cartas)
            if (variantesDeCarta(c.id).isNotEmpty) c,
        ]..sort((a, b) => a.nombrePlato.compareTo(b.nombrePlato));
        return PaginaInventario(
          secciones: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CabeceraSeccion(
                  titulo: 'Tamaños de platos',
                  descripcion:
                      'Tamaños con precio propio (por ejemplo, pescado pequeño, '
                      'mediano y grande). El plato solo los muestra.',
                  accion: BotonNuevo(
                    etiqueta: 'Tamaño',
                    onPressed: () => _abrirFormulario(),
                  ),
                ),
                const SizedBox(height: 14),
                if (conTamanos.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 22,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      _cargando
                          ? 'Cargando…'
                          : 'Aún no hay tamaños. Crea el primero con "Tamaño".',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                else
                  for (var i = 0; i < conTamanos.length; i++) ...[
                    if (i > 0) const SizedBox(height: 18),
                    _grupo(conTamanos[i]),
                  ],
              ],
            ),
          ],
        );
      },
    );
  }
}
