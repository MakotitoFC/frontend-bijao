import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/comprobante.dart';
import '../services/api_client.dart';
import '../services/facturacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/abrir_enlace.dart';
import '../utils/blur_dialog.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';

String _error(Object e) => e is ApiException
    ? e.message
    : e.toString().replaceFirst('Exception: ', '');

// Pide el motivo para anular un comprobante. Devuelve el motivo o null.
class _MotivoAnulacionDialog extends StatefulWidget {
  final Comprobante comprobante;
  const _MotivoAnulacionDialog({required this.comprobante});

  @override
  State<_MotivoAnulacionDialog> createState() => _MotivoAnulacionDialogState();
}

class _MotivoAnulacionDialogState extends State<_MotivoAnulacionDialog> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comprobante;
    return DialogoApp(
      titulo: 'Anular ${c.tipoEtiqueta.toLowerCase()}',
      ancho: 420,
      acciones: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: _motivo.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_motivo.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Anular'),
        ),
      ],
      children: [
        Text(
          '${c.numeroComprobante} · S/ ${c.total.toStringAsFixed(2)}. '
          '${c.esInterno ? 'Es un ticket interno: no se envía a SUNAT.' : 'Se envía la comunicación de baja a SUNAT.'}',
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

// Historial de comprobantes del día en Caja: estado ante SUNAT, PDF, reimprimir,
// consultar el estado de los pendientes y anular.
class ComprobantesCajaPanel extends StatefulWidget {
  const ComprobantesCajaPanel({super.key});

  @override
  State<ComprobantesCajaPanel> createState() => _ComprobantesCajaPanelState();
}

class _ComprobantesCajaPanelState extends State<ComprobantesCajaPanel> {
  List<Comprobante> _lista = const [];
  bool _cargando = true;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final hoy = DateTime.now();
      final lista = await FacturacionService.instance.listar(
        desde: hoy,
        hasta: hoy,
      );
      if (mounted) setState(() => _lista = lista);
    } catch (e) {
      if (mounted) setState(() => _errorCarga = _error(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _accion(Future<void> Function() hacer, String exito) async {
    try {
      await hacer();
      if (!mounted) return;
      showAppToast(context, exito, type: ToastType.success);
      await _cargar();
    } catch (e) {
      if (mounted) showAppToast(context, _error(e), type: ToastType.error);
    }
  }

  Future<void> _anular(Comprobante c) async {
    final motivo = await showBlurDialog<String>(
      context: context,
      builder: (_) => _MotivoAnulacionDialog(comprobante: c),
    );
    if (motivo == null) return;
    await _accion(
      () => FacturacionService.instance.anular(c.id, motivo: motivo),
      'Comprobante anulado.',
    );
  }

  Color _color(Comprobante c) {
    if (c.anulado || c.rechazado) return AppColors.error;
    if (c.pendiente) return AppColors.naranja;
    return AppColors.primaryGreen;
  }

  Widget _fila(Comprobante c) {
    final color = _color(c);
    final cliente = c.clienteDenominacion.isEmpty
        ? 'CLIENTES VARIOS'
        : c.clienteDenominacion;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c.numeroComprobante} · ${c.tipoEtiqueta}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration: c.anulado
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      '${c.horaEmision} · $cliente',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.tag),
                ),
                child: Text(
                  c.estadoEtiqueta,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'S/ ${c.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if ((c.mensaje ?? '').isNotEmpty && (c.rechazado || c.anulado))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                c.mensaje!,
                style: const TextStyle(fontSize: 11, color: AppColors.error),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              children: [
                if (c.pdfTicketUrl != null || c.pdfA4Url != null)
                  TextButton.icon(
                    onPressed: () => abrirEnlace(c.pdfTicketUrl ?? c.pdfA4Url!),
                    icon: const Icon(LucideIcons.fileText, size: 14),
                    label: const Text('PDF'),
                  ),
                if (c.puedeAnularse)
                  TextButton.icon(
                    onPressed: () => _accion(
                      () => FacturacionService.instance.reimprimir(c.id),
                      'Enviado a la impresora de caja.',
                    ),
                    icon: const Icon(LucideIcons.printer, size: 14),
                    label: const Text('Reimprimir'),
                  ),
                if (c.pendiente)
                  TextButton.icon(
                    onPressed: () => _accion(
                      () => FacturacionService.instance.consultarEstado(c.id),
                      'Estado consultado.',
                    ),
                    icon: const Icon(LucideIcons.refreshCw, size: 14),
                    label: const Text('Ver estado'),
                  ),
                if (c.puedeAnularse)
                  TextButton.icon(
                    onPressed: () => _anular(c),
                    icon: const Icon(LucideIcons.ban, size: 14),
                    label: const Text('Anular'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Comprobantes de hoy',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _cargando ? null : _cargar,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
              ),
            ],
          ),
          if (_errorCarga != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'No se pudieron leer los comprobantes: $_errorCarga',
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
          if (_cargando && _lista.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_lista.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aún no hay comprobantes emitidos hoy',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            // Se ven 5 comprobantes; el resto se desplaza.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 430),
              child: Scrollbar(
                child: ListView(
                  shrinkWrap: true,
                  children: [for (final c in _lista) _fila(c)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
