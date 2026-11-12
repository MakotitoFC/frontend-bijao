import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';
import 'dialogo_app.dart' show LimiteModal;

const _mesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];
const _mesesLargos = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];
const _diasSemana = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

DateTime _soloDia(DateTime d) => DateUtils.dateOnly(d);

// Texto corto del rango para el botón: "Hoy", "Ayer", "20 oct 2026" o
// "20 oct – 21 oct 2026".
String etiquetaRangoFechas(
  DateTimeRange? r, {
  String vacio = 'Todas las fechas',
}) {
  if (r == null) return vacio;
  final hoy = _soloDia(DateTime.now());
  final ini = _soloDia(r.start);
  final fin = _soloDia(r.end);
  String dia(DateTime d, {bool anio = true}) =>
      '${d.day} ${_mesesCortos[d.month - 1]}${anio ? ' ${d.year}' : ''}';
  if (ini == fin) {
    if (ini == hoy) return 'Hoy';
    if (ini == hoy.subtract(const Duration(days: 1))) return 'Ayer';
    return dia(ini);
  }
  return ini.year == fin.year
      ? '${dia(ini, anio: false)} – ${dia(fin)}'
      : '${dia(ini)} – ${dia(fin)}';
}

// Botón que abre una tarjeta flotante (no un modal) para elegir un rango de
// fechas: un calendario donde se marca el inicio y el fin (y, al lado, un
// botón "Hoy").
// Con [permiteTodas] se puede dejar sin filtro ("Todas las fechas").
class SelectorRangoFechas extends StatefulWidget {
  final DateTimeRange? valor;
  final ValueChanged<DateTimeRange?> onChanged;
  final bool permiteTodas;
  // Texto del botón cuando no hay fechas.
  final String textoVacio;
  // Texto de la opción que quita las fechas.
  final String textoTodas;
  // Con false no salen los accesos rápidos (Hoy, Ayer…): solo el calendario.
  final bool conAtajos;
  // Con true, de los accesos rápidos solo sale "Hoy".
  final bool soloHoy;
  // Con true se pueden elegir fechas futuras (por ejemplo, la vigencia de una
  // promoción).
  final bool permiteFuturo;
  // Con true se elige un solo día: al tocar un día queda aplicado, sin "Aplicar".
  final bool soloDia;

  const SelectorRangoFechas({
    super.key,
    required this.valor,
    required this.onChanged,
    this.permiteTodas = false,
    this.textoVacio = 'Todas las fechas',
    this.textoTodas = 'Todas',
    this.conAtajos = true,
    this.soloHoy = false,
    this.permiteFuturo = false,
    this.soloDia = false,
  });

  @override
  State<SelectorRangoFechas> createState() => _SelectorRangoFechasState();
}

class _SelectorRangoFechasState extends State<SelectorRangoFechas> {
  final LayerLink _enlace = LayerLink();
  OverlayEntry? _entrada;

  bool get _abierto => _entrada != null;

  @override
  void dispose() {
    _entrada?.remove();
    _entrada = null;
    super.dispose();
  }

  void _cerrar() {
    _entrada?.remove();
    _entrada = null;
    if (mounted) setState(() {});
  }

