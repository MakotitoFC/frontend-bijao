import 'package:flutter/material.dart';

import '../data/configuracion_store.dart';
import '../data/movimientos_caja_store.dart';
import '../models/medio_pago.dart';
import '../models/movimiento_caja.dart';
import 'app_select.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';

// Lo que se llena al registrar o editar un movimiento de caja.
typedef MovimientoNuevo = ({
  CategoriaMovimiento categoria,
  double monto,
  MedioPago medio,
  String? nota,
});

// Formulario simple de un ingreso o una salida: categoría, monto, medio de pago
// y una nota opcional. Con [existente] sirve para editar. Devuelve lo llenado o
// null si se cancela.
class MovimientoCajaDialog extends StatefulWidget {
  final TipoMovimiento tipo;
  final MovimientoCaja? existente;

  const MovimientoCajaDialog({super.key, required this.tipo, this.existente});

  @override
  State<MovimientoCajaDialog> createState() => _MovimientoCajaDialogState();
}

class _MovimientoCajaDialogState extends State<MovimientoCajaDialog> {
  late final List<CategoriaMovimiento> _categorias = categoriasDeTipo(
    widget.tipo,
  );
  late final List<MedioPago> _medios = mediosPagoActivos;
  CategoriaMovimiento? _categoria;
  MedioPago? _medio;
  late final _monto = TextEditingController(
    text: widget.existente?.monto.toStringAsFixed(2) ?? '',
  );
  late final _nota = TextEditingController(text: widget.existente?.nota ?? '');

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _categoria = _categorias.where((c) => c.id == e?.categoriaId).firstOrNull;
    _medio =
        _medios.where((m) => m.id == e?.medioPagoId).firstOrNull ??
        // Efectivo es lo más común en una salida o un ingreso de caja.
        _medios
            .where((m) => m.medioPago.toLowerCase() == 'efectivo')
            .firstOrNull ??
        _medios.firstOrNull;
  }

  @override
  void dispose() {
    _monto.dispose();
    _nota.dispose();
    super.dispose();
  }

  double get _valor =>
      double.tryParse(_monto.text.trim().replaceAll(',', '.')) ?? 0;

  bool get _completo => _categoria != null && _medio != null && _valor > 0;

  void _guardar() {
    if (!_completo) return;
    final nota = _nota.text.trim();
    Navigator.of(context).pop<MovimientoNuevo>((
      categoria: _categoria!,
      monto: double.parse(_valor.toStringAsFixed(2)),
      medio: _medio!,
      nota: nota.isEmpty ? null : nota,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.existente != null;
    final etiqueta = widget.tipo.etiqueta.toLowerCase();
    return DialogoApp(
      titulo: editando
          ? 'Editar $etiqueta'
          : 'Registrar ${widget.tipo == TipoMovimiento.egreso ? 'una' : 'un'} $etiqueta',
      ancho: 420,
      acciones: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _completo ? _guardar : null,
          child: Text(editando ? 'Guardar cambios' : 'Registrar'),
        ),
      ],
      children: [
        AppSelect<CategoriaMovimiento>(
          label: 'Categoría',
          value: _categoria,
          hint: 'Elige para qué fue',
          items: [
            for (final c in _categorias)
              AppSelectItem(value: c, label: c.nombre),
          ],
          onChanged: (c) => setState(() => _categoria = c),
        ),
        const SizedBox(height: 14),
        CampoTexto(
          controller: _monto,
          autofocus: !editando,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _guardar(),
          decoration: const InputDecoration(
            labelText: 'Monto (S/)',
            prefixText: 'S/ ',
          ),
        ),
        const SizedBox(height: 14),
        AppSelect<MedioPago>(
          label: 'Medio de pago',
          value: _medio,
          items: [
            for (final m in _medios)
              AppSelectItem(value: m, label: m.medioPago),
          ],
          onChanged: (m) => setState(() => _medio = m),
        ),
        const SizedBox(height: 14),
        CampoTexto(
          controller: _nota,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Nota (opcional)',
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// Pide el motivo para anular un movimiento. Devuelve el motivo o null.
class AnularMovimientoDialog extends StatefulWidget {
  final MovimientoCaja movimiento;

  const AnularMovimientoDialog({super.key, required this.movimiento});

  @override
  State<AnularMovimientoDialog> createState() => _AnularMovimientoDialogState();
}

class _AnularMovimientoDialogState extends State<AnularMovimientoDialog> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  bool get _valido => _motivo.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final m = widget.movimiento;
    return DialogoApp(
      titulo: 'Anular ${m.tipo.etiqueta.toLowerCase()}',
      ancho: 420,
      acciones: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: _valido
              ? () => Navigator.of(context).pop(_motivo.text.trim())
              : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          child: const Text('Anular'),
        ),
      ],
      children: [
        Text(
          '${m.categoriaNombre} · S/ ${m.monto.toStringAsFixed(2)}. Queda en la '
          'lista como anulado y deja de contar en los totales de la caja.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        CampoTexto(
          controller: _motivo,
          autofocus: true,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Motivo de la anulación',
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
