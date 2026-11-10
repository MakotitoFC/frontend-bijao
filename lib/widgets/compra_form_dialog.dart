import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/catalogos_store.dart';
import '../data/compras_store.dart';
import '../data/inventario_store.dart';
import '../models/compra.dart';
import '../models/compra_detalle.dart';
import '../models/producto_inventario.dart';
import '../models/unidad_producto.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/uuid_helper.dart';
import 'app_select.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';
import 'selector_rango_fechas.dart';

// Un producto de la compra: se llena en su propia tarjeta.
class _Linea {
  ProductoInventario? producto;
  UnidadProducto? unidad;
  final cantidad = TextEditingController();
  final factor = TextEditingController();
  final precio = TextEditingController();

  void dispose() {
    cantidad.dispose();
    factor.dispose();
    precio.dispose();
  }

  static double _leer(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  UnidadProducto? get unidadBase => unidadesProducto
      .where((u) => u.id == producto?.unidadProductoId)
      .firstOrNull;

  // Se compra en una unidad distinta de la base: hay que indicar la equivalencia.
  bool get necesitaFactor =>
      producto != null &&
      unidad != null &&
      unidad!.id != producto!.unidadProductoId;

  double get cantidadValor => _leer(cantidad);
  double get factorValor => necesitaFactor ? _leer(factor) : 1;
  double get cantidadBase => cantidadValor * factorValor;
  double get precioValor => _leer(precio);
  double get total => cantidadValor * precioValor;

  bool get vacia =>
      producto == null &&
      cantidad.text.trim().isEmpty &&
      precio.text.trim().isEmpty;

  bool get completa =>
      producto != null &&
      cantidadValor > 0 &&
      precioValor > 0 &&
      (!necesitaFactor || factorValor > 0);
}

// Nueva compra, todo en un solo modal y con un solo botón de guardado: la
// fecha, las notas y los productos comprados. El título y los botones quedan
// fijos y solo se desplaza el contenido. Al guardar, la compra y sus productos
// se envían juntos y el stock sube. Devuelve true si se guardó.
//
// Con [compra] el diálogo edita solo la fecha y las notas de una compra ya
// guardada.
class CompraFormDialog extends StatefulWidget {
  final Compra? compra;

  const CompraFormDialog({super.key, this.compra});

  @override
  State<CompraFormDialog> createState() => _CompraFormDialogState();
}

class _CompraFormDialogState extends State<CompraFormDialog> {
  late final TextEditingController _notasController;
  late DateTime _fecha;
  bool _guardando = false;
  String? _error;
  final List<_Linea> _lineas = [_Linea()];

  bool get _edita => widget.compra != null;

  double get _total =>
      _lineas.where((l) => l.completa).fold(0.0, (s, l) => s + l.total);

  @override
  void initState() {
    super.initState();
    _fecha = widget.compra?.fechaCompra ?? DateTime.now();
    _notasController = TextEditingController(
      text: widget.compra?.notasLimpias ?? '',
    );
  }

  @override
  void dispose() {
    for (final l in _lineas) {
      l.dispose();
    }
    _notasController.dispose();
    super.dispose();
  }

  void _alCambiar() => setState(() => _error = null);

  // Otra tarjeta, solo cuando el usuario la pide.
  void _agregarLinea() => setState(() {
    _lineas.add(_Linea());
    _error = null;
  });

  void _quitar(int i) {
    setState(() {
      _lineas.removeAt(i).dispose();
      if (_lineas.isEmpty) _lineas.add(_Linea());
      _error = null;
    });
  }

  void _elegirProducto(_Linea l, ProductoInventario? p) {
    l.producto = p;
    // Por defecto se compra en la unidad base del producto.
    l.unidad = l.unidadBase;
    l.factor.clear();
    _alCambiar();
  }

