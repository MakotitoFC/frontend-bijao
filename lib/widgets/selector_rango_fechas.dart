import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';

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
String etiquetaRangoFechas(DateTimeRange? r, {String vacio = 'Todas las fechas'}) {
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
// fechas: accesos rápidos y un calendario donde se marca el inicio y el fin.
// Con [permiteTodas] se puede dejar sin filtro ("Todas las fechas").
class SelectorRangoFechas extends StatefulWidget {
  final DateTimeRange? valor;
  final ValueChanged<DateTimeRange?> onChanged;
  final bool permiteTodas;

  const SelectorRangoFechas({
    super.key,
    required this.valor,
    required this.onChanged,
    this.permiteTodas = false,
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
            targetAnchor: derecha ? Alignment.bottomRight : Alignment.bottomLeft,
            followerAnchor: derecha ? Alignment.topRight : Alignment.topLeft,
            offset: const Offset(0, 8),
            child: Align(
              alignment: derecha ? Alignment.topRight : Alignment.topLeft,
              child: _TarjetaRango(
                ancho: ancho,
                inicial: widget.valor,
                permiteTodas: widget.permiteTodas,
                onAplicar: (r) {
                  widget.onChanged(r);
                  _cerrar();
                },
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entrada!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _enlace,
      child: OutlinedButton.icon(
        onPressed: _abierto ? _cerrar : _abrir,
        icon: const Icon(LucideIcons.calendarDays, size: 16),
        label: Text(
          etiquetaRangoFechas(widget.valor),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: _abierto ? AppColors.primaryGreen : Colors.grey.shade300,
          ),
          minimumSize: const Size(0, AppSizes.boton - 6),
        ),
      ),
    );
  }
}

class _TarjetaRango extends StatefulWidget {
  final double ancho;
  final DateTimeRange? inicial;
  final bool permiteTodas;
  final ValueChanged<DateTimeRange?> onAplicar;

  const _TarjetaRango({
    required this.ancho,
    required this.inicial,
    required this.permiteTodas,
    required this.onAplicar,
  });

  @override
  State<_TarjetaRango> createState() => _TarjetaRangoState();
}

class _TarjetaRangoState extends State<_TarjetaRango> {
  late DateTime _mes;
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

  void _aplicarRapido(DateTime ini, DateTime fin) =>
      widget.onAplicar(DateTimeRange(start: ini, end: fin));

  void _tocarDia(DateTime d) => setState(() {
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
    final deshabilitado = d.isAfter(_hoy);
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

  Widget _calendario() {
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
    final esMesActual = _mes.year == _hoy.year && _mes.month == _hoy.month;
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
              child: Text(
                '${_mesesLargos[_mes.month - 1]} ${_mes.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    final hoy = _hoy;
    final ayer = hoy.subtract(const Duration(days: 1));
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
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _rapido('Hoy', () => _aplicarRapido(hoy, hoy)),
                _rapido('Ayer', () => _aplicarRapido(ayer, ayer)),
                _rapido(
                  'Últimos 7 días',
                  () => _aplicarRapido(
                    hoy.subtract(const Duration(days: 6)),
                    hoy,
                  ),
                ),
                _rapido(
                  'Este mes',
                  () => _aplicarRapido(DateTime(hoy.year, hoy.month), hoy),
                ),
                _rapido(
                  'Mes pasado',
                  () => _aplicarRapido(
                    DateTime(hoy.year, hoy.month - 1),
                    DateTime(hoy.year, hoy.month, 0),
                  ),
                ),
                if (widget.permiteTodas)
                  _rapido('Todas', () => widget.onAplicar(null)),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 6),
            _calendario(),
            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 10),
            Row(
              children: [
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
        ),
      ),
    );
  }
}