  void _abrir() {
    final caja = context.findRenderObject() as RenderBox;
    final posicion = caja.localToGlobal(Offset.zero);
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    final ancho = anchoPantalla - 24 < 340 ? anchoPantalla - 24 : 340.0;
    // Se alinea al borde derecho del botón salvo que se salga de la pantalla.
    final derecha = posicion.dx + caja.size.width - ancho >= 12;
    // Dentro de un modal el calendario no se pasa del borde inferior del modal:
    // si no cabe debajo del botón, se sube hasta que su base quede en ese límite
    // (sin salirse de la pantalla). Fuera de un modal, el límite es la pantalla.
    final pantalla = Offset.zero & MediaQuery.sizeOf(context);
    final limite = LimiteModal.rectDe(context) ?? pantalla;
    const altoTarjeta = 440.0;
    const margen = 8.0;
    final debajo = posicion.dy + caja.size.height + margen;
    final tope = limite.bottom < pantalla.bottom
        ? limite.bottom
        : pantalla.bottom - margen;
    final cabe = debajo + altoTarjeta <= tope;
    final inicio = cabe
        ? debajo
        : (tope - altoTarjeta).clamp(pantalla.top + margen, debajo);
    final desplazamientoY = inicio - (posicion.dy + caja.size.height);
    final disponible = (tope - inicio).clamp(200.0, 2000.0);
    _entrada = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _cerrar,
            ),
          ),
          CompositedTransformFollower(
            link: _enlace,
            showWhenUnlinked: false,
            targetAnchor: derecha
                ? Alignment.bottomRight
                : Alignment.bottomLeft,
            followerAnchor: derecha ? Alignment.topRight : Alignment.topLeft,
            offset: Offset(0, desplazamientoY),
            child: Align(
              alignment: derecha ? Alignment.topRight : Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: disponible),
                child: SingleChildScrollView(
                  child: _TarjetaRango(
                    ancho: ancho,
                    inicial: widget.valor,
                    permiteTodas: widget.permiteTodas,
                    textoTodas: widget.textoTodas,
                    conAtajos: widget.conAtajos,
                    soloHoy: widget.soloHoy,
                    permiteFuturo: widget.permiteFuturo,
                    soloDia: widget.soloDia,
                    onAplicar: (r) {
                      widget.onChanged(r);
                      _cerrar();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entrada!);
    setState(() {});
  }

  // "Hoy" va como un botón aparte, al lado del selector y no dentro del
  // calendario.
  Widget _botonHoy() {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final v = widget.valor;
    final activo =
        v != null &&
        DateUtils.dateOnly(v.start) == hoy &&
        DateUtils.dateOnly(v.end) == hoy;
    return OutlinedButton(
      onPressed: () {
        if (_abierto) _cerrar();
        widget.onChanged(DateTimeRange(start: hoy, end: hoy));
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: activo ? AppColors.primaryGreen : Colors.black87,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: activo ? AppColors.primaryGreen : Colors.grey.shade300,
        ),
        minimumSize: const Size(0, AppSizes.control),
      ),
      child: const Text(
        'Hoy',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selector = _selector();
    if (!widget.conAtajos) return selector;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: selector),
        const SizedBox(width: 6),
        _botonHoy(),
      ],
    );
  }

  Widget _selector() {
    return CompositedTransformTarget(
      link: _enlace,
      child: OutlinedButton.icon(
        onPressed: _abierto ? _cerrar : _abrir,
        icon: const Icon(LucideIcons.calendarDays, size: 16),
        label: Text(
          etiquetaRangoFechas(widget.valor, vacio: widget.textoVacio),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: _abierto ? AppColors.primaryGreen : Colors.grey.shade300,
          ),
          minimumSize: const Size(0, AppSizes.control),
        ),
      ),
    );
  }
}

class _TarjetaRango extends StatefulWidget {
  final double ancho;
  final DateTimeRange? inicial;
  final bool permiteTodas;
  final String textoTodas;
  final bool conAtajos;
  final bool soloHoy;
  final bool permiteFuturo;
  final bool soloDia;
  final ValueChanged<DateTimeRange?> onAplicar;

  const _TarjetaRango({
    required this.ancho,
    required this.inicial,
    required this.permiteTodas,
    required this.textoTodas,
    required this.conAtajos,
    required this.soloHoy,
    required this.permiteFuturo,
    required this.soloDia,
    required this.onAplicar,
  });

  @override
  State<_TarjetaRango> createState() => _TarjetaRangoState();
}

enum _VistaCalendario { dias, meses, anios }

class _TarjetaRangoState extends State<_TarjetaRango> {
  late DateTime _mes;
  _VistaCalendario _vista = _VistaCalendario.dias;
  // Primer año de la página de años que se muestra (12 por página).
  int _paginaAnios = 0;
  DateTime? _inicio;
  DateTime? _fin;

