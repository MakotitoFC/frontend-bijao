import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/mesas_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../data/usuarios_store.dart';
import '../models/mesa.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/app_select.dart';
import '../widgets/marching_ants_border.dart';
import '../widgets/mesa_card.dart';
import '../widgets/mesa_form_dialog.dart';

// Pedido activo (no pagado) de una mesa, considerando mesas unidas
// (`todasLasMesas`). Usado por el plano (T-1, T-2...).
Pedido? _pedidoActivoDeMesa(int mesaNumero) {
  for (final p in pedidos) {
    if (p.todasLasMesas.contains(mesaNumero) && p.estado != 'pagado') {
      return p;
    }
  }
  return null;
}

String _horaDe(DateTime fecha) =>
    '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

// Mesero que tomó el pedido (pedidos.usuario_id): así se ve, mesa por mesa,
// cuántas está atendiendo cada uno.
String? _meseroDe(Pedido? pedido) {
  if (pedido?.usuarioId == null) return null;
  for (final u in usuarios) {
    if (u.id == pedido!.usuarioId) return u.nombre;
  }
  return null;
}

// Plano de mesas (tabla `mesas`): filtros de zona/estado, unir mesas y la
// grilla. Al tocar una mesa avisa por `onSeleccionarMesa`.
class MesasPlano extends StatefulWidget {
  final ValueChanged<Mesa> onSeleccionarMesa;

  const MesasPlano({super.key, required this.onSeleccionarMesa});

  @override
  State<MesasPlano> createState() => _MesasPlanoState();
}

class _MesasPlanoState extends State<MesasPlano> {
  bool _modoUnion = false;
  final Set<int> _paraUnir = {};
  String? _zona;
  String? _estado;

  void _seleccionarMesa(Mesa mesa) {
    if (_modoUnion) {
      _alternarSeleccionParaUnir(mesa);
      return;
    }
    widget.onSeleccionarMesa(mesa);
  }

  void _alternarSeleccionParaUnir(Mesa mesa) {
    if (mesa.estado != 'libre' || estaUnida(mesa.numero)) return;
    setState(() {
      if (!_paraUnir.remove(mesa.numero)) _paraUnir.add(mesa.numero);
    });
  }

  void _confirmarUnion() {
    if (_paraUnir.length < 2) return;
    setState(() {
      unirMesas(_paraUnir.toList());
      _paraUnir.clear();
      _modoUnion = false;
    });
  }

  void _cancelarUnion() {
    setState(() {
      _paraUnir.clear();
      _modoUnion = false;
    });
  }

  Future<void> _nuevaMesa() async {
    final datos = await showBlurDialog<({int numero, int capacidad})>(
      context: context,
      builder: (_) => const MesaFormDialog(),
    );
    if (datos == null || !mounted) return;
    setState(
      () => agregarMesa(
        numero: datos.numero,
        capacidad: datos.capacidad,
        zona: _zona ?? 'Principal',
      ),
    );
  }

