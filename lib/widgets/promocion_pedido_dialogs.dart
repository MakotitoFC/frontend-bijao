import 'package:flutter/material.dart';

import '../data/pedidos_store.dart';
import '../data/promociones_store.dart';
import '../data/subcategorias_store.dart';
import '../models/pedido_line.dart';
import '../models/promocion.dart';
import '../models/promocion_componente.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import '../utils/uuid_helper.dart';
import 'app_toast.dart';
import 'pago_dialogs.dart';

// Promoción lista para agregar al pedido: la promoción tal como la configuró el
// admin (con los cambios que pidió el cliente, si los hubo).
typedef PromocionConfigurada = ({
  Promocion promocion,
  int cantidad,
  List<ComponenteElegido> componentes,
  String? comentario,
  double precioUnitario,
});

// El mozo elige una promoción disponible (vigente y completa) y, si el cliente
// lo pide, cambia algún producto. No puede agregar nada que el admin no haya
// registrado. Devuelve null si cancela.
Future<PromocionConfigurada?> elegirPromocion(BuildContext context) async {
  final disponibles = promocionesDisponibles();
  if (disponibles.isEmpty) {
    showAppToast(
      context,
      'No hay promociones disponibles. El administrador las configura en '
      'Configuración → Promociones.',
      type: ToastType.info,
      titulo: 'Promociones',
    );
    return null;
  }
  final promo = await showBlurDialog<Promocion>(
    context: context,
    builder: (_) => const PromocionesDisponiblesDialog(),
  );
  if (promo == null || !context.mounted) return null;
  return showBlurDialog<PromocionConfigurada>(
    context: context,
    builder: (_) => PromocionOpcionesDialog(promocion: promo),
  );
}

// Línea de pedido de una promoción (`pedidos_detalle` con `promocion_id`).
PedidoLine lineaDePromocion(PromocionConfigurada r) => PedidoLine(
  id: UuidHelper.v7(),
  cartaId: cartaIdPromocion,
  nombrePlato: r.promocion.nombre,
  cantidad: r.cantidad,
  modificadores: const [],
  presentacion: null,
  promocion: r.promocion,
  comentario: r.comentario,
  precioUnitario: r.precioUnitario,
  descuentoAplicado: 0,
  precioTotalLinea: r.precioUnitario * r.cantidad,
  componentes: r.componentes,
);

// Texto de un componente elegido, para mostrar en líneas y cocina.
String textoDeComponente(ComponenteElegido e) =>
    '${e.cantidad} × ${e.nombre}${e.esCambio ? ' (cambio)' : ''}';

String _soles(double v) => 'S/ ${v.toStringAsFixed(2)}';

// ---------------------------------------------------------------------------
// Lista de promociones disponibles.
// ---------------------------------------------------------------------------

