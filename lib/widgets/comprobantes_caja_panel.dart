import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/cierres_store.dart';
import '../models/comprobante.dart';
import '../services/api_client.dart';
import '../services/facturacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/abrir_enlace.dart';
import '../utils/blur_dialog.dart';
import 'app_select.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';
import 'lista_paginada.dart';

String _error(Object e) => e is ApiException
    ? e.message
    : e.toString().replaceFirst('Exception: ', '');

class _ResultadoAnulacion {
  final bool esNotaCredito;
  final String codigo;
  final String motivo;
  const _ResultadoAnulacion({
    required this.esNotaCredito,
    required this.codigo,
    required this.motivo,
  });
}

// Pide el motivo para anular un comprobante o emitir nota de crédito.
class _MotivoAnulacionDialog extends StatefulWidget {
  final Comprobante comprobante;
  const _MotivoAnulacionDialog({required this.comprobante});

  @override
  State<_MotivoAnulacionDialog> createState() => _MotivoAnulacionDialogState();
}

class _MotivoAnulacionDialogState extends State<_MotivoAnulacionDialog> {
  String _tipoAccion = 'nota_credito';
  String _codigoMotivo = '01';
  final _motivo = TextEditingController(text: 'ANULACION DE LA OPERACION');

  @override
  void initState() {
    super.initState();
    if (widget.comprobante.esInterno) {
      _tipoAccion = 'baja';
      _motivo.text = 'Ticket interno anulado manualmente';
    }
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comprobante;
    final esNota = !c.esInterno && _tipoAccion == 'nota_credito';

    return DialogoApp(
      titulo: c.esInterno ? 'Anular ticket interno' : 'Anulación / Nota de Crédito',
      ancho: 480,
      acciones: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: _motivo.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    _ResultadoAnulacion(
                      esNotaCredito: esNota,
                      codigo: _codigoMotivo,
                      motivo: _motivo.text.trim(),
                    ),
                  ),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: Text(esNota ? 'Emitir Nota de Crédito' : 'Anular'),
        ),
      ],
      children: [
        Text(
          '${c.numeroComprobante} · S/ ${c.total.toStringAsFixed(2)}. '
          '${c.esInterno ? 'Es un ticket interno: no se envía a SUNAT.' : 'Comprobante fiscal ante SUNAT.'}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        if (!c.esInterno) ...[
          const Text(
            'Mecanismo de anulación:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text('Nota de Crédito (07)', style: TextStyle(fontSize: 12)),
                  ),
                  selected: _tipoAccion == 'nota_credito',
                  onSelected: (sel) {
                    if (sel) setState(() => _tipoAccion = 'nota_credito');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text('Baja / Anulación', style: TextStyle(fontSize: 12)),
                  ),
                  selected: _tipoAccion == 'baja',
                  onSelected: (sel) {
                    if (sel) setState(() => _tipoAccion = 'baja');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_tipoAccion == 'nota_credito') ...[
            const Text(
              'Motivo SUNAT (Catálogo 09):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _codigoMotivo,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: '01',
                      child: Text('01 — Anulación de la operación'),
                    ),
                    DropdownMenuItem(
                      value: '02',
                      child: Text('02 — Anulación por error en RUC/DNI'),
                    ),
                    DropdownMenuItem(
                      value: '03',
                      child: Text('03 — Corrección por error en descripción'),
                    ),
                    DropdownMenuItem(
                      value: '07',
                      child: Text('07 — Devolución total'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _codigoMotivo = val;
                        switch (val) {
                          case '01':
                            _motivo.text = 'ANULACION DE LA OPERACION';
                            break;
                          case '02':
                            _motivo.text = 'ANULACION POR ERROR EN EL RUC / DNI';
                            break;
                          case '03':
                            _motivo.text = 'CORRECCION POR ERROR EN LA DESCRIPCION';
                            break;
                          case '07':
                            _motivo.text = 'DEVOLUCION TOTAL';
                            break;
                        }
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
        CampoTexto(
          controller: _motivo,
          autofocus: true,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Descripción / Motivo',
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

// Última lista leída: al volver a la vista se muestra al instante y se
// actualiza por detrás.
List<Comprobante>? _cacheComprobantes;

// Comprobantes de hoy dentro del turno actual.
Future<List<Comprobante>> _leerComprobantesDeHoy() async {
  if (estadoCajaServidor != null && !estadoCajaServidor!.abierta) {
    return const [];
  }
  final hoy = DateTime.now();
  final lista = await FacturacionService.instance.listar(
    desde: hoy,
    hasta: hoy,
  );
  final desdeTurno = inicioCajaActual;
  return lista.where((c) {
    final fh = c.fechaHora;
    if (fh == null) return true;
    return !fh.isBefore(desdeTurno);
  }).toList();
}

// Lee la lista de antemano para que la vista abra sin espera.
Future<void> precargarComprobantesCaja() async {
  try {
    _cacheComprobantes = await _leerComprobantesDeHoy();
  } catch (_) {}
}

class _ComprobantesCajaPanelState extends State<ComprobantesCajaPanel> {
  List<Comprobante> _lista = _cacheComprobantes ?? const [];
  bool _cargando = _cacheComprobantes == null;
  String? _errorCarga;
  // Tipo de comprobante elegido para filtrar la lista (null = todos).
  String? _tipoFiltro;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    // Con una lista ya en pantalla se actualiza sin tapar nada.
    if (_cacheComprobantes == null) {
      setState(() {
        _cargando = true;
        _errorCarga = null;
      });
    }
    try {
      final lista = await _leerComprobantesDeHoy();
      _cacheComprobantes = lista;
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
    final res = await showBlurDialog<_ResultadoAnulacion>(
      context: context,
      builder: (_) => _MotivoAnulacionDialog(comprobante: c),
    );
    if (res == null) return;
    if (res.esNotaCredito) {
      await _accion(
        () => FacturacionService.instance.emitirNotaCredito(
          c.id,
          motivoCodigo: res.codigo,
          motivoDescripcion: res.motivo,
        ),
        'Nota de Crédito emitida y comprobante anulado.',
      );
    } else {
      await _accion(
        () => FacturacionService.instance.anular(c.id, motivo: res.motivo),
        'Comprobante anulado ante SUNAT.',
      );
    }
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
                if (c.ticketUrl != null)
                  TextButton.icon(
                    onPressed: () => abrirEnlace(c.ticketUrl!),
                    icon: const Icon(LucideIcons.fileText, size: 14),
                    label: const Text('Ticket'),
                  ),
                if (c.a4Url != null)
                  TextButton.icon(
                    onPressed: () => abrirEnlace(c.a4Url!),
                    icon: const Icon(LucideIcons.fileText, size: 14),
                    label: const Text('PDF A4'),
                  ),
                if (c.xmlDescargaUrl != null)
                  TextButton.icon(
                    onPressed: () => abrirEnlace(c.xmlDescargaUrl!),
                    icon: const Icon(LucideIcons.code, size: 14),
                    label: const Text('XML'),
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
    final tipos = {for (final c in _lista) c.tipoEtiqueta}.toList()..sort();
    final visibles = _tipoFiltro == null
        ? _lista
        : [
            for (final c in _lista)
              if (c.tipoEtiqueta == _tipoFiltro) c,
          ];
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
            ],
          ),
          if (_lista.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 240,
                  child: AppSelect<String>(
                    compacto: true,
                    value: _tipoFiltro ?? '',
                    hint: 'Todos los comprobantes',
                    items: [
                      const AppSelectItem(
                        value: '',
                        label: 'Todos los comprobantes',
                      ),
                      for (final t in tipos) AppSelectItem(value: t, label: t),
                    ],
                    onChanged: (v) => setState(
                      () => _tipoFiltro = (v == null || v.isEmpty) ? null : v,
                    ),
                  ),
                ),
              ),
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
            // De 5 en 5, con las flechas para pasar de página.
            ListaPaginada<Comprobante>(
              items: visibles,
              reiniciarCon: _tipoFiltro,
              itemBuilder: _fila,
            ),
        ],
      ),
    );
  }
}
