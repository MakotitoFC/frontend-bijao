import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/pedidos_store.dart';
import '../models/pedido_line.dart';
import '../models/taper.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';
import 'dialogo_app.dart';

// Un táper del catálogo con la cantidad elegida.
typedef TaperElegido = ({Taper taper, int cantidad});

// Fila de pedido para un táper del catálogo: el servidor la guarda con su
// `taper_id` y toma el precio del catálogo (`taper.precio`). Va "para llevar".
PedidoLine lineaDeTaper(Taper t, int cantidad) => PedidoLine(
  id: UuidHelper.v7(),
  cartaId: cartaIdTaper,
  nombrePlato: t.nombre,
  cantidad: cantidad,
  modificadores: const [],
  presentacion: null,
  promocion: null,
  comentario: null,
  precioUnitario: t.precio,
  descuentoAplicado: 0,
  precioTotalLinea: t.precio * cantidad,
  tipoEntrega: 'llevar',
  taperId: t.id,
  precioBase: t.precio,
);

// Elige tápers del catálogo (nombre y precio los pone el administrador en
// Inventario) y cuántos de cada uno. Devuelve solo los de cantidad mayor a 0, o
// null si se cierra.
class TaperCatalogoDialog extends StatefulWidget {
  final List<Taper> tapers;
  // Cantidades con las que arranca (por id de táper).
  final Map<String, int> iniciales;

  const TaperCatalogoDialog({
    super.key,
    required this.tapers,
    this.iniciales = const {},
  });

  @override
  State<TaperCatalogoDialog> createState() => _TaperCatalogoDialogState();
}

class _TaperCatalogoDialogState extends State<TaperCatalogoDialog> {
  late final Map<String, int> _cantidades = {...widget.iniciales};

  int _cant(Taper t) => _cantidades[t.id] ?? 0;

  String _stock(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  double get _total =>
      widget.tapers.fold(0.0, (s, t) => s + t.precio * _cant(t));

  bool get _hay => widget.tapers.any((t) => _cant(t) > 0);

  void _cambiar(Taper t, int delta) {
    final nueva = (_cant(t) + delta).clamp(0, 99);
    setState(() => _cantidades[t.id] = nueva);
  }

  Widget _fila(Taper t) {
    final c = _cant(t);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'S/ ${t.precio.toStringAsFixed(2)} c/u · ',
                      ),
                      // El stock es informativo: no impide agregar.
                      TextSpan(
                        text: 'Stock ${_stock(t.stock)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c > t.stock
                              ? AppColors.naranja
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton.outlined(
            tooltip: 'Quitar uno',
            onPressed: c > 0 ? () => _cambiar(t, -1) : null,
            icon: const Icon(LucideIcons.minus, size: 16),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$c',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton.outlined(
            tooltip: 'Agregar uno',
            onPressed: () => _cambiar(t, 1),
            icon: const Icon(LucideIcons.plus, size: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DialogoApp(
      titulo: 'Táper',
      ancho: 420,
      acciones: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _hay
              ? () => Navigator.of(context).pop<List<TaperElegido>>([
                  for (final t in widget.tapers)
                    if (_cant(t) > 0) (taper: t, cantidad: _cant(t)),
                ])
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
          ),
          child: Text('Agregar · S/ ${_total.toStringAsFixed(2)}'),
        ),
      ],
      children: [
        Text(
          'El precio sale del catálogo de tápers. Se agrega como un producto '
          'más del pedido.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        for (final t in widget.tapers) _fila(t),
      ],
    );
  }
}
