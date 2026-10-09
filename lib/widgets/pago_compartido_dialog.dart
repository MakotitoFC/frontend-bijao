import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../data/configuracion_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../models/medio_pago.dart';
import '../models/pedido.dart';
import '../models/pedido_line.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'app_tag.dart';
import 'app_toast.dart';
import 'pago_dialogs.dart';

// Boleta de un pagador: lo que consumió (o su parte) y cómo pagó.
typedef BoletaPagador = ({
  String nombre,
  List<({String descripcion, double monto})> items,
  double total,
  List<({MedioPago medio, double monto})> pagos,
});

typedef ResultadoPagoCompartido = ({
  bool boletasIndividuales,
  List<BoletaPagador> boletas,
});

enum _Modo { iguales, platos, categoria, grupos }

class _FilaPago {
  MedioPago medio;
  final TextEditingController monto = TextEditingController();

  _FilaPago(this.medio);
}

class _Pagador {
  final TextEditingController nombre;
  final List<_FilaPago> pagos;

  _Pagador(String nombre, MedioPago medio)
    : nombre = TextEditingController(text: nombre),
      pagos = [_FilaPago(medio)];

  void liberar() {
    nombre.dispose();
    for (final p in pagos) {
      p.monto.dispose();
    }
  }
}

double _r2(double v) => (v * 100).roundToDouble() / 100;

// Reparte la cuenta entre varios pagadores. Escenarios: partes iguales, cada
// uno su plato, por categoría (bebidas / platos / postres...) o por grupo
// (subcuentas). Cada pagador puede usar uno o varios métodos de pago, y puede
// pedir su propia boleta. Devuelve las boletas generadas, o null si se cancela.
class PagoCompartidoDialog extends StatefulWidget {
  final Pedido pedido;
  final String titulo;

  const PagoCompartidoDialog({
    super.key,
    required this.pedido,
    required this.titulo,
  });

  @override
  State<PagoCompartidoDialog> createState() => _PagoCompartidoDialogState();
}

class _PagoCompartidoDialogState extends State<PagoCompartidoDialog> {
  static const _maxPagadores = 8;

  _Modo _modo = _Modo.iguales;
  final List<_Pagador> _pagadores = [];
  final Map<String, int> _asignLinea = {};
  final Map<String, int> _asignCategoria = {};
  bool _boletasIndividuales = false;

  late final double _saldo = saldoPendienteDePedido(widget.pedido.id);
  late final List<PedidoLine> _lineas =
      (detallesPorPedido[widget.pedido.id] ?? [])
          .where(esLineaDeProducto)
          .where((l) => _saldoLinea(l) > 0.001)
          .toList();
  late final double _extras = (detallesPorPedido[widget.pedido.id] ?? [])
      .where((l) => !esLineaDeProducto(l))
      .fold(0.0, (s, l) => s + _saldoLinea(l));

  MedioPago get _medioInicial => mediosPagoActivos.first;

  @override
  void initState() {
    super.initState();
    _reiniciar(_Modo.iguales);
  }

  @override
  void dispose() {
    for (final p in _pagadores) {
      p.liberar();
    }
    super.dispose();
  }

  double _saldoLinea(PedidoLine l) =>
      l.precioTotalLinea - montoPagadoDeLinea(l.id);

  String _categoriaDe(PedidoLine l) {
    final item = cartasNotifier.value
        .where((c) => c.id == l.cartaId)
        .firstOrNull;
    if (item == null) return 'Sin categoría';
    final cat = categorias.where((c) => c.id == item.categoriaId).firstOrNull;
    return cat?.categoria ?? 'Sin categoría';
  }

  List<String> get _categorias {
    final vistas = <String>[];
    for (final l in _lineas) {
      final c = _categoriaDe(l);
      if (!vistas.contains(c)) vistas.add(c);
    }
    return vistas;
  }

  String _nombreDefecto(int i) => _modo == _Modo.grupos
      ? 'Grupo ${String.fromCharCode(65 + i)}'
      : 'Persona ${i + 1}';

  void _reiniciar(_Modo modo) {
    for (final p in _pagadores) {
      p.liberar();
    }
    _pagadores.clear();
    _modo = modo;
    _asignLinea.clear();
    _asignCategoria.clear();
    for (var i = 0; i < 2; i++) {
      _pagadores.add(_Pagador(_nombreDefecto(i), _medioInicial));
    }
    _sincronizar();
  }

  void _cambiar(VoidCallback fn) => setState(() {
    fn();
    _sincronizar();
  });

