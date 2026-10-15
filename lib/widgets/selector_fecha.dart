import 'package:flutter/material.dart';

import 'app_select.dart';
import 'campo_texto.dart';

const _meses = [
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

// Fecha elegida con tres selectores (día, mes y año), cada uno con el mismo
// desplegable de la app. Con `permiteVacio` se puede dejar sin fecha ("Sin
// límite") y aparece una "x" para quitarla.
//
// Solo avisa con una fecha cuando están elegidos los tres datos.
class SelectorFecha extends StatefulWidget {
  final String etiqueta;
  final DateTime? valor;
  final ValueChanged<DateTime?> onChanged;
  final int anioMin;
  final int anioMax;
  final bool permiteVacio;

  const SelectorFecha({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.onChanged,
    required this.anioMin,
    required this.anioMax,
    this.permiteVacio = false,
  });

  @override
  State<SelectorFecha> createState() => _SelectorFechaState();
}

class _SelectorFechaState extends State<SelectorFecha> {
  int? _dia;
  int? _mes;
  int? _anio;

  @override
  void initState() {
    super.initState();
    _tomarDe(widget.valor);
  }

  @override
  void didUpdateWidget(covariant SelectorFecha old) {
    super.didUpdateWidget(old);
    // Si la fecha cambió desde fuera, se refleja; si el padre aún no recibió
    // una fecha completa, se conserva lo que el usuario fue eligiendo.
    if (widget.valor != old.valor && widget.valor != null) {
      _tomarDe(widget.valor);
    }
  }

  void _tomarDe(DateTime? d) {
    _dia = d?.day;
    _mes = d?.month;
    _anio = d?.year;
  }

  int _diasDelMes() {
    if (_mes == null) return 31;
    final anio = _anio ?? 2024; // año bisiesto: febrero con 29 hasta elegir año
    return DateTime(anio, _mes! + 1, 0).day;
  }

  void _avisar() {
    if (_dia == null || _mes == null || _anio == null) return;
    final dia = _dia! > _diasDelMes() ? _diasDelMes() : _dia!;
    _dia = dia;
    widget.onChanged(DateTime(_anio!, _mes!, dia));
  }

  @override
  Widget build(BuildContext context) {
    final anios = [
      for (var a = widget.anioMin; a <= widget.anioMax; a++) a,
      // Si el valor guardado cae fuera del rango, igual se puede ver.
      if (_anio != null && (_anio! < widget.anioMin || _anio! > widget.anioMax))
        _anio!,
    ];
    final hayAlgo = _dia != null || _mes != null || _anio != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.etiqueta,
          style: TextStyle(
            fontSize: CampoTexto.tamanoEtiqueta,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: AppSelect<int>(
                hint: 'Día',
                value: _dia,
                items: [
                  for (var d = 1; d <= _diasDelMes(); d++)
                    AppSelectItem(value: d, label: '$d'),
                ],
                onChanged: (v) {
                  setState(() => _dia = v);
                  _avisar();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: AppSelect<int>(
                hint: 'Mes',
                value: _mes,
                items: [
                  for (var m = 1; m <= 12; m++)
                    AppSelectItem(value: m, label: _meses[m - 1]),
                ],
                onChanged: (v) {
                  setState(() => _mes = v);
                  _avisar();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: AppSelect<int>(
                hint: 'Año',
                value: _anio,
                items: [
                  for (final a in anios) AppSelectItem(value: a, label: '$a'),
                ],
                onChanged: (v) {
                  setState(() => _anio = v);
                  _avisar();
                },
              ),
            ),
            if (widget.permiteVacio && hayAlgo) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Quitar fecha',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => _tomarDe(null));
                  widget.onChanged(null);
                },
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
