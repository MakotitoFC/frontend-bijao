import 'package:flutter/material.dart';

import '../data/configuracion_store.dart';
import '../data/inventario_store.dart';
import '../models/medio_pago.dart';
import '../models/producto_inventario.dart';
import '../services/alquiler_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';

// Alquiler de menaje (manteles, sillas…), todo en un solo modal y con un solo
// botón: cobra el alquiler (ingreso en Caja) y saca las unidades del almacén.
// Con [alquiler] edita el cliente, el precio, el medio de pago y las notas de
// uno ya registrado. Devuelve true si se guardó.
class AlquilerDialog extends StatefulWidget {
  final Alquiler? alquiler;

  const AlquilerDialog({super.key, this.alquiler});

  @override
  State<AlquilerDialog> createState() => _AlquilerDialogState();
}

class _AlquilerDialogState extends State<AlquilerDialog> {
  ProductoInventario? _producto;
  MedioPago? _medio;
  final _cantidad = TextEditingController(text: '1');
  final _precio = TextEditingController();
  final _cliente = TextEditingController();
  final _notas = TextEditingController();
  bool _guardando = false;
  String? _error;

  bool get _edita => widget.alquiler != null;

  // Productos de alquiler; si no hay ninguno marcado así, todos los activos.
  List<ProductoInventario> get _productos {
    final activos = productosInventario.where((p) => p.estado).toList();
    final alquiler = activos
        .where(
          (p) =>
              (p.tipoProductoNombre ?? '').toLowerCase().contains('alquiler'),
        )
        .toList();
    return alquiler.isNotEmpty ? alquiler : activos;
  }

  @override
  void initState() {
    super.initState();
    final a = widget.alquiler;
    _medio =
        mediosPagoActivos
            .where(
              (m) => a != null
                  ? m.id == a.movimiento.medioPagoId
                  : m.grupo == 'efectivo',
            )
            .firstOrNull ??
        mediosPagoActivos.firstOrNull;
    if (a != null) {
      _producto = productosInventario
          .where((p) => p.id == a.productoId)
          .firstOrNull;
      _cantidad.text = '${a.cantidad}';
      _precio.text = a.precioUnitario.toStringAsFixed(2);
      _cliente.text = a.cliente;
      _notas.text = a.notas ?? '';
    } else if (productosInventario.isEmpty) {
      CatalogService.instance.cargarProductosInventario().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _cantidad.dispose();
    _precio.dispose();
    _cliente.dispose();
    _notas.dispose();
    super.dispose();
  }

  int get _cant => int.tryParse(_cantidad.text.trim()) ?? 0;
  double get _precioValor =>
      double.tryParse(_precio.text.trim().replaceAll(',', '.')) ?? 0;
  double get _total => _cant * _precioValor;

  void _elegir(ProductoInventario? p) {
    setState(() {
      _producto = p;
      // El precio sale del precio al cliente del producto y, si no lo tiene,
      // de su costo; se puede cambiar.
      final base = p?.precioCliente ?? p?.costoReposicion ?? p?.costoPromedio;
      if (base != null && base > 0) _precio.text = base.toStringAsFixed(2);
      _error = null;
    });
  }

  Future<void> _guardar() async {
    final p = _producto;
    final medio = _medio;
    if (p == null) {
      setState(() => _error = 'Elige el producto de alquiler.');
      return;
    }
    if (medio == null) {
      setState(() => _error = 'Elige el medio de pago.');
      return;
    }
    if (_precioValor <= 0) {
      setState(() => _error = 'Ingresa el precio por unidad.');
      return;
    }
    if (!_edita) {
      if (_cant <= 0) {
        setState(() => _error = 'Ingresa una cantidad mayor a 0.');
        return;
      }
      if (_cant > p.stockActual) {
        setState(
          () => _error =
              'Solo hay ${p.stockActual.toStringAsFixed(0)} disponibles.',
        );
        return;
      }
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      if (_edita) {
        await AlquilerService.instance.editar(
          widget.alquiler!,
          precioUnitario: _precioValor,
          cliente: _cliente.text,
          notas: _notas.text,
          medio: medio,
        );
      } else {
        await AlquilerService.instance.registrar(
          producto: p,
          cantidad: _cant,
          precioUnitario: _precioValor,
          cliente: _cliente.text,
          notas: _notas.text,
          medio: medio,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _producto;
    final disponibles = p?.stockActual ?? 0;
    final campoCantidad = CampoTexto(
      controller: _cantidad,
      readOnly: _edita,
      decoration: const InputDecoration(labelText: 'Cantidad'),
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() => _error = null),
    );
    final campoPrecio = CampoTexto(
      controller: _precio,
      decoration: const InputDecoration(labelText: 'Precio por unidad (S/)'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() => _error = null),
    );
    return DialogoApp(
      titulo: _edita ? 'Editar alquiler' : 'Alquiler',
      ancho: 480,
      acciones: [
        OutlinedButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_edita ? 'Guardar cambios' : 'Cobrar y registrar'),
        ),
      ],
      children: [
        if (_edita)
          Text(
            'Solo cambian el cliente, el precio, el medio de pago y las notas. '
            'Para cambiar el producto o las unidades, anula el alquiler y '
            'registra otro.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        if (_edita) const SizedBox(height: 12),
        AppSelect<ProductoInventario>(
          label: 'Producto de alquiler',
          hint: 'Selecciona un producto',
          buscable: true,
          value: p,
          items: [
            for (final x in _productos)
              AppSelectItem(
                value: x,
                label:
                    '${x.nombre} · ${x.stockActual.toStringAsFixed(0)} disp.',
              ),
          ],
          onChanged: _edita ? (_) {} : _elegir,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth >= 360) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: campoCantidad),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: campoPrecio),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                campoCantidad,
                const SizedBox(height: 12),
                campoPrecio,
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        CampoTexto(
          controller: _cliente,
          decoration: const InputDecoration(
            labelText: 'Cliente (opcional)',
            hintText: 'Nombre o teléfono',
          ),
        ),
        const SizedBox(height: 14),
        AppSelect<MedioPago>(
          label: 'Medio de pago',
          hint: 'Selecciona el medio de pago',
          value: _medio,
          items: [
            for (final m in mediosPagoActivos)
              AppSelectItem(value: m, label: m.medioPago),
          ],
          onChanged: (m) => setState(() => _medio = m),
        ),
        const SizedBox(height: 14),
        CampoTexto(
          controller: _notas,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notas (opcional)'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                !_edita && p != null
                    ? 'Disponibles: ${disponibles.toStringAsFixed(0)} → '
                          '${(disponibles - _cant).toStringAsFixed(0)}'
                    : '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            Text(
              'Total S/ ${_total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(fontSize: 12.5, color: AppColors.error),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