  int _destino(PedidoLine l) {
    final n = _pagadores.length;
    final i = _modo == _Modo.categoria
        ? (_asignCategoria[_categoriaDe(l)] ?? 0)
        : (_asignLinea[l.id] ?? 0);
    return i < n ? i : 0;
  }

  // Lo que debe pagar cada pagador según el modo.
  List<double> get _montos {
    final n = _pagadores.length;
    if (_modo == _Modo.iguales) {
      final parte = (_saldo / n * 100).floorToDouble() / 100;
      return [
        for (var i = 0; i < n; i++)
          i == n - 1 ? _r2(_saldo - parte * (n - 1)) : parte,
      ];
    }
    final base = List<double>.filled(n, 0);
    for (final l in _lineas) {
      base[_destino(l)] += _saldoLinea(l);
    }
    final sumaBase = base.fold(0.0, (a, b) => a + b);
    final res = <double>[];
    var acumulado = 0.0;
    for (var i = 0; i < n; i++) {
      if (i == n - 1) {
        res.add(_r2(_saldo - acumulado));
        break;
      }
      final parte = sumaBase.abs() > 0.001 ? base[i] / sumaBase : 1 / n;
      final m = _r2(base[i] + _extras * parte);
      res.add(m);
      acumulado += m;
    }
    return res;
  }

  // Pagadores con un solo método siguen automáticamente a su monto.
  void _sincronizar() {
    final montos = _montos;
    for (var i = 0; i < _pagadores.length; i++) {
      final p = _pagadores[i];
      if (p.pagos.length == 1) {
        p.pagos.first.monto.text = montos[i].toStringAsFixed(2);
      }
    }
  }

  double _sumaPagos(_Pagador p) =>
      p.pagos.fold(0.0, (s, f) => s + leerMonto(f.monto.text));

  bool get _valido {
    final montos = _montos;
    var hayAlguno = false;
    for (var i = 0; i < _pagadores.length; i++) {
      if (montos[i] <= 0.005) continue;
      hayAlguno = true;
      final p = _pagadores[i];
      if ((_sumaPagos(p) - montos[i]).abs() > 0.01) return false;
      if (p.pagos.any((f) => leerMonto(f.monto.text) <= 0)) return false;
    }
    return hayAlguno;
  }

  void _agregarPagador() {
    if (_pagadores.length >= _maxPagadores) return;
    _cambiar(() {
      _pagadores.add(
        _Pagador(_nombreDefecto(_pagadores.length), _medioInicial),
      );
    });
  }

  void _quitarPagador(int i) {
    if (_pagadores.length <= 2) return;
    _cambiar(() {
      _pagadores.removeAt(i).liberar();
      for (final k in _asignLinea.keys.toList()) {
        final v = _asignLinea[k]!;
        if (v == i) {
          _asignLinea[k] = 0;
        } else if (v > i) {
          _asignLinea[k] = v - 1;
        }
      }
      for (final k in _asignCategoria.keys.toList()) {
        final v = _asignCategoria[k]!;
        if (v == i) {
          _asignCategoria[k] = 0;
        } else if (v > i) {
          _asignCategoria[k] = v - 1;
        }
      }
    });
  }

  // Un pagador puede dividir su monto en varios métodos (ej. 50 efectivo + 50 yape).
  void _agregarMetodo(_Pagador p) {
    final ultimo = p.pagos.last;
    final valor = leerMonto(ultimo.monto.text);
    final mitad = (valor / 2 * 100).floorToDouble() / 100;
    final otro = mediosPagoActivos.firstWhere(
      (m) => p.pagos.every((f) => f.medio.id != m.id),
      orElse: () => _medioInicial,
    );
    setState(() {
      ultimo.monto.text = (valor - mitad).toStringAsFixed(2);
      final nueva = _FilaPago(otro)..monto.text = mitad.toStringAsFixed(2);
      p.pagos.add(nueva);
    });
  }

  void _quitarMetodo(_Pagador p, int i) {
    if (p.pagos.length <= 1) return;
    setState(() {
      final quitada = p.pagos.removeAt(i);
      final monto = leerMonto(quitada.monto.text);
      quitada.monto.dispose();
      final primera = p.pagos.first;
      primera.monto.text = (leerMonto(primera.monto.text) + monto)
          .toStringAsFixed(2);
    });
    _cambiar(() {});
  }