class PromocionesDisponiblesDialog extends StatelessWidget {
  const PromocionesDisponiblesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final promos = promocionesDisponibles();
    return ModalPago(
      titulo: 'Promociones',
      subtitulo: 'Elige una promoción para agregar al pedido',
      anchoEscritorio: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in promos) ...[
            _tarjeta(context, p),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _tarjeta(BuildContext context, Promocion p) {
    final seleccion = seleccionInicial(p);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).pop(p),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.platoDelDia.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    p.etiqueta,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.platoDelDia,
                    ),
                  ),
                ),
              ],
            ),
            if (p.descripcion != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  p.descripcion!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 8),
            for (final e in seleccion)
              Text(
                '${e.cantidad} × ${e.nombre}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            const SizedBox(height: 8),
            Text(
              _soles(totalDeSeleccion(seleccion)),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.primaryGreenDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// La promoción armada: cada hueco con su producto incluido y, si hay otras
// opciones registradas, la posibilidad de cambiarlo a pedido del cliente.
// ---------------------------------------------------------------------------

class PromocionOpcionesDialog extends StatefulWidget {
  final Promocion promocion;
  // Selección actual al editar una línea ya agregada.
  final List<ComponenteElegido>? inicial;
  final int cantidadInicial;
  final String? comentarioInicial;
  // true = cambia los productos de una línea existente (sin cantidad ni nota).
  final bool edicion;

  const PromocionOpcionesDialog({
    super.key,
    required this.promocion,
    this.inicial,
    this.cantidadInicial = 1,
    this.comentarioInicial,
    this.edicion = false,
  });

  @override
  State<PromocionOpcionesDialog> createState() =>
      _PromocionOpcionesDialogState();
}

class _PromocionOpcionesDialogState extends State<PromocionOpcionesDialog> {
  // componenteId -> opcionId elegida.
  final Map<String, String> _elegidas = {};
  // Componentes con la lista de opciones desplegada.
  final Set<String> _desplegados = {};
  late int _cantidad = widget.cantidadInicial;
  late final _comentario = TextEditingController(
    text: widget.comentarioInicial,
  );

  @override
  void initState() {
    super.initState();
    for (final c in componentesDe(widget.promocion.id)) {
      final previa = widget.inicial
          ?.where((e) => e.componenteId == c.id)
          .map((e) => e.opcionId)
          .firstOrNull;
      _elegidas[c.id] =
          (previa != null &&
              opcionesDe(c.id, soloActivas: true).any((o) => o.id == previa))
          ? previa
          : opcionIncluida(c.id)!.id;
    }
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  List<ComponenteElegido> get _seleccion => [
    for (final c in componentesDe(widget.promocion.id))
      elegirOpcion(
        widget.promocion,
        c,
        opcionesDe(c.id).firstWhere((o) => o.id == _elegidas[c.id]),
      ),
  ];

  double get _precioUnitario => totalDeSeleccion(_seleccion);

  void _confirmar() {
    final nota = _comentario.text.trim();
    Navigator.of(context).pop<PromocionConfigurada>((
      promocion: widget.promocion,
      cantidad: _cantidad,
      componentes: _seleccion,
      comentario: nota.isEmpty ? null : nota,
      precioUnitario: _precioUnitario,
    ));
  }

  Widget _paso(IconData icono, VoidCallback? onTap) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onTap == null
            ? Colors.grey.shade100
            : AppColors.primaryGreen.withValues(alpha: 0.12),
      ),
      child: Icon(
        icono,
        size: 18,
        color: onTap == null ? Colors.grey.shade400 : AppColors.primaryGreenDark,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = widget.promocion;
    final componentes = componentesDe(p.id);
    final seleccion = _seleccion;
    final total = _precioUnitario;
    return ModalPago(
      titulo: p.nombre,
      subtitulo: widget.edicion
          ? 'Cambia un producto si el cliente lo pide'
          : 'Si el cliente lo pide, cambia un producto por otra opción',
      anchoEscritorio: 480,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < componentes.length; i++) ...[
              _bloque(componentes[i], seleccion[i]),
              const SizedBox(height: 10),
            ],
            if (!widget.edicion) ...[
              TextField(
                controller: _comentario,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cantidad',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _paso(
                    Icons.remove,
                    _cantidad > 1 ? () => setState(() => _cantidad--) : null,
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$_cantidad',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _paso(Icons.add, () => setState(() => _cantidad++)),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.edicion || _cantidad == 1
                        ? 'Precio'
                        : 'Precio × $_cantidad',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _soles(widget.edicion ? total : total * _cantidad),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _confirmar,
              child: Text(
                widget.edicion ? 'Guardar cambios' : 'Agregar al pedido',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bloque(PromocionComponente c, ComponenteElegido elegido) {
    final activas = opcionesDe(c.id, soloActivas: true);
    final puedeCambiar = activas.length > 1;
    final desplegado = _desplegados.contains(c.id);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: elegido.esCambio
              ? AppColors.platoDelDia
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            nombreDeSubcategoria(c.subcategoriaId).toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${c.cantidad} × ${elegido.nombre}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                _soles(elegido.precio),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (elegido.esCambio)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Cambio${elegido.precioAjuste != 0 ? ' · ${elegido.precioAjuste > 0 ? '+' : '-'}${_soles(elegido.precioAjuste.abs())}' : ''}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.platoDelDia,
                ),
              ),
            ),
          if (puedeCambiar)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  if (!_desplegados.remove(c.id)) _desplegados.add(c.id);
                }),
                icon: Icon(
                  desplegado ? Icons.expand_less : Icons.swap_horiz,
                  size: 18,
                ),
                label: Text(desplegado ? 'Ocultar opciones' : 'Cambiar'),
              ),
            ),
          if (puedeCambiar && desplegado)
            for (final o in activas) _filaOpcion(c, o),
        ],
      ),
    );
  }

  Widget _filaOpcion(PromocionComponente c, PromocionOpcion o) {
    final activa = _elegidas[c.id] == o.id;
    final unitario =
        elegirOpcion(widget.promocion, c, o).precio / (c.cantidad == 0 ? 1 : c.cantidad);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() {
        _elegidas[c.id] = o.id;
        _desplegados.remove(c.id);
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                activa ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: activa ? AppColors.primaryGreen : Colors.grey.shade400,
              ),
            ),
            Expanded(child: Text(nombreDeOpcion(o))),
            Text(
              _soles(unitario),
              style: TextStyle(
                fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                color: activa ? AppColors.primaryGreenDark : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