  String _num(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');

  Future<void> _guardar() async {
    final notas = _notasController.text.trim();
    setState(() {
      _guardando = true;
      _error = null;
    });
    if (_edita) {
      await _guardarEdicion(notas);
      return;
    }

    final parciales = _lineas.where((l) => !l.vacia && !l.completa);
    if (parciales.isNotEmpty) {
      setState(() {
        _guardando = false;
        _error =
            'Completa producto, cantidad y precio en cada tarjeta, o quita '
            'la que no uses.';
      });
      return;
    }
    final listas = _lineas.where((l) => l.completa).toList();
    if (listas.isEmpty) {
      setState(() {
        _guardando = false;
        _error = 'Agrega al menos un producto a la compra.';
      });
      return;
    }

    // Se arma la compra con todos sus productos y se envía de una vez.
    final id = UuidHelper.v7();
    registrarCompra(
      Compra(
        id: id,
        fechaCompra: _fecha,
        total: 0,
        notas: notas.isEmpty ? null : notas,
      ),
    );
    for (var i = 0; i < listas.length; i++) {
      final l = listas[i];
      agregarDetalleACompra(
        id,
        CompraDetalle(
          id: '${DateTime.now().microsecondsSinceEpoch}$i',
          compraId: id,
          productoInventarioId: l.producto!.id,
          cantidad: l.cantidadValor,
          unidadProductoId: l.unidad?.id ?? l.producto!.unidadProductoId,
          factorABase: l.factorValor,
          cantidadBase: l.cantidadBase,
          precioUnitario: l.precioValor,
          precioTotal: l.total,
          costoUnitarioBase: l.cantidadBase > 0 ? l.total / l.cantidadBase : 0,
        ),
      );
    }
    try {
      await CatalogService.instance.guardarCompra(id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final texto = e.toString().replaceFirst('Exception: ', '');
      // Si la compra ya quedó guardada y falló solo el stock, no se vuelve a
      // enviar: se avisa y se cierra.
      final yaGuardada = compras.any((c) => c.id == id && c.guardada);
      if (!yaGuardada) descartarCompra(id);
      if (!mounted) return;
      if (yaGuardada) {
        showAppToast(context, texto, type: ToastType.error);
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _guardando = false;
        _error = texto;
      });
    }
  }

  Future<void> _guardarEdicion(String notas) async {
    final original = widget.compra!;
    final marca = original.anulada
        ? '${Compra.prefijoAnulada}${original.motivoAnulacion ?? ''}'
        : '';
    final nuevas = notas.isEmpty
        ? marca
        : (marca.isEmpty ? notas : '$marca\n$notas');
    try {
      await CatalogService.instance.actualizarCompra(
        Compra(
          id: original.id,
          fechaCompra: _fecha,
          total: original.total,
          notas: nuevas,
        ),
      );
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

  // Tarjeta de un producto, de arriba abajo: título con su papelera, producto,
  // cantidad / unidad / precio y, al pie, el stock y el subtotal.
  Widget _tarjetaLinea(int i) {
    final l = _lineas[i];
    final base = l.unidadBase?.unidad ?? '';
    final comprada = l.unidad?.unidad ?? '';
    final puedeQuitar = _lineas.length > 1 || !l.vacia;
    final cantidad = CampoTexto(
      controller: l.cantidad,
      decoration: const InputDecoration(
        labelText: 'Cantidad',
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _alCambiar(),
    );
    final unidad = AppSelect<UnidadProducto>(
      label: 'Unidad',
      hint: 'Unidad',
      value: l.unidad,
      items: [
        for (final u in unidadesProducto)
          AppSelectItem(value: u, label: u.unidad),
      ],
      onChanged: (v) {
        l.unidad = v;
        if (!l.necesitaFactor) l.factor.clear();
        _alCambiar();
      },
    );
    final precio = CampoTexto(
      controller: l.precio,
      decoration: InputDecoration(
        labelText: comprada.isEmpty ? 'Precio (S/)' : 'Precio por $comprada',
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _alCambiar(),
    );
    final stock = l.producto == null
        ? ''
        : (l.cantidadBase > 0
              ? 'Stock: ${_num(l.producto!.stockActual)} → '
                    '${_num(l.producto!.stockActual + l.cantidadBase)} $base'
              : 'Stock actual: ${_num(l.producto!.stockActual)} $base');
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _lineas.length > 1 ? 'Producto ${i + 1}' : 'Producto',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                if (puedeQuitar)
                  // Mismo contenedor circular de trazo gris que la "x" de los
                  // modales.
                  Tooltip(
                    message: 'Quitar producto',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _quitar(i),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Icon(
                          LucideIcons.trash2,
                          size: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AppSelect<ProductoInventario>(
            hint: 'Selecciona un producto',
            buscable: true,
            value: l.producto,
            items: [
              for (final p in productosInventario)
                AppSelectItem(value: p, label: p.nombre),
            ],
            onChanged: (p) => _elegirProducto(l, p),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 420) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cantidad),
                    const SizedBox(width: 10),
                    Expanded(child: unidad),
                    const SizedBox(width: 10),
                    Expanded(child: precio),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cantidad),
                      const SizedBox(width: 10),
                      Expanded(child: unidad),
                    ],
                  ),
                  const SizedBox(height: 10),
                  precio,
                ],
              );
            },
          ),
          if (l.necesitaFactor) ...[
            const SizedBox(height: 10),
            CampoTexto(
              controller: l.factor,
              decoration: InputDecoration(
                labelText: '1 $comprada equivale a… ($base)',
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _alCambiar(),
            ),
          ],
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  stock,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              Text(
                'Subtotal  ',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                'S/ ${l.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Total y botones. En celular los botones ocupan todo el ancho, uno al lado
  // del otro, bajo el total.
  Widget _pie(bool esMobile) {
    final total = Text(
      'Total S/ ${_total.toStringAsFixed(2)}',
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    );
    final cancelar = OutlinedButton(
      onPressed: _guardando ? null : () => Navigator.of(context).pop(),
      child: const Text('Cancelar'),
    );
    final guardar = ElevatedButton(
      onPressed: _guardando ? null : _guardar,
      child: Text(_edita ? 'Guardar cambios' : 'Guardar compra'),
    );
    if (esMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_edita) ...[total, const SizedBox(height: 12)],
          Row(
            children: [
              Expanded(child: cancelar),
              const SizedBox(width: 10),
              Expanded(child: guardar),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        if (!_edita) Expanded(child: total) else const Spacer(),
        cancelar,
        const SizedBox(width: 10),
        guardar,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final pantalla = MediaQuery.sizeOf(context);
    final ancho = _edita ? 440.0 : 600.0;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? pantalla.width : ancho,
          maxWidth: esMobile ? pantalla.width : ancho,
          maxHeight: pantalla.height * (esMobile ? 0.94 : 0.9),
        ),
        // Título y botones fijos; solo el contenido se desplaza.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(28, esMobile ? 24 : 22, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _edita ? 'Editar compra' : 'Nueva compra',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      BotonCerrarCircular(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SeparadorDialogo(),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_edita) ...[
                      Text(
                        'Solo cambian la fecha y las notas. Para corregir '
                        'productos o cantidades, anula la compra y registra '
                        'otra.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Fecha de compra',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Calendario flotante de la app (no abre otro modal).
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectorRangoFechas(
                        valor: DateTimeRange(start: _fecha, end: _fecha),
                        conAtajos: false,
                        onChanged: (r) {
                          if (r != null) setState(() => _fecha = r.start);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    CampoTexto(
                      controller: _notasController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notas (opcional)',
                      ),
                    ),
                    if (!_edita) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Productos comprados',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (var i = 0; i < _lineas.length; i++) _tarjetaLinea(i),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _agregarLinea,
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Agregar otro producto'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              padding: EdgeInsets.fromLTRB(
                28,
                14,
                28,
                (esMobile ? 20 : 22) + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _pie(esMobile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