  BoletaPagador _boletaDe(int i, double monto) {
    final p = _pagadores[i];
    final items = <({String descripcion, double monto})>[];
    if (_modo == _Modo.iguales) {
      items.add((
        descripcion: 'Parte del consumo (1/${_pagadores.length})',
        monto: monto,
      ));
    } else {
      var suma = 0.0;
      for (final l in _lineas.where((l) => _destino(l) == i)) {
        final m = _saldoLinea(l);
        suma += m;
        items.add((descripcion: '${l.cantidad}x ${l.nombrePlato}', monto: m));
      }
      final extra = _r2(monto - suma);
      if (extra.abs() > 0.004) {
        items.add((descripcion: 'Cargos y ajustes (prorrata)', monto: extra));
      }
    }
    return (
      nombre: p.nombre.text.trim().isEmpty
          ? _nombreDefecto(i)
          : p.nombre.text.trim(),
      items: items,
      total: monto,
      pagos: [
        for (final f in p.pagos)
          (medio: f.medio, monto: leerMonto(f.monto.text)),
      ],
    );
  }

  void _confirmar() {
    if (!_valido) return;
    final montos = _montos;
    final boletas = <BoletaPagador>[];
    for (var i = 0; i < _pagadores.length; i++) {
      if (montos[i] <= 0.005) continue;
      final boleta = _boletaDe(i, montos[i]);
      boletas.add(boleta);
      for (final pago in boleta.pagos) {
        registrarPago(
          pedido: widget.pedido,
          medioPago: pago.medio,
          montoAbonado: pago.monto,
          propina: 0,
          pagador: boleta.nombre,
        );
      }
    }
    showAppToast(
      context,
      'Pago compartido entre ${boletas.length} · S/ ${_saldo.toStringAsFixed(2)}',
      type: ToastType.success,
      titulo: 'Pago registrado',
    );
    Navigator.of(context)
        .pop((boletasIndividuales: _boletasIndividuales, boletas: boletas));
  }

  // ---------- UI ----------

  String get _descripcionModo => switch (_modo) {
    _Modo.iguales => 'La cuenta se divide en partes iguales.',
    _Modo.platos => 'Cada persona paga los platos que elijas para ella.',
    _Modo.categoria => 'Cada pagador asume una categoría (ej. uno las bebidas, otro los platos).',
    _Modo.grupos =>
      'Subcuentas por grupo (familia A, familia B…); cada grupo paga lo suyo.',
  };

