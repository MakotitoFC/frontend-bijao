import 'package:flutter/material.dart';

import '../data/cartas_store.dart';
import '../data/configuracion_store.dart';
import '../data/creditos_store.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';

// Reporta un problema con un plato ya pedido (devolución/reclamo): categoría,
// detalle del motivo, evidencia (opcional) y resolución. Cada resolución pide
// los datos que necesita (reemplazo, medio de devolución). Devuelve un
// ReporteProblema o null si se cancela.
class ReportarProblemaDialog extends StatefulWidget {
  final String nombrePlato;
  // Importe de la línea y cuánto de él ya está pagado (para reembolsos/cambios).
  final double precioLinea;
  final double pagadoLinea;
  final String? medioOriginalId;

  const ReportarProblemaDialog({
    super.key,
    required this.nombrePlato,
    this.precioLinea = 0,
    this.pagadoLinea = 0,
    this.medioOriginalId,
  });

  @override
  State<ReportarProblemaDialog> createState() => _ReportarProblemaDialogState();
}

class _ReportarProblemaDialogState extends State<ReportarProblemaDialog> {
  static const _otro = 'otro';
  static const _manual = 'manual';

  static const _categorias = [
    AppSelectItem(
      value: 'Producto en mal estado',
      label: 'Producto en mal estado',
    ),
    AppSelectItem(value: 'Pedido incorrecto', label: 'Pedido incorrecto'),
    AppSelectItem(value: 'Producto frío', label: 'Producto frío'),
    AppSelectItem(value: 'Demora excesiva', label: 'Demora excesiva'),
    AppSelectItem(value: 'Cliente canceló', label: 'Cliente canceló'),
    AppSelectItem(value: _otro, label: 'Otro'),
  ];

  static const _evidencias = [
    AppSelectItem<String?>(value: null, label: 'Sin evidencia'),
    AppSelectItem<String?>(value: 'Foto', label: 'Foto'),
    AppSelectItem<String?>(value: 'Boleta/Factura', label: 'Boleta/Factura'),
    AppSelectItem<String?>(value: _otro, label: 'Otro'),
  ];

  static const _resoluciones = [
    AppSelectItem(value: 'reembolso', label: 'Reembolso'),
    AppSelectItem(value: 'cambio', label: 'Cambio de producto'),
    AppSelectItem(value: 'nota_credito', label: 'Nota de crédito'),
    AppSelectItem(value: 'vale', label: 'Vale de consumo'),
    AppSelectItem(value: 'rechazado', label: 'Rechazado'),
  ];

  static const _explicaciones = {
    'reembolso': 'Se devuelve el dinero al cliente. Afecta caja o pasarela.',
    'cambio':
        'No se devuelve dinero. Se entrega otro producto; si hay diferencia '
        'de precio, se cobra o se devuelve.',
    'nota_credito':
        'No se devuelve efectivo. Se emite un documento que reduce la venta '
        'y genera saldo a favor.',
    'vale':
        'No se devuelve dinero. Se entrega un cupón canjeable por productos, '
        'con vigencia de $vigenciaValeDias días.',
    'rechazado': 'No se acepta la devolución. El pago se mantiene sin cambios.',
  };

  final _formKey = GlobalKey<FormState>();
  final _categoriaNuevaController = TextEditingController();
  final _detalleController = TextEditingController();
  final _evidenciaOtraController = TextEditingController();
  final _reemplazoNombreController = TextEditingController();
  final _reemplazoPrecioController = TextEditingController();
  String? _categoria;
  String? _evidencia;
  String? _resolucion;
  String? _reemplazo; // id de carta o _manual
  late String _medioReembolsoId =
      widget.medioOriginalId ?? mediosPagoActivos.first.id;
  bool _intentado = false;

  @override
  void dispose() {
    _categoriaNuevaController.dispose();
    _detalleController.dispose();
    _evidenciaOtraController.dispose();
    _reemplazoNombreController.dispose();
    _reemplazoPrecioController.dispose();
    super.dispose();
  }

  double get _precioReemplazo =>
      double.tryParse(
        _reemplazoPrecioController.text.trim().replaceAll(',', '.'),
      ) ??
      0;

  double get _diferencia => _precioReemplazo - widget.precioLinea;

  // ¿Se devolverá dinero? Reembolso con pago previo, o cambio más barato.
  bool get _devuelveDinero {
    if (widget.pagadoLinea <= 0) return false;
    if (_resolucion == 'reembolso') return true;
    return _resolucion == 'cambio' && _diferencia < -0.001;
  }

  void _elegirReemplazo(String? v) {
    setState(() {
      _reemplazo = v;
      final item = cartasNotifier.value.where((c) => c.id == v).firstOrNull;
      if (item != null) {
        _reemplazoNombreController.text = item.nombrePlato;
        _reemplazoPrecioController.text = (item.precioCliente ?? 0)
            .toStringAsFixed(2);
      } else if (v == _manual) {
        _reemplazoNombreController.clear();
        _reemplazoPrecioController.clear();
      }
    });
  }

