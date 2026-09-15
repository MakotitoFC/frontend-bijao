import 'package:flutter/material.dart';

import '../data/mock_modificadores.dart';
import '../data/mock_presentaciones.dart';
import '../data/promociones_store.dart';
import '../data/mock_tapers.dart';
import '../models/carta_item.dart';
import '../models/carta_presentacion.dart';
import '../models/modificador.dart';
import '../models/pedido_line.dart';
import '../models/promocion.dart';
import '../models/taper.dart';

// Configura cantidad, modificadores, taper y presentación (bebidas) de un
// ítem antes de agregarlo al carrito. Devuelve el PedidoLine resultante
// via Navigator.pop, o null si se cancela.
class AgregarItemSheet extends StatefulWidget {
  final CartaItem item;

  const AgregarItemSheet({super.key, required this.item});

  @override
  State<AgregarItemSheet> createState() => _AgregarItemSheetState();
}

class _AgregarItemSheetState extends State<AgregarItemSheet> {
  int _cantidad = 1;
  final Set<Modificador> _modificadoresSeleccionados = {};
  CartaPresentacion? _presentacionSeleccionada;
  bool _conTaper = false;
  final _comentarioController = TextEditingController();

  late final List<Modificador> _modificadoresDisponibles;
  late final List<CartaPresentacion> _presentacionesDisponibles;
  late final Taper? _taper;
  late final Promocion? _promocion;

  @override
  void initState() {
    super.initState();
    _modificadoresDisponibles = mockModificadores
        .where((m) => m.cartaId == widget.item.id)
        .toList();
    _presentacionesDisponibles = mockPresentaciones
        .where((p) => p.cartaId == widget.item.id)
        .toList();
    _presentacionSeleccionada = _presentacionesDisponibles.isNotEmpty
        ? _presentacionesDisponibles.first
        : null;
    _taper = widget.item.taperId == null
        ? null
        : mockTapers.where((t) => t.id == widget.item.taperId).firstOrNull();
    _promocion = promocionDeCarta(widget.item.id);
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  double get _precioBaseUnitario =>
      _presentacionSeleccionada?.precioCliente ??
      widget.item.precioCliente ??
      0;

  double get _modificadoresUnitario =>
      _modificadoresSeleccionados.fold(0.0, (sum, m) => sum + m.precioAjuste);

  double get _taperUnitario => _conTaper ? (_taper?.precio ?? 0) : 0;

  double get _precioUnitario =>
      _precioBaseUnitario + _modificadoresUnitario + _taperUnitario;

  double get _subtotal => _precioUnitario * _cantidad;

  double get _descuento {
    if (_promocion == null) return 0;
    return _promocion.tipo == 'porcentaje'
        ? _subtotal * (_promocion.valor / 100)
        : _promocion.valor * _cantidad;
  }

  double get _total => _subtotal - _descuento;

  void _confirmar() {
    Navigator.of(context).pop(
      PedidoLine(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        cartaId: widget.item.id,
        nombrePlato: widget.item.nombrePlato,
        cantidad: _cantidad,
        modificadores: _modificadoresSeleccionados.toList(),
        presentacion: _presentacionSeleccionada,
        taper: _conTaper ? _taper : null,
        promocion: _promocion,
        comentario: _comentarioController.text.trim().isEmpty
            ? null
            : _comentarioController.text.trim(),
        precioUnitario: _precioUnitario,
        descuentoAplicado: _descuento,
        precioTotalLinea: _total,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                widget.item.nombrePlato,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.descripcion,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_promocion != null) ...[
                const SizedBox(height: 12),
                Chip(
                  avatar: const Icon(Icons.local_offer_outlined, size: 18),
                  label: Text('${_promocion.nombre} (${_promocion.etiqueta})'),
                ),
              ],
              if (_presentacionesDisponibles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Presentación',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                RadioGroup<CartaPresentacion>(
                  groupValue: _presentacionSeleccionada,
                  onChanged: (value) =>
                      setState(() => _presentacionSeleccionada = value),
                  child: Column(
                    children: _presentacionesDisponibles
                        .map(
                          (p) => RadioListTile<CartaPresentacion>(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${p.unidad.unidadPresentacion} · ${p.volumenMl} ml',
                            ),
                            secondary: Text(
                              'S/ ${p.precioCliente.toStringAsFixed(2)}',
                            ),
                            value: p,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              if (_modificadoresDisponibles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Modificadores',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                ..._modificadoresDisponibles.map(
                  (m) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.nombre),
                    secondary: m.precioAjuste > 0
                        ? Text('+S/ ${m.precioAjuste.toStringAsFixed(2)}')
                        : null,
                    value: _modificadoresSeleccionados.contains(m),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _modificadoresSeleccionados.add(m);
                      } else {
                        _modificadoresSeleccionados.remove(m);
                      }
                    }),
                  ),
                ),
              ],
              if (_taper != null) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Llevar en ${_taper.nombre}'),
                  secondary: Text('+S/ ${_taper.precio.toStringAsFixed(2)}'),
                  value: _conTaper,
                  onChanged: (checked) =>
                      setState(() => _conTaper = checked ?? false),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cantidad',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _cantidad > 1
                            ? () => setState(() => _cantidad--)
                            : null,
                      ),
                      Text(
                        '$_cantidad',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => _cantidad++),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _comentarioController,
                decoration: const InputDecoration(
                  labelText: 'Comentario (opcional)',
                  hintText: 'Ej. sin sal, para llevar, etc.',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    'S/ ${_total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _confirmar,
                child: const Text('Agregar al pedido'),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? firstOrNull() => isEmpty ? null : first;
}