  DateTime get _hoy => _soloDia(DateTime.now());

  @override
  void initState() {
    super.initState();
    _inicio = widget.inicial == null ? null : _soloDia(widget.inicial!.start);
    _fin = widget.inicial == null ? null : _soloDia(widget.inicial!.end);
    final base = _fin ?? _hoy;
    _mes = DateTime(base.year, base.month);
  }

  void _tocarDia(DateTime d) {
    if (widget.soloDia) {
      widget.onAplicar(DateTimeRange(start: d, end: d));
      return;
    }
    _elegirDia(d);
  }

  void _elegirDia(DateTime d) => setState(() {
    if (_inicio == null || _fin != null) {
      _inicio = d;
      _fin = null;
    } else if (d.isBefore(_inicio!)) {
      _inicio = d;
    } else {
      _fin = d;
    }
  });

  void _aplicar() {
    final ini = _inicio;
    if (ini == null) return;
    widget.onAplicar(DateTimeRange(start: ini, end: _fin ?? ini));
  }

  Widget _rapido(String texto, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _celdaDia(DateTime d) {
    final deshabilitado = !widget.permiteFuturo && d.isAfter(_hoy);
    final esInicio = _inicio != null && d == _inicio;
    final esFin = _fin != null && d == _fin;
    final dentro =
        _inicio != null &&
        _fin != null &&
        d.isAfter(_inicio!) &&
        d.isBefore(_fin!);
    final marcado = esInicio || esFin;
    final unSoloDia = _inicio != null && _fin == null;
    return GestureDetector(
      onTap: deshabilitado ? null : () => _tocarDia(d),
      child: Container(
        height: 36,
        // La franja del rango une los extremos.
        decoration: BoxDecoration(
          color: (dentro || (marcado && _fin != null && _inicio != _fin))
              ? AppColors.primaryGreen.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(esInicio ? 18 : 0),
            right: Radius.circular(esFin || (esInicio && unSoloDia) ? 18 : 0),
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: marcado ? AppColors.primaryGreen : Colors.transparent,
            shape: BoxShape.circle,
            border: !marcado && d == _hoy
                ? Border.all(color: AppColors.primaryGreen)
                : null,
          ),
          child: Text(
            '${d.day}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: marcado ? FontWeight.w700 : FontWeight.w500,
              color: marcado
                  ? Colors.white
                  : (deshabilitado ? Colors.grey.shade400 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  // Día, mes y año: el título abre la elección de mes y de año.
  Widget _calendario() => switch (_vista) {
    _VistaCalendario.dias => _vistaDias(),
    _VistaCalendario.meses => _vistaMeses(),
    _VistaCalendario.anios => _vistaAnios(),
  };

  Widget _vistaDias() {
    final primero = DateTime(_mes.year, _mes.month);
    final huecos = primero.weekday - 1; // la semana empieza en lunes
    final dias = DateUtils.getDaysInMonth(_mes.year, _mes.month);
    final celdas = <Widget>[
      for (var i = 0; i < huecos; i++) const SizedBox(height: 36),
      for (var d = 1; d <= dias; d++)
        _celdaDia(DateTime(_mes.year, _mes.month, d)),
    ];
    while (celdas.length % 7 != 0) {
      celdas.add(const SizedBox(height: 36));
    }
    final esMesActual =
        !widget.permiteFuturo &&
        _mes.year == _hoy.year &&
        _mes.month == _hoy.month;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  setState(() => _mes = DateTime(_mes.year, _mes.month - 1)),
              icon: const Icon(Icons.chevron_left, size: 22),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _vista = _VistaCalendario.meses),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_mesesLargos[_mes.month - 1]} ${_mes.year}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: esMesActual
                  ? null
                  : () => setState(
                      () => _mes = DateTime(_mes.year, _mes.month + 1),
                    ),
              icon: const Icon(Icons.chevron_right, size: 22),
            ),
          ],
        ),
        Row(
          children: [
            for (final s in _diasSemana)
              Expanded(
                child: Center(
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < celdas.length; i += 7)
          Row(
            children: [
              for (var j = i; j < i + 7; j++) Expanded(child: celdas[j]),
            ],
          ),
      ],
    );
  }

  // Cuadrícula de 4 filas × 3 columnas con una opción elegible por celda.
  Widget _cuadricula(List<Widget> celdas) => Column(
    children: [
      for (var i = 0; i < celdas.length; i += 3)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              for (var j = i; j < i + 3; j++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: celdas[j],
                  ),
                ),
            ],
          ),
        ),
    ],
  );

  Widget _opcionCuadricula(
    String texto, {
    required bool elegida,
    required bool deshabilitada,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: deshabilitada ? null : onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: elegida ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: elegida ? AppColors.primaryGreen : Colors.grey.shade300,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: elegida ? FontWeight.w800 : FontWeight.w600,
            color: elegida
                ? Colors.white
                : (deshabilitada ? Colors.grey.shade400 : Colors.black87),
          ),
        ),
      ),
    );
  }

  // Elegir el mes (y, con el título, el año).
  Widget _vistaMeses() {
    final anio = _mes.year;
    final puedeSiguiente = widget.permiteFuturo || anio < _hoy.year;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  setState(() => _mes = DateTime(anio - 1, _mes.month)),
              icon: const Icon(Icons.chevron_left, size: 22),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() {
                  _paginaAnios = anio - 5;
                  _vista = _VistaCalendario.anios;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$anio',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: puedeSiguiente
                  ? () => setState(() => _mes = DateTime(anio + 1, _mes.month))
                  : null,
              icon: const Icon(Icons.chevron_right, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _cuadricula([
          for (var m = 1; m <= 12; m++)
            _opcionCuadricula(
              _mesesCortos[m - 1],
              elegida: m == _mes.month,
              deshabilitada:
                  !widget.permiteFuturo &&
                  DateTime(anio, m).isAfter(DateTime(_hoy.year, _hoy.month)),
              onTap: () => setState(() {
                _mes = DateTime(anio, m);
                _vista = _VistaCalendario.dias;
              }),
            ),
        ]),
        TextButton(
          onPressed: () => setState(() => _vista = _VistaCalendario.dias),
          child: const Text('Volver a los días'),
        ),
      ],
    );
  }

  // Elegir el año (12 por página).
  Widget _vistaAnios() {
    final fin = _paginaAnios + 11;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _paginaAnios -= 12),
              icon: const Icon(Icons.chevron_left, size: 22),
            ),
            Expanded(
              child: Text(
                '$_paginaAnios – $fin',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: (widget.permiteFuturo || fin < _hoy.year)
                  ? () => setState(() => _paginaAnios += 12)
                  : null,
              icon: const Icon(Icons.chevron_right, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _cuadricula([
          for (var y = _paginaAnios; y <= fin; y++)
            _opcionCuadricula(
              '$y',
              elegida: y == _mes.year,
              deshabilitada: !widget.permiteFuturo && y > _hoy.year,
              onTap: () => setState(() {
                _mes = DateTime(y, _mes.month);
                _vista = _VistaCalendario.meses;
              }),
            ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final seleccion = _inicio == null
        ? 'Elige el día de inicio'
        : etiquetaRangoFechas(
            DateTimeRange(start: _inicio!, end: _fin ?? _inicio!),
          );
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: widget.ancho,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _calendario(),
            if (!widget.soloDia) ...[
              const SizedBox(height: 8),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Quitar las fechas (solo donde se permite) sigue disponible.
                  if (widget.permiteTodas) ...[
                    _rapido(widget.textoTodas, () => widget.onAplicar(null)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      seleccion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _inicio == null ? null : _aplicar,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: const Text('Aplicar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