  Widget _boton(IconData icono, VoidCallback? onTap) => InkWell(
    borderRadius: BorderRadius.circular(AppRadii.tag),
    onTap: onTap,
    child: Container(
      width: AppSizes.control,
      height: AppSizes.control,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.tag),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(
        icono,
        size: 16,
        color: onTap == null ? Colors.grey.shade300 : Colors.black87,
      ),
    ),
  );

  List<AppSelectItem<int>> get _opcionesPagador => [
    for (var i = 0; i < _pagadores.length; i++)
      AppSelectItem(
        value: i,
        label: _pagadores[i].nombre.text.trim().isEmpty
            ? _nombreDefecto(i)
            : _pagadores[i].nombre.text.trim(),
      ),
  ];

  Widget _seccionAsignacion() {
    final porCategoria = _modo == _Modo.categoria;
    final filas = <Widget>[];
    if (porCategoria) {
      for (final c in _categorias) {
        final lineasC = _lineas.where((l) => _categoriaDe(l) == c).toList();
        final total = lineasC.fold(0.0, (s, l) => s + _saldoLinea(l));
        filas.add(
          _filaAsignacion(
            titulo: c,
            detalle:
                '${lineasC.length} producto${lineasC.length == 1 ? '' : 's'} · S/ ${total.toStringAsFixed(2)}',
            valor: (_asignCategoria[c] ?? 0).clamp(0, _pagadores.length - 1),
            onChanged: (v) => _cambiar(() => _asignCategoria[c] = v),
          ),
        );
      }
    } else {
      for (final l in _lineas) {
        filas.add(
          _filaAsignacion(
            titulo: '${l.cantidad}x ${l.nombrePlato}',
            detalle: 'S/ ${_saldoLinea(l).toStringAsFixed(2)}',
            valor: _destino(l),
            onChanged: (v) => _cambiar(() => _asignLinea[l.id] = v),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          porCategoria
              ? 'QUIÉN PAGA CADA CATEGORÍA'
              : 'QUIÉN PAGA CADA PRODUCTO',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 8),
        if (filas.isEmpty)
          Text(
            'No hay productos pendientes de pago.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          )
        else
          ...filas,
      ],
    );
  }

  Widget _filaAsignacion({
    required String titulo,
    required String detalle,
    required int valor,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detalle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: AppSelect<int>(
              value: valor,
              compacto: true,
              items: _opcionesPagador,
              onChanged: (v) => onChanged(v ?? 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaPagador(int i, double monto) {
    final p = _pagadores[i];
    final diff = monto - _sumaPagos(p);
    final cuadra = diff.abs() <= 0.01;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppSizes.boton,
                  child: TextField(
                    controller: p.nombre,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      hintText: 'Nombre',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'S/ ${monto.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreenDark,
                ),
              ),
              if (_pagadores.length > 2)
                IconButton(
                  tooltip: 'Quitar',
                  onPressed: () => _quitarPagador(i),
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (var k = 0; k < p.pagos.length; k++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: AppSelect<String>(
                      value: p.pagos[k].medio.id,
                      compacto: true,
                      hint: 'Método',
                      items: [
                        for (final m in mediosPagoActivos)
                          AppSelectItem(value: m.id, label: m.medioPago),
                      ],
                      onChanged: (v) => setState(() {
                        if (v != null) {
                          p.pagos[k].medio = mediosPagoActivos.firstWhere(
                            (m) => m.id == v,
                          );
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: AppSizes.boton,
                      child: TextField(
                        controller: p.pagos[k].monto,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        textAlignVertical: TextAlignVertical.center,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixText: 'S/ ',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: p.pagos.length > 1
                        ? IconButton(
                            tooltip: 'Quitar método',
                            onPressed: () => _quitarMetodo(p, k),
                            icon: Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                              color: Colors.grey.shade500,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: monto > 0.005 ? () => _agregarMetodo(p) : null,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.control),
                  maximumSize: const Size(double.infinity, AppSizes.control),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Dividir en otro método'),
              ),
              if (monto > 0.005)
                Text(
                  cuadra
                      ? 'Completo'
                      : (diff > 0
                            ? 'Falta S/ ${diff.toStringAsFixed(2)}'
                            : 'Sobra S/ ${(-diff).toStringAsFixed(2)}'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cuadra
                        ? AppColors.primaryGreenDark
                        : AppColors.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final montos = _montos;
    final esIguales = _modo == _Modo.iguales;
    return ModalPago(
      titulo: 'Pago compartido #${widget.pedido.numeroPedido}',
      subtitulo: widget.titulo,
      anchoEscritorio: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tarjetaSaldo('Total a repartir', _saldo),
          const SizedBox(height: 14),
          Wrap(
            runSpacing: 8,
            children: [
              AppTag(
                etiqueta: 'Partes iguales',
                activo: _modo == _Modo.iguales,
                onTap: () => setState(() => _reiniciar(_Modo.iguales)),
              ),
              AppTag(
                etiqueta: 'Cada uno su plato',
                activo: _modo == _Modo.platos,
                onTap: () => setState(() => _reiniciar(_Modo.platos)),
              ),
              AppTag(
                etiqueta: 'Por categoría',
                activo: _modo == _Modo.categoria,
                onTap: () => setState(() => _reiniciar(_Modo.categoria)),
              ),
              AppTag(
                etiqueta: 'Por grupo',
                activo: _modo == _Modo.grupos,
                onTap: () => setState(() => _reiniciar(_Modo.grupos)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _descripcionModo,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  esIguales
                      ? 'Dividir entre'
                      : (_modo == _Modo.grupos ? 'Grupos' : 'Pagadores'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _boton(
                Icons.remove,
                _pagadores.length > 2
                    ? () => _quitarPagador(_pagadores.length - 1)
                    : null,
              ),
              SizedBox(
                width: 84,
                child: Text(
                  '${_pagadores.length} ${esIguales ? 'personas' : (_modo == _Modo.grupos ? 'grupos' : 'pagadores')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _boton(
                Icons.add,
                _pagadores.length < _maxPagadores ? _agregarPagador : null,
              ),
            ],
          ),
          if (!esIguales) ...[const SizedBox(height: 14), _seccionAsignacion()],
          const SizedBox(height: 14),
          for (var i = 0; i < _pagadores.length; i++)
            _tarjetaPagador(i, montos[i]),
          Row(
            children: [
              // Switch más bajo, escalado de forma uniforme para no deformarlo.
              SizedBox(
                width: 44,
                height: 28,
                child: FittedBox(
                  child: Switch(
                    value: _boletasIndividuales,
                    onChanged: (v) => setState(() => _boletasIndividuales = v),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Boleta individual por pagador',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _valido ? _confirmar : null,
            icon: const Icon(LucideIcons.users, size: 18),
            label: Text('Cobrar · S/ ${_saldo.toStringAsFixed(2)}'),
          ),
        ],
      ),
    );
  }
}