  void _guardar() {
    setState(() => _intentado = true);
    if (!_formKey.currentState!.validate()) return;
    if (_categoria == null || _resolucion == null) return;
    if (_resolucion == 'cambio' && _reemplazo == null) return;
    final evidencia = _evidencia == _otro
        ? _evidenciaOtraController.text.trim()
        : _evidencia;
    final esCambio = _resolucion == 'cambio';
    Navigator.of(context).pop((
      categoria: _categoria == _otro
          ? _categoriaNuevaController.text.trim()
          : _categoria!,
      detalle: _detalleController.text.trim(),
      evidencia: evidencia,
      resolucion: _resolucion!,
      reemplazoNombre: esCambio ? _reemplazoNombreController.text.trim() : null,
      reemplazoPrecio: esCambio ? _precioReemplazo : null,
      reemplazoCartaId: esCambio && _reemplazo != _manual ? _reemplazo : null,
      medioReembolsoId: _devuelveDinero ? _medioReembolsoId : null,
    ));
  }

  Widget _errorSelect(String texto) => Padding(
    padding: const EdgeInsets.only(left: 4, top: 4),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 12, color: AppColors.error),
    ),
  );

  String? _requerido(String? v, String mensaje) =>
      (v == null || v.trim().isEmpty) ? mensaje : null;

  Widget _cajaInfo(String texto) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Text(
      texto,
      style: TextStyle(fontSize: 12, height: 1.35, color: Colors.grey.shade700),
    ),
  );

  Widget _bloqueCambio() {
    final cartas = cartasNotifier.value.where((c) => c.disponible).toList();
    final dif = _diferencia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        AppSelect<String>(
          label: 'Producto de reemplazo',
          value: _reemplazo,
          hint: 'Elige el producto que se entrega',
          items: [
            for (final c in cartas)
              AppSelectItem(value: c.id, label: c.nombrePlato),
            const AppSelectItem(value: _manual, label: 'Otro producto…'),
          ],
          onChanged: _elegirReemplazo,
        ),
        if (_intentado && _reemplazo == null)
          _errorSelect('Elige el producto de reemplazo'),
        if (_reemplazo != null) ...[
          if (_reemplazo == _manual) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _reemplazoNombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto',
              ),
              validator: (v) => _requerido(v, 'Escribe el nombre'),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _reemplazoPrecioController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Precio del reemplazo (S/)',
            ),
            validator: (v) =>
                _precioReemplazo <= 0 ? 'Ingresa el precio' : null,
          ),
          const SizedBox(height: 6),
          Text(
            dif > 0.001
                ? 'Diferencia a cobrar: S/ ${dif.toStringAsFixed(2)}'
                : (dif < -0.001
                      ? 'Diferencia a favor del cliente: S/ ${(-dif).toStringAsFixed(2)}'
                      : 'Sin diferencia de precio'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dif > 0.001 ? AppColors.error : AppColors.primaryGreenDark,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? anchoPantalla : 460,
          maxWidth: esMobile ? anchoPantalla : 460,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: _intentado
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              28,
              esMobile ? 28 : 22,
              28,
              28 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Reportar problema',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.nombrePlato,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppSelect<String>(
                  label: 'Categoría',
                  value: _categoria,
                  items: _categorias,
                  hint: 'Elige una categoría',
                  onChanged: (v) => setState(() => _categoria = v),
                ),
                if (_intentado && _categoria == null)
                  _errorSelect('Elige la categoría'),
                if (_categoria == _otro) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _categoriaNuevaController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nueva categoría',
                      hintText: 'Ej. Objeto extraño en el plato',
                    ),
                    validator: (v) => _requerido(v, 'Escribe la categoría'),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _detalleController,
                  minLines: 3,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'Detalle del motivo',
                    hintText:
                        'Describe qué ocurrió con el mayor detalle posible',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      _requerido(v, 'Ingresa el detalle del motivo'),
                ),
                const SizedBox(height: 16),
                AppSelect<String?>(
                  label: 'Evidencia (opcional)',
                  value: _evidencia,
                  items: _evidencias,
                  hint: 'Sin evidencia',
                  onChanged: (v) => setState(() => _evidencia = v),
                ),
                if (_evidencia == _otro) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _evidenciaOtraController,
                    decoration: const InputDecoration(
                      labelText: 'Otra evidencia',
                      hintText: 'Ej. Testigo, video de cámara',
                    ),
                    validator: (v) => _requerido(v, 'Describe la evidencia'),
                  ),
                ],
                const SizedBox(height: 16),
                AppSelect<String>(
                  label: 'Resolución',
                  value: _resolucion,
                  items: _resoluciones,
                  hint: 'Elige una resolución',
                  onChanged: (v) => setState(() => _resolucion = v),
                ),
                if (_intentado && _resolucion == null)
                  _errorSelect('Elige la resolución'),
                if (_resolucion != null)
                  _cajaInfo(_explicaciones[_resolucion]!),
                if (_resolucion == 'cambio') _bloqueCambio(),
                if (_devuelveDinero) ...[
                  const SizedBox(height: 14),
                  AppSelect<String>(
                    label: 'Devolver por',
                    value: _medioReembolsoId,
                    items: [
                      for (final m in mediosPagoActivos)
                        AppSelectItem(value: m.id, label: m.medioPago),
                    ],
                    onChanged: (v) => setState(
                      () => _medioReembolsoId = v ?? _medioReembolsoId,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _guardar,
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