  void _desunir(int numero) {
    setState(() => separarMesas(numero));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _barraSuperior(),
        Expanded(child: _grilla()),
      ],
    );
  }

  // Filtros de zona/estado + Unir mesas/+ Mesa.
  Widget _barraSuperior() {
    final n = _paraUnir.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 170,
                child: AppSelect<String?>(
                  value: _zona,
                  compacto: true,
                  items: [
                    const AppSelectItem(value: null, label: 'Todas las zonas'),
                    for (final z in zonasMesas)
                      AppSelectItem(value: z, label: z),
                  ],
                  onChanged: (v) => setState(() => _zona = v),
                  hint: 'Todas las zonas',
                ),
              ),
              SizedBox(
                width: 190,
                child: AppSelect<String?>(
                  value: _estado,
                  compacto: true,
                  items: const [
                    AppSelectItem(value: null, label: 'Todos los estados'),
                    AppSelectItem(value: 'ocupada', label: 'Ocupadas'),
                    AppSelectItem(value: 'libre', label: 'Libres'),
                  ],
                  onChanged: (v) => setState(() => _estado = v),
                  hint: 'Todos los estados',
                ),
              ),
              _botonOscuro(
                icono: LucideIcons.link,
                texto: 'Unir mesas',
                activo: _modoUnion,
                onTap: () => setState(() {
                  _modoUnion = !_modoUnion;
                  _paraUnir.clear();
                }),
              ),
              _botonOscuro(
                icono: Icons.add,
                texto: 'Mesa',
                onTap: _nuevaMesa,
              ),
            ],
          ),
          if (_modoUnion) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      n < 2
                          ? 'Elige 2 o más mesas libres para unir ($n)'
                          : 'Unir ${_paraUnir.toList().map((e) => 'Mesa $e').join(' + ')}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelarUnion,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: n >= 2 ? _confirmarUnion : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.warning,
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
                    ),
                    child: const Text('Unir'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Botón de trazo verde; activo se rellena de verde.
  Widget _botonOscuro({
    required IconData icono,
    required String texto,
    required VoidCallback onTap,
    bool activo = false,
  }) {
    final color = activo ? Colors.white : AppColors.primaryGreen;
    return Material(
      color: activo ? AppColors.primaryGreen : Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.input),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.input),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.input),
            border: Border.all(color: AppColors.primaryGreen, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(width: 7),
              Text(
                texto,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grilla() {
    final visibles = mesas
        .where(
          (m) =>
              esAnclaDeGrupo(m.numero) &&
              (_zona == null || m.zona == _zona) &&
              (_estado == null || m.estado == _estado),
        )
        .toList();

    if (visibles.isEmpty) {
      return Center(
        child: Text(
          'Sin mesas para este filtro',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        // Escala del dibujo según el ancho disponible.
        final scale = c.maxWidth >= 640
            ? 1.0
            : (c.maxWidth >= 420 ? 0.82 : 0.68);

        final columnas = <List<Mesa>>[];
        for (var i = 0; i < visibles.length; i += 2) {
          final fin = (i + 2 > visibles.length) ? visibles.length : i + 2;
          columnas.add(visibles.sublist(i, fin));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          // Center asegura que el Wrap quede centrado en el ancho disponible.
          child: Center(
            child: Wrap(
              spacing: 24 * scale,
              runSpacing: 24 * scale,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                for (final columna in columnas)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final mesa in columna) ...[
                        _mesaCard(mesa, scale, c.maxWidth),
                        SizedBox(height: 20 * scale),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mesaCard(Mesa mesa, double scale, double anchoDisponible) {
    final ocupada = mesa.estado == 'ocupada';
    final pedido = ocupada ? _pedidoActivoDeMesa(mesa.numero) : null;
    final unidas = otrasUnidas(mesa.numero);
    final seleccionadaParaUnir = _paraUnir.contains(mesa.numero);
    // Mesa unida que no entra en el ancho disponible: se muestra compacta.
    final totalSillas = MesaCard.totalSillasDe(mesa.numero, unidas);
    final simplificada =
        unidas.isNotEmpty && (scale < 1 || totalSillas > 8) &&
        (totalSillas * 34 * scale) > anchoDisponible * 0.85;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _modoUnion && mesa.estado != 'libre' ? 0.4 : 1,
      child: seleccionadaParaUnir
          ? MarchingAntsBorder(
              radius: 34,
              color: Colors.grey.shade400,
              child: MesaCard(
                numero: mesa.numero,
                ocupada: ocupada,
                horaInicio: pedido != null ? _horaDe(pedido.fechaPedido) : null,
                monto: pedido != null ? totalDePedido(pedido.id) : null,
                mesero: _meseroDe(pedido),
                onTap: () => _seleccionarMesa(mesa),
                scale: scale,
                simplificada: simplificada,
              ),
            )
          : MesaCard(
              key: ValueKey('mesa-${mesa.numero}'),
              numero: mesa.numero,
              unidas: unidas,
              ocupada: ocupada,
              horaInicio: pedido != null ? _horaDe(pedido.fechaPedido) : null,
              monto: pedido != null ? totalDePedido(pedido.id) : null,
              mesero: _meseroDe(pedido),
              onTap: () => _seleccionarMesa(mesa),
              onDesunir: unidas.isNotEmpty && mesa.estado == 'libre'
                  ? () => _desunir(mesa.numero)
                  : null,
              scale: scale,
              simplificada: simplificada,
            ),
    );
  }
}
