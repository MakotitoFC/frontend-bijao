import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../models/carta_item.dart';
import '../models/categoria_comida.dart';
import '../models/reglas_cocina.dart';
import '../services/api_client.dart';
import '../services/reglas_cocina_service.dart';
import '../theme/app_theme.dart';
import 'app_switch.dart';
import 'app_tag.dart';
import 'app_toast.dart';

// Configuración (administrador) de qué sale en la comanda de cocina: se apaga
// una categoría entera (bebidas, tápers, helados…) y, dentro de ella, se marcan
// los platos que sí deben salir (limonada, aguaje…). También al revés: un plato
// que no debe salir aunque su categoría sí.
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
  bool _sinRuta = false;

  bool get _cambios => _reglas != _guardadas;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final r = await ReglasCocinaService.instance.cargar();
    if (!mounted) return;
    setState(() {
      _sinRuta = r == null;
      _guardadas = r ?? const ReglasCocina();
      _reglas = _guardadas.copia();
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await ReglasCocinaService.instance.guardar(_reglas);
      if (!mounted) return;
      setState(() {
        _guardadas = _reglas.copia();
        _guardando = false;
        _sinRuta = false;
      });
      showAppToast(
        context,
        'Listo: la cocina recibirá solo lo que marcaste.',
        type: ToastType.success,
        titulo: 'Impresión en cocina',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      showAppToast(
        context,
        e is ApiException ? e.message : 'No se pudo guardar: $e',
        type: ToastType.error,
      );
    }
  }

  // Regla de una categoría: al prenderla vuelve al valor por defecto (sí).
  void _categoria(String id, bool imprime) {
    final c = _reglas.copia();
    if (imprime) {
      c.categorias.remove(id);
    } else {
      c.categorias[id] = false;
    }
    setState(() => _reglas = c);
  }

  // Excepción de un plato: null = sigue a su categoría.
  void _plato(String id, bool? imprime) {
    final c = _reglas.copia();
    if (imprime == null) {
      c.platos.remove(id);
    } else {
      c.platos[id] = imprime;
    }
    setState(() => _reglas = c);
  }

  List<CartaItem> _platosDe(CategoriaComida cat) =>
      cartasNotifier.value.where((p) => p.categoriaId == cat.id).toList()
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
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Impresión en cocina',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_cambios)
                    TextButton(
                      onPressed: _guardando
                          ? null
                          : () => setState(() => _reglas = _guardadas.copia()),
                      child: const Text('Descartar'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _cambios && !_guardando ? _guardar : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(_guardando ? 'Guardando…' : 'Guardar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Elige qué categorías salen en la comanda de cocina. Dentro de '
                'una categoría apagada puedes marcar los platos que sí deben '
                'salir (por ejemplo, la limonada y el aguaje en Bebidas); y en '
                'una categoría prendida, los que no. Lo demás se imprime solo '
                'en caja o no se imprime.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              if (_sinRuta) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.naranja.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'El servidor todavía no guarda estas reglas: puedes '
                    'armarlas, pero no se aplicarán en la cocina hasta que '
                    'el servidor las habilite.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (categorias.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      'Aún no hay categorías',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ),
              for (final cat in categorias) ...[
                _tarjetaCategoria(cat),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaCategoria(CategoriaComida cat) {
    final imprime = _reglas.imprimeCategoria(cat.id);
    final platos = _platosDe(cat);
    final abierta = _abiertas.contains(cat.id);
    final excepciones = platos.where((p) => _reglas.platos.containsKey(p.id));
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
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      if (!_abiertas.remove(cat.id)) _abiertas.add(cat.id);
                    }),
                    child: Row(
                      children: [
                        AnimatedRotation(
                          turns: abierta ? 0.25 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            cat.categoria,
                            softWrap: true,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${platos.length} platos'
                          '${excepciones.isNotEmpty ? ' · ${excepciones.length} con excepción' : ''}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
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
                  onChanged: (v) => _categoria(cat.id, v),
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primaryGreen,
                ),
              ],
            ),
          ),
          if (abierta) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            if (platos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Esta categoría no tiene platos.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            for (final p in platos) _filaPlato(p, imprime),
          ],
        ],
      ),
    );
  }

  Widget _filaPlato(CartaItem p, bool categoriaImprime) {
    final excepcion = _reglas.platos[p.id];
    final sale = excepcion ?? categoriaImprime;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
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
            etiqueta: 'Como la categoría',
            activo: excepcion == null,
            onTap: () => _plato(p.id, null),
          ),
          AppTag(
            etiqueta: 'Sí sale',
            activo: excepcion == true,
            onTap: () => _plato(p.id, true),
          ),
          AppTag(
            etiqueta: 'No sale',
            activo: excepcion == false,
            onTap: () => _plato(p.id, false),
          ),
        ],
      ),
    );
  }
}
