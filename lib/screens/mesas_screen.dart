import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../data/mesas_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/mesa.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../widgets/mesa_card.dart';
import '../widgets/panel_pedido_mesa.dart';

// Vista de mesas: grilla a pantalla completa estilo "floor plan".
// El panel de detalle aparece SOLO al hacer clic en una mesa.
class MesasScreen extends StatefulWidget {
  const MesasScreen({super.key});

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen> {
  bool _modoUnion = false;
  final Set<int> _paraUnir = {};

  final _busquedaController = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _seleccionarMesa(Mesa mesa) {
    if (_modoUnion) {
      _alternarSeleccionParaUnir(mesa);
      return;
    }
    _abrirPedidoMesa(mesa);
  }

  Future<void> _abrirPedidoMesa(Mesa mesa) async {
    await showBlurDialog<void>(
      context: context,
      builder: (dialogContext) => PanelPedidoMesa(
        key: ValueKey(mesa.numero),
        mesa: mesa,
        onCerrar: () => Navigator.of(dialogContext).pop(),
        onCambio: () => setState(() {}),
      ),
    );
    setState(() {});
  }

  void _alternarSeleccionParaUnir(Mesa mesa) {
    if (mesa.estado != 'libre' || estaUnida(mesa.numero)) return;
    setState(() {
      if (_paraUnir.contains(mesa.numero)) {
        _paraUnir.remove(mesa.numero);
      } else if (_paraUnir.length < 2) {
        _paraUnir.add(mesa.numero);
      }
    });
  }

  void _confirmarUnion() {
    final numeros = _paraUnir.toList();
    if (numeros.length != 2) return;
    setState(() {
      unirMesas(numeros[0], numeros[1]);
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

  void _desunir(int numero) {
    setState(() => separarMesas(numero));
  }

  Pedido? _pedidoActivoDe(int mesaNumero) {
    for (final p in pedidos) {
      if (p.todasLasMesas.contains(mesaNumero) && p.estado != 'pagado') {
        return p;
      }
    }
    return null;
  }

  String _hora(DateTime fecha) =>
      '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildAncho(context),
    );
  }

  Widget _buildAncho(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: _encabezado(context),
          ),
          const SizedBox(height: 16),
          if (_modoUnion) _barraUnion(),
          // La grilla ocupa todo el ancho disponible; su ClipRect propio
          // evita que las mesas se dibujen por encima del encabezado al
          // hacer scroll.
          Expanded(
            child: Padding(padding: const EdgeInsets.all(20), child: _grilla()),
          ),
        ],
      ),
    );
  }

  Widget _barraUnion() {
    final listo = _paraUnir.length == 2;
    return Container(
      width: double.infinity,
      color: AppColors.primaryGreen.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        children: [
          Text(
            listo
                ? 'Unir Mesa ${_paraUnir.elementAt(0)} y Mesa ${_paraUnir.elementAt(1)}'
                : 'Elige 2 mesas libres para unir (${_paraUnir.length}/2)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton(onPressed: _cancelarUnion, child: const Text('Cancelar')),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: listo ? _confirmarUnion : null,
            child: const Text('Unir mesas'),
          ),
        ],
      ),
    );
  }

  BoxShadow get _sombraFlotante => BoxShadow(
    color: Colors.black.withValues(alpha: 0.06),
    blurRadius: 12,
    offset: const Offset(0, 3),
  );

  // Encabezado: dos tarjetas flotantes en la misma fila. Una con las tags de
  // leyenda (Disponible/Ocupada) y otra con el buscador + el botón de unir
  // mesas (sin pestañas de piso/salón porque tu app no maneja zonas).
  Widget _encabezado(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _tarjetaFlotante(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _puntoLeyenda(
                color: const Color(0xFFBDBDBD),
                texto: 'Disponible',
              ),
              const SizedBox(width: 14),
              _puntoLeyenda(color: AppColors.mesaOcupada, texto: 'Ocupada'),
            ],
          ),
        ),
        const Spacer(),
        _tarjetaFlotante(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _busquedaController,
                  onChanged: (v) => setState(() => _busqueda = v),
                  style: const TextStyle(fontSize: 13),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'Buscar mesa...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 34),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 40,
                height: 40,
                child: Material(
                  color: _modoUnion
                      ? const Color(0xFFE8F5E9)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() {
                      _modoUnion = !_modoUnion;
                      _paraUnir.clear();
                    }),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedLink04,
                        size: 18,
                        color: _modoUnion
                            ? AppColors.primaryGreen
                            : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjetaFlotante({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [_sombraFlotante],
      ),
      child: child,
    );
  }

  Widget _puntoLeyenda({required Color color, required String texto}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _grilla() {
    final termino = _busqueda.trim().toLowerCase();
    final visibles = mesas.where((m) {
      final pareja = parejaDe(m.numero);
      if (!(pareja == null || m.numero < pareja)) return false;
      if (termino.isEmpty) return true;
      final etiqueta = pareja == null
          ? 't-${m.numero}'
          : 't-${m.numero}+$pareja';
      return etiqueta.contains(termino) || m.numero.toString() == termino;
    }).toList();

    final columnas = <List<Mesa>>[];
    for (var i = 0; i < visibles.length; i += 2) {
      final fin = (i + 2 > visibles.length) ? visibles.length : i + 2;
      columnas.add(visibles.sublist(i, fin));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // Center: un SingleChildScrollView vertical le da a su hijo un ancho
      // "loose" (0..maxWidth), así que el propio Wrap se encoge a su
      // contenido y WrapAlignment.center no tiene ancho extra sobre el cual
      // centrar. Center sí ocupa todo el ancho disponible y centra el Wrap
      // (ya encogido a su contenido) dentro de él.
      child: Center(
        child: Wrap(
          spacing: 32,
          runSpacing: 32,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            for (final columna in columnas)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final mesa in columna) ...[
                    _mesaCard(mesa),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _mesaCard(Mesa mesa) {
    final ocupada = mesa.estado == 'ocupada';
    final pedido = ocupada ? _pedidoActivoDe(mesa.numero) : null;
    final pareja = parejaDe(mesa.numero);
    final seleccionadaParaUnir = _paraUnir.contains(mesa.numero);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _modoUnion && mesa.estado != 'libre' ? 0.4 : 1,
      child: seleccionadaParaUnir
          ? Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryGreen, width: 2),
                borderRadius: BorderRadius.circular(34),
              ),
              child: MesaCard(
                numero: mesa.numero,
                ocupada: ocupada,
                horaInicio: pedido != null ? _hora(pedido.fechaPedido) : null,
                monto: pedido != null ? totalDePedido(pedido.id) : null,
                onTap: () => _seleccionarMesa(mesa),
              ),
            )
          : MesaCard(
              key: ValueKey('mesa-${mesa.numero}'),
              numero: mesa.numero,
              numeroPareja: pareja,
              ocupada: ocupada,
              horaInicio: pedido != null ? _hora(pedido.fechaPedido) : null,
              monto: pedido != null ? totalDePedido(pedido.id) : null,
              onTap: () => _seleccionarMesa(mesa),
              onDesunir: pareja != null && mesa.estado == 'libre'
                  ? () => _desunir(mesa.numero)
                  : null,
            ),
    );
  }
}
