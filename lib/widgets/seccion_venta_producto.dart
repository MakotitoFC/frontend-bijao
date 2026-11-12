import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cartas_store.dart';
import '../data/inventario_store.dart';
import '../models/producto_inventario.dart';
import '../models/taper.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'app_switch.dart';
import 'campo_texto.dart';
import 'tabs_texto.dart';

// Cómo se vende un producto nuevo; el formulario lo usa para mostrar solo lo
// necesario y para rellenar el nombre y las unidades.
enum ModoVentaProducto { noSeVende, carta, taperNuevo }

class _FilaCarta {
  String? cartaId;
  final TextEditingController cantidad;

  _FilaCarta({this.cartaId, String cantidad = '1'})
    : cantidad = TextEditingController(text: cantidad);
}

// Sección "Venta" de la ficha de un producto de inventario: cómo se cobra lo
// que se lleva en stock.
//  - No se vende: es un insumo o menaje.
//  - Se vende en la carta: elige qué productos de la carta lo descuentan y
//    cuánto por unidad vendida (1 para una gaseosa o una botella).
//  - Táper: si el producto es un táper, aquí se editan su precio y si está
//    activo (ya no hace falta una pestaña aparte).
// El formulario llama a [guardar] después de guardar el producto.
class SeccionVentaProducto extends StatefulWidget {
  final ProductoInventario? producto; // null = producto nuevo
  // Avisa al formulario cuando cambia el modo o el producto de la carta
  // elegido (con su nombre).
  final void Function(ModoVentaProducto modo, String? cartaNombre)? onCambio;

  const SeccionVentaProducto({super.key, this.producto, this.onCambio});

  @override
  State<SeccionVentaProducto> createState() => SeccionVentaProductoState();
}

class SeccionVentaProductoState extends State<SeccionVentaProducto> {
  bool _cargando = true;
  String? _errorCarga;
  bool _seVende = false;
  // Solo en un producto nuevo: crearlo como táper (se cobra en pedidos para
  // llevar o delivery). El formulario lo crea con el servicio de tápers.
  bool _esTaperNuevo = false;
  final List<_FilaCarta> _filas = [];
  // Estado de partida, para guardar solo si algo cambió.
  String _firmaInicial = '';

  bool get esTaperNuevo => _esTaperNuevo;

  ModoVentaProducto get modo => _esTaperNuevo
      ? ModoVentaProducto.taperNuevo
      : (_seVende ? ModoVentaProducto.carta : ModoVentaProducto.noSeVende);

  void _avisar() {
    final cb = widget.onCambio;
    if (cb == null) return;
    String? nombre;
    for (final f in _filas) {
      if (f.cartaId != null) {
        nombre = cartaPorId(f.cartaId)?.nombrePlato;
        break;
      }
    }
    cb(modo, nombre);
  }

  // Precio del táper nuevo o del existente (null si no es un táper).
  double? get precioTaper => (_esTaperNuevo || _taper != null)
      ? double.tryParse(_taperPrecio.text.trim())
      : null;

