import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cartas_store.dart';
import '../data/categorias_store.dart';
import '../data/configuracion_store.dart';
import '../data/pagos_store.dart';
import '../data/pedidos_store.dart';
import '../services/api_client.dart';
import '../services/pago_service.dart';
import '../services/catalog_service.dart';
import '../data/movimientos_caja_store.dart';
import '../models/medio_pago.dart';
import '../models/movimiento_caja.dart';
import '../models/pedido.dart';
import '../services/movimiento_caja_service.dart';
import '../models/pedido_line.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'app_toast.dart';
import 'comprobante_en_cobro.dart';
import 'pago_dialogs.dart';
import 'app_switch.dart';
import 'campo_texto.dart';

// Boleta de un pagador: lo que consumió (o su parte) y cómo pagó.
typedef BoletaPagador = ({
  String nombre,
  List<({String descripcion, double monto})> items,
  double total,
  List<({MedioPago medio, double monto})> pagos,
  // Efectivo que entregó y vuelto que se le dio (0 si pagó justo).
  double recibido,
  double vuelto,
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
  // Comprobante que pide este pagador (ticket, boleta o factura); null si el
  // pedido no admite comprobante.
  ComprobanteEnCobro? comprobante;
  // Efectivo con el que paga (para el vuelto); vacío = pagó justo.
  final recibido = TextEditingController();

  _Pagador(String nombre, MedioPago medio)
    : nombre = TextEditingController(text: nombre),
      pagos = [_FilaPago(medio)];

  void liberar() {
    comprobante?.dispose();
    nombre.dispose();
    recibido.dispose();
    for (final p in pagos) {
      p.monto.dispose();
    }
  }
}

double _r2(double v) => (v * 100).roundToDouble() / 100;

// Una unidad de un producto: si se pidieron 3 iguales son 3 unidades y cada una
// se puede asignar a un pagador distinto (uno pide 1 de suri y 1 de chancho,
// otro lo demás). El saldo de la línea se reparte en partes iguales.
class _Unidad {
  final PedidoLine linea;
  final int indice; // desde 0
  final double monto;

  const _Unidad(this.linea, this.indice, this.monto);

  String get clave => '${linea.id}#$indice';
}

// Reparte la cuenta entre varios pagadores. Escenarios: partes iguales, cada
// uno su plato, por categoría (bebidas / platos / postres...) o por grupo
// (subcuentas). Cada pagador puede usar uno o varios métodos de pago, y puede
// pedir su propia boleta. Devuelve las boletas generadas, o null si se cancela.
class PagoCompartidoDialog extends StatefulWidget {
  final Pedido pedido;
  final String titulo;
  final bool permiteVolver;

  const PagoCompartidoDialog({
    super.key,
    required this.pedido,
    required this.titulo,
    this.permiteVolver = false,
  });

  @override
  State<PagoCompartidoDialog> createState() => _PagoCompartidoDialogState();
}

class _PagoCompartidoDialogState extends State<PagoCompartidoDialog> {
  static const _maxPagadores = 8;

  _Modo _modo = _Modo.iguales;
  CategoriaMovimiento? _categoriaSeleccionada;
  final List<_Pagador> _pagadores = [];
  // Pagador de cada unidad de producto (clave de [_Unidad]).
  final Map<String, int> _asignUnidad = {};
  final Map<String, int> _asignCategoria = {};
  bool _boletasIndividuales = false;

  // La cuenta que cobra el servidor: la propina y el táper de la app no se
  // reparten, se cobran aparte.
  late final double _saldo = saldoCuentaDePedido(widget.pedido.id);
  late final double _propinaApp = propinaPendienteDePedido(widget.pedido.id);
  late final double _taperApp = taperPendienteDePedido(widget.pedido.id);
  late final List<PedidoLine> _lineas =
      (detallesPorPedido[widget.pedido.id] ?? [])
          .where(esLineaDeProducto)
          .where((l) => _saldoLinea(l) > 0.001)
          .toList();
  late final List<_Unidad> _unidades = [
    for (final l in _lineas) ..._unidadesDe(l),
  ];

  List<_Unidad> _unidadesDe(PedidoLine l) {
    final n = l.cantidad < 1 ? 1 : l.cantidad;
    final saldo = _saldoLinea(l);
    final cada = _r2(saldo / n);
    return [
      for (var i = 0; i < n; i++)
        _Unidad(l, i, i == n - 1 ? _r2(saldo - cada * (n - 1)) : cada),
    ];
  }

  late final double _extras = (detallesPorPedido[widget.pedido.id] ?? [])
      .where((l) => !esLineaDeProducto(l) && lineaDeCuenta(widget.pedido.id, l))
      .fold(0.0, (s, l) => s + _saldoLinea(l));

  MedioPago get _medioInicial => mediosPagoActivos.first;

  // Comprobante a emitir al saldar la cuenta (solo administración y caja).
  // Cada pagador puede pedir un comprobante distinto: uno ticket, otro boleta
  // y otro factura. Se crea al armar los pagadores.
  late final bool _admiteComprobante = puedeElegirComprobante(widget.pedido);

  ComprobanteEnCobro? _nuevoComprobante() {
    if (!_admiteComprobante) return null;
    return ComprobanteEnCobro(0)..addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _categoriaSeleccionada =
        categoriasDeTipo(TipoMovimiento.ingreso)
            .where((c) => c.nombre.toLowerCase().contains('venta'))
            .firstOrNull ??
        categoriasDeTipo(TipoMovimiento.ingreso).firstOrNull;
    if (mediosPago.isEmpty) {
      CatalogService.instance
          .cargarMediosPago()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((_) {});
    }
    if (categoriasMovimiento.isEmpty) {
      MovimientoCajaService.instance
          .cargarCategorias()
          .then((_) {
            if (mounted) {
              setState(() {
                _categoriaSeleccionada =
                    categoriasDeTipo(TipoMovimiento.ingreso)
                        .where((c) => c.nombre.toLowerCase().contains('venta'))
                        .firstOrNull ??
                    categoriasDeTipo(TipoMovimiento.ingreso).firstOrNull;
              });
            }
          })
          // Sin conexión no se pueden leer las categorías: el cobro sigue.
          .catchError((_) {});
    }
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
    final item = cartaPorId(l.cartaId);
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
    _asignUnidad.clear();
    _asignCategoria.clear();
    for (var i = 0; i < 2; i++) {
      _pagadores.add(
        _Pagador(_nombreDefecto(i), _medioInicial)
          ..comprobante = _nuevoComprobante(),
      );
    }
    _sincronizar();
  }

  void _cambiar(VoidCallback fn) => setState(() {
    fn();
    _sincronizar();
  });

  int _destino(_Unidad u) {
    final n = _pagadores.length;
    final i = _modo == _Modo.categoria
        ? (_asignCategoria[_categoriaDe(u.linea)] ?? 0)
        : (_asignUnidad[u.clave] ?? 0);
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
    for (final u in _unidades) {
      base[_destino(u)] += u.monto;
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

  // Lo que este pagador paga en efectivo (sin recargo).
  double _efectivoDe(_Pagador p) => p.pagos
      .where((f) => f.medio.grupo == 'efectivo')
      .fold(0.0, (s, f) => s + leerMonto(f.monto.text));

  double _vueltoDe(_Pagador p) {
    final r = leerMonto(p.recibido.text);
    final e = _efectivoDe(p);
    return e > 0.005 && r > e + 0.005 ? r - e : 0.0;
  }

  // Vacío = pagó justo; si se escribe, tiene que alcanzar para su efectivo.
  bool _recibidoValido(_Pagador p) {
    final e = _efectivoDe(p);
    return p.recibido.text.trim().isEmpty ||
        e <= 0.005 ||
        leerMonto(p.recibido.text) >= e - 0.005;
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

  // Recargo que se suma a lo que paga [p] (p. ej. por usar tarjeta): se calcula
  // sobre cada monto según su método. No cambia lo que se abona a la cuenta.
  double _recargoDe(_Pagador p) => p.pagos.fold(
    0.0,
    (s, f) => s + f.medio.recargoSobre(leerMonto(f.monto.text)),
  );

  // Recargo de todos los pagadores que tienen algo que pagar.
  double get _recargoTotal {
    final montos = _montos;
    var total = 0.0;
    for (var i = 0; i < _pagadores.length; i++) {
      if (montos[i] > 0.005) total += _recargoDe(_pagadores[i]);
    }
    return total;
  }

  bool get _valido {
    final montos = _montos;
    var hayAlguno = false;
    for (var i = 0; i < _pagadores.length; i++) {
      if (montos[i] <= 0.005) continue;
      hayAlguno = true;
      final p = _pagadores[i];
      if ((_sumaPagos(p) - montos[i]).abs() > 0.01) return false;
      if (p.pagos.any((f) => leerMonto(f.monto.text) <= 0)) return false;
      if (!_recibidoValido(p)) return false;
    }
    return hayAlguno;
  }

  void _agregarPagador() {
    if (_pagadores.length >= _maxPagadores) return;
    _cambiar(() {
      _pagadores.add(
        _Pagador(_nombreDefecto(_pagadores.length), _medioInicial)
          ..comprobante = _nuevoComprobante(),
      );
    });
  }

  void _quitarPagador(int i) {
    if (_pagadores.length <= 2) return;
    _cambiar(() {
      _pagadores.removeAt(i).liberar();
      for (final k in _asignUnidad.keys.toList()) {
        final v = _asignUnidad[k]!;
        if (v == i) {
          _asignUnidad[k] = 0;
        } else if (v > i) {
          _asignUnidad[k] = v - 1;
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
      // Las unidades del mismo producto se juntan: "2x Suri".
      final porLinea = <String, ({String nombre, int cant, double monto})>{};
      for (final u in _unidades.where((u) => _destino(u) == i)) {
        final previo = porLinea[u.linea.id];
        porLinea[u.linea.id] = (
          nombre: u.linea.nombrePlato,
          cant: (previo?.cant ?? 0) + 1,
          monto: (previo?.monto ?? 0) + u.monto,
        );
      }
      var suma = 0.0;
      for (final e in porLinea.values) {
        suma += e.monto;
        items.add((descripcion: '${e.cant}x ${e.nombre}', monto: e.monto));
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
      recibido: _vueltoDe(p) > 0.005 ? leerMonto(p.recibido.text) : 0,
      vuelto: _vueltoDe(p),
    );
  }

  bool _guardando = false;

  // Cada pagador con monto tiene completos los datos de su comprobante.
  bool get _comprobantesCompletos {
    final montos = _montos;
    for (var i = 0; i < _pagadores.length; i++) {
      if (montos[i] <= 0.005) continue;
      if (!(_pagadores[i].comprobante?.completo ?? true)) return false;
    }
    return true;
  }

  // Selector de comprobante de un pagador, con lo que paga como total (así la
  // boleta de más de S/ 700 pide el DNI de ese pagador, no del pedido entero).
  Widget _comprobanteDe(int i, double monto) {
    final p = _pagadores[i];
    final control = p.comprobante;
    if (control == null) return const SizedBox.shrink();
    control.total = monto + _recargoDe(p);
    final nombre = p.nombre.text.trim().isEmpty
        ? _nombreDefecto(i)
        : p.nombre.text.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$nombre · S/ ${control.total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SelectorComprobante(control: control, pedido: widget.pedido),
        ],
      ),
    );
  }

  String _mensajeError(Object e) => e is ApiException
      ? e.message
      : e.toString().replaceFirst('Exception: ', '');

  Future<void> _confirmar() async {
    if (!_valido || _guardando) return;
    final montos = _montos;
    final recargoTotal = _recargoTotal;
    final boletas = <BoletaPagador>[];
    for (var i = 0; i < _pagadores.length; i++) {
      if (montos[i] <= 0.005) continue;
      boletas.add(_boletaDe(i, montos[i]));
    }
    setState(() => _guardando = true);
    // Un pago por cada método de cada pagador. Si uno falla, los anteriores ya
    // están en el servidor: se vuelve a leer y se avisa.
    var registrados = 0;
    final total = boletas.fold<int>(0, (s, b) => s + b.pagos.length);
    // Id del primer pago de cada pagador (por posición): a él se vincula su
    // comprobante.
    final pagoDe = <int, String>{};
    try {
      for (var b = 0; b < boletas.length; b++) {
        final boleta = boletas[b];
        for (final pago in boleta.pagos) {
          final esEfectivo = pago.medio.grupo == 'efectivo' || pago.medio.medioPago.toLowerCase().contains('efectivo');
          final registrado = await PagoService.instance.registrar(
            pedido: widget.pedido,
            medio: pago.medio,
            montoAbonado: pago.monto,
            pagador: boleta.nombre,
            categoriaMovimientoId: _categoriaSeleccionada?.id,
            montoRecibido: esEfectivo && boleta.recibido > 0.005 ? boleta.recibido : null,
            vuelto: esEfectivo && boleta.vuelto > 0.005 ? boleta.vuelto : null,
          );
          pagoDe.putIfAbsent(b, () => registrado.id);
          registrados++;
        }
      }
    } catch (e) {
      try {
        await PagoService.instance.cargarDePedido(widget.pedido);
      } catch (_) {}
      if (!mounted) return;
      showAppToast(
        context,
        registrados == 0
            ? 'No se pudo registrar el pago: ${_mensajeError(e)}'
            : 'Se registraron $registrados de $total pagos y falló uno: '
                  '${_mensajeError(e)}. Revisa lo cobrado antes de seguir.',
        type: ToastType.error,
        titulo: 'Pago incompleto',
        duration: const Duration(seconds: 6),
      );
      if (registrados > 0) {
        Navigator.of(context).pop(); // el saldo cambió: se vuelve a abrir
      } else {
        setState(() => _guardando = false);
      }
      return;
    }
    if (!mounted) return;
    final vueltoTotal = boletas.fold(0.0, (s, b) => s + b.vuelto);
    if (vueltoTotal > 0.005) {
      efectivoRecibidoPorPedido[widget.pedido.id] = (
        recibido: boletas.fold(0.0, (s, b) => s + b.recibido),
        vuelto: vueltoTotal,
      );
    }
    showAppToast(
      context,
      'Pago compartido entre ${boletas.length} · '
      'S/ ${(_saldo + recargoTotal + _propinaApp + _taperApp).toStringAsFixed(2)}'
      '${recargoTotal > 0 ? ' (incluye recargo S/ ${recargoTotal.toStringAsFixed(2)})' : ''}',
      type: ToastType.success,
      titulo: 'Pago registrado',
    );
    // La cuenta quedó saldada: se emite el comprobante que pidió cada pagador
    // (uno puede no querer nada, otro boleta y otro factura).
    final conMonto = [
      for (var i = 0; i < _pagadores.length; i++)
        if (montos[i] > 0.005) _pagadores[i],
    ];
    for (var b = 0; b < conMonto.length; b++) {
      final eleccion = conMonto[b].comprobante;
      if (eleccion == null || !eleccion.emite) continue;
      await emitirComprobanteTrasCobro(
        context,
        widget.pedido,
        eleccion,
        pagoId: pagoDe[b],
      );
      if (!mounted) return;
    }
    Navigator.of(context)
        .pop((boletasIndividuales: _boletasIndividuales, boletas: boletas));
  }

  // ---------- UI ----------

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

  // Un color por pagador, para reconocerlo en las asignaciones y en su tarjeta.
  static const _coloresPagador = [
    Color(0xFF0E9F6E),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFEF4444),
    Color(0xFF64748B),
  ];

  Color _colorDe(int i) => _coloresPagador[i % _coloresPagador.length];

  Widget _avatar(int i, {double tam = 28}) => Container(
    width: tam,
    height: tam,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: _colorDe(i), shape: BoxShape.circle),
    child: Text(
      '${i + 1}',
      style: TextStyle(
        color: Colors.white,
        fontSize: tam * 0.46,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _etiquetaSeccion(String texto) => Text(
    texto,
    style: TextStyle(
      fontSize: 11,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade500,
    ),
  );

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
                '${lineasC.length} producto${lineasC.length == 1 ? '' : 's'}',
            monto: total,
            valor: (_asignCategoria[c] ?? 0).clamp(0, _pagadores.length - 1),
            onChanged: (v) => _cambiar(() => _asignCategoria[c] = v),
          ),
        );
      }
    } else {
      // Una fila por unidad: si se pidieron varios iguales, cada uno se asigna
      // por separado.
      for (final u in _unidades) {
        final varios = u.linea.cantidad > 1;
        filas.add(
          _filaAsignacion(
            titulo: u.linea.nombrePlato,
            detalle: varios
                ? 'Unidad ${u.indice + 1} de ${u.linea.cantidad}'
                : 'Cantidad: 1',
            monto: u.monto,
            valor: _destino(u),
            onChanged: (v) => _cambiar(() => _asignUnidad[u.clave] = v),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _etiquetaSeccion(
          porCategoria
              ? 'QUIÉN PAGA CADA CATEGORÍA'
              : 'QUIÉN PAGA CADA PRODUCTO',
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: filas.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'No hay productos pendientes de pago.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < filas.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: Colors.grey.shade200),
                      filas[i],
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _filaAsignacion({
    required String titulo,
    required String detalle,
    required double monto,
    required int valor,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  '$detalle · S/ ${monto.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _avatar(valor, tam: 22),
          const SizedBox(width: 6),
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
    final conMonto = monto > 0.005;
    final color = _colorDe(i);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: conMonto && cuadra
              ? AppColors.primaryGreen.withValues(alpha: 0.45)
              : Colors.grey.shade300,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            color: color.withValues(alpha: 0.07),
            child: Row(
              children: [
                _avatar(i),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: AppSizes.boton,
                    child: CampoTexto(
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'DEBE PAGAR',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      'S/ ${monto.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryGreenDark,
                      ),
                    ),
                  ],
                ),
                if (_pagadores.length > 2)
                  IconButton(
                    tooltip: 'Quitar',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _quitarPagador(i),
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                                AppSelectItem(
                                  value: m.id,
                                  label: m.aplicaComision
                                      ? '${m.medioPago} (+${m.porcentajeComision.toStringAsFixed(1)}%)'
                                      : m.medioPago,
                                ),
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
                            child: CampoTexto(
                              controller: p.pagos[k].monto,
                              expands: true,
                              maxLines: null,
                              minLines: null,
                              textAlignVertical: TextAlignVertical.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                isDense: true,
                                prefixText: 'S/ ',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
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
                if (conMonto && _recargoDe(p) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Recargo por método de pago: +S/ ${_recargoDe(p).toStringAsFixed(2)} '
                      '· Total que paga: S/ ${(monto + _recargoDe(p)).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.naranja,
                      ),
                    ),
                  ),
                if (conMonto && _efectivoDe(p) > 0.005) ...[
                  const SizedBox(height: 8),
                  CampoTexto(
                    controller: p.recibido,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Paga en efectivo con (S/) · opcional, para el vuelto',
                      errorText: _recibidoValido(p)
                          ? null
                          : 'Falta: su efectivo es S/ ${_efectivoDe(p).toStringAsFixed(2)}',
                    ),
                  ),
                  if (_vueltoDe(p) > 0.005)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Vuelto: S/ ${_vueltoDe(p).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: conMonto ? () => _agregarMetodo(p) : null,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, AppSizes.control),
                            maximumSize: const Size(
                              double.infinity,
                              AppSizes.control,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Dividir en otro método'),
                        ),
                      ),
                    ),
                    if (conMonto) _estadoPagador(cuadra, diff),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Si lo que pone el pagador cuadra con lo que debe: "Completo" o lo que falta.
  Widget _estadoPagador(bool cuadra, double diff) {
    final color = cuadra ? AppColors.primaryGreenDark : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            cuadra ? Icons.check_circle : Icons.error_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            cuadra
                ? 'Completo'
                : (diff > 0
                      ? 'Falta S/ ${diff.toStringAsFixed(2)}'
                      : 'Sobra S/ ${(-diff).toStringAsFixed(2)}'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Una de las cuatro formas de repartir la cuenta.
  Widget _modoTile(_Modo modo, IconData icono, String titulo, String detalle) {
    final activo = _modo == modo;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _reiniciar(modo)),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: activo
                ? AppColors.primaryGreen.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
              width: activo ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icono,
                size: 20,
                color: activo ? AppColors.primaryGreenDark : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: activo ? AppColors.primaryGreenDark : null,
                      ),
                    ),
                    Text(
                      detalle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.2,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final montos = _montos;
    final esIguales = _modo == _Modo.iguales;
    final unidad = esIguales
        ? 'personas'
        : (_modo == _Modo.grupos ? 'grupos' : 'pagadores');
    return ModalPago(
      titulo: 'Pago compartido',
      subtitulo: 'Pedido #${widget.pedido.numeroPedido} · ${widget.titulo}',
      anchoEscritorio: 640,
      onVolver: widget.permiteVolver
          ? () => Navigator.of(context).pop(volverAElegirPago)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tarjetaSaldo('Total a repartir', _saldo),
          const SizedBox(height: 12),
          AppSelect<CategoriaMovimiento>(
            label: 'Concepto / Categoría del cobro',
            flotante: true,
            buscable: true,
            value: _categoriaSeleccionada,
            hint: 'Selecciona concepto de ingreso',
            items: [
              for (final c in categoriasDeTipo(TipoMovimiento.ingreso))
                AppSelectItem(value: c, label: c.nombre),
            ],
            onChanged: (c) => setState(() => _categoriaSeleccionada = c),
          ),
          if (_propinaApp > 0 || _taperApp > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Además se cobra ${[if (_propinaApp > 0) 'propina S/ ${_propinaApp.toStringAsFixed(2)}', if (_taperApp > 0) 'táper S/ ${_taperApp.toStringAsFixed(2)}'].join(' y ')}, sin recargo. No se reparte: se suma al primer cobro.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(height: 16),
          _etiquetaSeccion('¿CÓMO SE REPARTE?'),
          const SizedBox(height: 8),
          Row(
            children: [
              _modoTile(
                _Modo.iguales,
                Icons.pie_chart_outline,
                'Partes iguales',
                'Se divide en partes iguales',
              ),
              const SizedBox(width: 8),
              _modoTile(
                _Modo.platos,
                Icons.restaurant_menu,
                'Cada uno su plato',
                'Eliges quién paga cada plato',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esIguales
                            ? 'Dividir entre'
                            : (_modo == _Modo.grupos ? 'Grupos' : 'Pagadores'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Entre 2 y $_maxPagadores',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _boton(
                  Icons.remove,
                  _pagadores.length > 2
                      ? () => _quitarPagador(_pagadores.length - 1)
                      : null,
                ),
                SizedBox(
                  width: 92,
                  child: Text(
                    '${_pagadores.length} $unidad',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _boton(
                  Icons.add,
                  _pagadores.length < _maxPagadores ? _agregarPagador : null,
                ),
              ],
            ),
          ),
          if (!esIguales) ...[const SizedBox(height: 16), _seccionAsignacion()],
          const SizedBox(height: 16),
          _etiquetaSeccion('CÓMO PAGA CADA UNO'),
          const SizedBox(height: 8),
          for (var i = 0; i < _pagadores.length; i++)
            _tarjetaPagador(i, montos[i]),
          if (_admiteComprobante) ...[
            const SizedBox(height: 12),
            _etiquetaSeccion('COMPROBANTE DE CADA UNO'),
            const SizedBox(height: 8),
            for (var i = 0; i < _pagadores.length; i++)
              if (montos[i] > 0.005) _comprobanteDe(i, montos[i]),
            const SizedBox(height: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.receipt, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cuenta individual por pagador',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        'Al cobrar, se muestra una cuenta por cada uno.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSwitch(
                  value: _boletasIndividuales,
                  onChanged: (v) => setState(() => _boletasIndividuales = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.permiteVolver) ...[
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(volverAElegirPago),
                    icon: const Icon(LucideIcons.chevronLeft, size: 16),
                    label: const Text('Regresar'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: _valido && !_guardando && _comprobantesCompletos
                      ? _confirmar
                      : null,
                  icon: const Icon(LucideIcons.users, size: 18),
                  label: Text(
                    'Cobrar · S/ ${(_saldo + _recargoTotal + _propinaApp + _taperApp).toStringAsFixed(2)}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