  Taper? _taper;
  final _taperPrecio = TextEditingController();
  bool _taperActivo = true;
  double? _precioInicial;
  bool _activoInicial = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.cantidad.dispose();
    }
    _taperPrecio.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final p = widget.producto;
    String? error;
    try {
      if (cartasNotifier.value.isEmpty) {
        await CatalogService.instance.cargarCarta();
      }
      if (p != null) {
        await CatalogService.instance.cargarTapers();
        await CatalogService.instance.cargarVinculosCarta();
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    setState(() {
      _errorCarga = error;
      if (p != null) {
        _taper = CatalogService.instance.tapers
            .where((t) => t.productoInventarioId == p.id)
            .firstOrNull;
        final t = _taper;
        if (t != null) {
          _taperPrecio.text = t.precio.toStringAsFixed(2);
          _taperActivo = t.estado;
          _precioInicial = t.precio;
          _activoInicial = t.estado;
        }
        for (final v in vinculosDeProducto(p.id)) {
          _filas.add(
            _FilaCarta(cartaId: v.cartaId, cantidad: _numero(v.cantidad)),
          );
        }
        _seVende = _filas.isNotEmpty;
      }
      _firmaInicial = _firma();
      _cargando = false;
    });
  }

  String _numero(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  String _firma() => _seVende
      ? _filas.map((f) => '${f.cartaId}:${f.cantidad.text.trim()}').join('|')
      : '';

  bool get _hayCambios {
    if (_firma() != _firmaInicial) return true;
    final t = _taper;
    if (t == null) return false;
    final precio = double.tryParse(_taperPrecio.text.trim());
    return precio != _precioInicial || _taperActivo != _activoInicial;
  }

  // Lo que se guardará de los vínculos, sin filas vacías.
  List<({String cartaId, double cantidad})> _vinculos() => [
    if (_seVende)
      for (final f in _filas)
        if (f.cartaId != null)
          (
            cartaId: f.cartaId!,
            cantidad: double.tryParse(f.cantidad.text.trim()) ?? 0,
          ),
  ];

  // Revisa los datos antes de guardar el producto. Devuelve el motivo si algo
  // está mal, o null.
  String? validar() {
    if (_esTaperNuevo) {
      final precio = double.tryParse(_taperPrecio.text.trim());
      if (precio == null || precio < 0) {
        return 'Ingresa un precio válido para el táper.';
      }
      return null;
    }
    if (_taper != null) {
      final precio = double.tryParse(_taperPrecio.text.trim());
      if (precio == null || precio < 0) {
        return 'Ingresa un precio válido para el táper.';
      }
      return null;
    }
    if (!_seVende) return null;
    final usados = <String>{};
    for (final f in _filas) {
      if (f.cartaId == null) {
        return 'Elige el producto de la carta en cada fila, o quita la fila.';
      }
      if (!usados.add(f.cartaId!)) {
        return 'Un producto de la carta está repetido.';
      }
      final c = double.tryParse(f.cantidad.text.trim()) ?? 0;
      if (c <= 0) return 'La cantidad por venta debe ser mayor que cero.';
    }
    if (_filas.isEmpty) {
      return 'Agrega al menos un producto de la carta, o marca "No se vende".';
    }
    return null;
  }

  // Guarda la venta del producto (ya guardado, con su [productoId]). Devuelve
  // el motivo si falló, o null.
  Future<String?> guardar(String productoId) async {
    if (_cargando || _errorCarga != null || _esTaperNuevo || !_hayCambios) {
      return null;
    }
    try {
      final t = _taper;
      if (t != null) {
        await CatalogService.instance.actualizarTaper(
          t.id,
          precio: double.tryParse(_taperPrecio.text.trim()),
          estado: _taperActivo,
        );
      } else {
        await CatalogService.instance.guardarVinculosProducto(
          productoId,
          _vinculos(),
        );
      }
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  List<AppSelectItem<String>> _opcionesCarta(String? actual) {
    final usados = {
      for (final f in _filas)
        if (f.cartaId != null && f.cartaId != actual) f.cartaId!,
    };
    final cartas = [
      for (final c in cartasNotifier.value)
        if (!usados.contains(c.id)) c,
    ]..sort((a, b) => a.nombrePlato.compareTo(b.nombrePlato));
    return [
      for (final c in cartas)
        AppSelectItem(
          value: c.id,
          label: c.precioCliente == null
              ? c.nombrePlato
              : '${c.nombrePlato} · S/ ${c.precioCliente!.toStringAsFixed(2)}',
        ),
    ];
  }

  // Alto de la caja de un campo (sin su etiqueta de arriba).
  static const double _altoCaja = 44;

  Widget _filaCarta(_FilaCarta f, int i) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final angosto = c.maxWidth < 420;
          // Los dos campos llevan su etiqueta arriba: así sus cajas quedan a la
          // misma altura y alineadas con el botón de quitar.
          final selector = AppSelect<String>(
            label: 'Producto de la carta',
            hint: 'Elige un producto',
            value: f.cartaId,
            buscable: true,
            items: _opcionesCarta(f.cartaId),
            onChanged: (v) {
              setState(() => f.cartaId = v);
              _avisar();
            },
          );
          final cantidad = CampoTexto(
            controller: f.cantidad,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(labelText: 'Por venta'),
          );
          final quitar = SizedBox(
            width: 40,
            height: _altoCaja,
            child: IconButton(
              tooltip: 'Quitar',
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _filas.removeAt(i)),
              icon: const Icon(LucideIcons.x, size: 18),
            ),
          );
          if (angosto) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                selector,
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: cantidad),
                    const SizedBox(width: 8),
                    quitar,
                  ],
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 3, child: selector),
              const SizedBox(width: 10),
              SizedBox(width: 110, child: cantidad),
              const SizedBox(width: 4),
              quitar,
            ],
          );
        },
      ),
    );
  }

  Widget _tarjeta({required List<Widget> hijos}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: hijos,
    ),
  );

  Widget _titulo() => Text(
    'Venta',
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade800,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Cargando la venta del producto…',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
      );
    }
    if (_errorCarga != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No se pudo leer la venta de este producto: $_errorCarga',
          style: const TextStyle(fontSize: 12.5, color: AppColors.error),
        ),
      );
    }
    final t = _taper;
    if (t != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titulo(),
          const SizedBox(height: 8),
          _tarjeta(
            hijos: [
              Text(
                'Es un táper: se cobra en los pedidos para llevar y delivery y '
                'descuenta su stock en cada venta.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: CampoTexto(
                      controller: _taperPrecio,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Precio (S/)',
                        prefixText: 'S/ ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Activo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppSwitch(
                    value: _taperActivo,
                    onChanged: (v) => setState(() => _taperActivo = v),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo(),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TabsTexto(
            tabs: [
              TabTexto(
                etiqueta: 'No se vende',
                activa: !_seVende && !_esTaperNuevo,
                onTap: () {
                  setState(() {
                    _seVende = false;
                    _esTaperNuevo = false;
                  });
                  _avisar();
                },
              ),
              TabTexto(
                etiqueta: 'Se vende en la carta',
                activa: _seVende,
                onTap: () {
                  setState(() {
                    _seVende = true;
                    _esTaperNuevo = false;
                    if (_filas.isEmpty) _filas.add(_FilaCarta());
                  });
                  _avisar();
                },
              ),
              if (widget.producto == null)
                TabTexto(
                  etiqueta: 'Es un táper',
                  activa: _esTaperNuevo,
                  onTap: () {
                    setState(() {
                      _esTaperNuevo = true;
                      _seVende = false;
                    });
                    _avisar();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_esTaperNuevo)
          _tarjeta(
            hijos: [
              Text(
                'Se cobra en los pedidos para llevar y delivery y descuenta '
                'su stock en cada venta. El stock inicial y el mínimo son los '
                'de arriba.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              CampoTexto(
                controller: _taperPrecio,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Precio (S/)',
                  prefixText: 'S/ ',
                ),
              ),
            ],
          )
        else if (!_seVende)
          Text(
            'Es un insumo o menaje: solo se lleva su stock.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          )
        else
          _tarjeta(
            hijos: [
              Text(
                'Cada vez que se vende el producto de la carta, se descuenta '
                'esa cantidad de este producto del stock (1 para una gaseosa '
                'o una botella). Si se anula la venta, el stock vuelve.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _filas.length; i++) _filaCarta(_filas[i], i),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _filas.add(_FilaCarta())),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Agregar producto de la carta'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),
      ],
    );
  }
}
