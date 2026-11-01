import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../services/api_client.dart';
import '../services/facturacion_service.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'config_widgets.dart';

// Vista de administración para datos fiscales de la Sede, % de IGV, Cajas y
// Series y Correlativos de comprobantes electrónicos (SUNAT).
class SedeFiscalConfig extends StatefulWidget {
  const SedeFiscalConfig({super.key});

  @override
  State<SedeFiscalConfig> createState() => _SedeFiscalConfigState();
}

class _SedeFiscalConfigState extends State<SedeFiscalConfig> {
  final _servicio = FacturacionService.instance;
  final _api = ApiClient.instance;

  final _ruc = TextEditingController();
  final _razon = TextEditingController();
  final _direccion = TextEditingController();
  final _celular = TextEditingController();
  final _codigoSerie = TextEditingController(text: '001');
  final _igv = TextEditingController();
  final _resolucion = TextEditingController();
  final _consultaUrl = TextEditingController();

  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  List<SerieCorrelativo> _series = [];
  List<Map<String, dynamic>> _cajas = [];

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  @override
  void dispose() {
    _ruc.dispose();
    _razon.dispose();
    _direccion.dispose();
    _celular.dispose();
    _codigoSerie.dispose();
    _igv.dispose();
    _resolucion.dispose();
    _consultaUrl.dispose();
    super.dispose();
  }

  String _mensaje(Object e) => e is ApiException
      ? e.message
      : e.toString().replaceFirst('Exception: ', '');

  String _formatearCodigoSerie(String raw) {
    final c = raw.trim().toUpperCase();
    if (c.isEmpty) return '001';
    if (c.length == 1) return '${c}01';
    if (c.length == 2) return '0$c';
    return c.substring(0, c.length > 3 ? 3 : c.length);
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final cfgFuture = _servicio.obtenerSedeConfig();
      final seriesFuture = _servicio.obtenerSeriesCorrelativos();
      final cajasFuture = _api.get('/api/v1/cajas');

      final r = await Future.wait([
        cfgFuture,
        seriesFuture,
        cajasFuture,
      ]);

      if (!mounted) return;
      final cfg = r[0] as SedeConfig;
      _series = r[1] as List<SerieCorrelativo>;
      if (r[2] is List) {
        _cajas = (r[2] as List).whereType<Map<String, dynamic>>().toList();
      }

      _ruc.text = cfg.ruc;
      _razon.text = cfg.razonSocial;
      _direccion.text = cfg.direccion;
      _celular.text = cfg.celular;
      _codigoSerie.text = _formatearCodigoSerie(cfg.codigoSerie);
      _igv.text = cfg.igvPorcentaje.toStringAsFixed(2);
      _resolucion.text = cfg.resolucionSunat;
      _consultaUrl.text = cfg.consultaSunatUrl;
    } catch (e) {
      _error = _mensaje(e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarSede() async {
    if (_ruc.text.trim().isEmpty || _razon.text.trim().isEmpty) {
      showAppToast(context, 'RUC y Razón Social son requeridos', type: ToastType.error);
      return;
    }

    final codSerieFormateado = _formatearCodigoSerie(_codigoSerie.text);
    final igvVal = double.tryParse(_igv.text.trim()) ?? 18.0;

    setState(() => _guardando = true);
    try {
      await _servicio.guardarSedeConfig({
        'ruc': _ruc.text.trim(),
        'razon_social': _razon.text.trim(),
        'direccion': _direccion.text.trim(),
        'celular': _celular.text.trim(),
        'codigo_serie': codSerieFormateado,
        'igv_porcentaje': igvVal,
        'resolucion_sunat': _resolucion.text.trim(),
        'consulta_sunat_url': _consultaUrl.text.trim(),
      });
      _codigoSerie.text = codSerieFormateado;
      if (mounted) {
        showAppToast(context, 'Configuración fiscal actualizada correctamente', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error al guardar: ${_mensaje(e)}', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _abrirDialogoNuevaSerie() {
    String tipoSeleccionado = 'boleta';
    final codSerie = _formatearCodigoSerie(_codigoSerie.text);
    final serieCtrl = TextEditingController(text: 'B$codSerie');
    final numCtrl = TextEditingController(text: '0');

    void recalcularSeriePorTipo(String tipo, StateSetter setModalState) {
      final prefijo = tipo == 'factura' ? 'F' : (tipo == 'boleta' ? 'B' : 'T');
      final sufijo = serieCtrl.text.length >= 4 ? serieCtrl.text.substring(1) : codSerie;
      setModalState(() {
        tipoSeleccionado = tipo;
        serieCtrl.text = '$prefijo$sufijo'.toUpperCase();
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(LucideIcons.filePlus, size: 20),
              SizedBox(width: 8),
              Text('Registrar Serie para Sede'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seleccione el tipo de comprobante. El 1° caracter se define por SUNAT '
                '(B: Boleta, F: Factura, T: Ticket) y los siguientes 3 caracteres corresponden a la sede.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              const Text('Tipo de Comprobante:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'boleta', label: Text('Boleta (B)')),
                  ButtonSegment(value: 'factura', label: Text('Factura (F)')),
                  ButtonSegment(value: 'ticket', label: Text('Ticket (T)')),
                ],
                selected: {tipoSeleccionado},
                onSelectionChanged: (val) {
                  if (val.isNotEmpty) {
                    recalcularSeriePorTipo(val.first, setModalState);
                  }
                },
              ),
              const SizedBox(height: 14),
              CampoTexto(
                controller: serieCtrl,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Serie Fiscal (4 caracteres)',
                  helperText: 'Ejemplos: B001, F001, T001, BA01, FA01',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              CampoTexto(
                controller: numCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Último Correlativo Emitido',
                  helperText: '0 si es una nueva serie que iniciará en el número 1',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final serie = serieCtrl.text.trim().toUpperCase();
                final val = int.tryParse(numCtrl.text.trim());
                if (serie.length != 4) {
                  showAppToast(context, 'La serie debe tener exactamente 4 caracteres', type: ToastType.error);
                  return;
                }
                if (val == null || val < 0) {
                  showAppToast(context, 'Ingrese un correlativo válido mayor o igual a 0', type: ToastType.error);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _servicio.actualizarSerieCorrelativo(serie, val, tipoDocumento: tipoSeleccionado);
                  if (mounted) {
                    showAppToast(context, 'Serie $serie registrada exitosamente', type: ToastType.success);
                  }
                  _cargarTodo();
                } catch (e) {
                  if (mounted) {
                    showAppToast(context, _mensaje(e), type: ToastType.error);
                  }
                }
              },
              child: const Text('Guardar Serie'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generarSeriesEstandar() async {
    final codSerie = _formatearCodigoSerie(_codigoSerie.text);
    setState(() => _guardando = true);
    try {
      await _servicio.actualizarSerieCorrelativo('B$codSerie', 0, tipoDocumento: 'boleta');
      await _servicio.actualizarSerieCorrelativo('F$codSerie', 0, tipoDocumento: 'factura');
      await _servicio.actualizarSerieCorrelativo('T$codSerie', 0, tipoDocumento: 'ticket');
      if (mounted) {
        showAppToast(context, 'Series estándar generadas: B$codSerie, F$codSerie, T$codSerie', type: ToastType.success);
      }
      await _cargarTodo();
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error al generar series: ${_mensaje(e)}', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _abrirDialogoCorrelativo(SerieCorrelativo s) {
    final numCtrl = TextEditingController(text: s.ultimoNumero.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modificar Serie ${s.serie}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo de Documento: ${s.tipoDocumento.toUpperCase()}'),
            const SizedBox(height: 12),
            CampoTexto(
              controller: numCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Último Correlativo Emitido',
                helperText: 'El próximo comprobante sumará +1 a este valor',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final val = int.tryParse(numCtrl.text.trim());
              if (val == null || val < 0) {
                showAppToast(context, 'Ingrese un número válido', type: ToastType.error);
                return;
              }
              Navigator.pop(ctx);
              try {
                await _servicio.actualizarSerieCorrelativo(s.serie, val, tipoDocumento: s.tipoDocumento);
                if (mounted) {
                  showAppToast(context, 'Correlativo de ${s.serie} actualizado a $val', type: ToastType.success);
                }
                _cargarTodo();
              } catch (e) {
                if (mounted) {
                  showAppToast(context, _mensaje(e), type: ToastType.error);
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _cargarTodo,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Datos Fiscales de la Sede
          SeccionConfig(
            titulo: 'Datos Fiscales y SUNAT de la Sede',
            descripcion: 'Configuración de razón social, RUC, dirección fiscal y tasa de IGV oficial.',
            filas: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: CampoTextoConfig(
                            etiqueta: 'RUC de la Empresa',
                            valor: _ruc.text,
                            onChanged: (v) => _ruc.text = v,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: CampoTextoConfig(
                            etiqueta: '% IGV Actual',
                            valor: _igv.text,
                            onChanged: (v) => _igv.text = v,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: CampoTextoConfig(
                            etiqueta: 'Código Serie Sede (3 carácteres)',
                            valor: _codigoSerie.text,
                            onChanged: (v) {
                              setState(() {
                                _codigoSerie.text = v.toUpperCase();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Series generadas para SUNAT (4 caracteres):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Chip(
                                      label: Text('Boleta: B${_formatearCodigoSerie(_codigoSerie.text)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.green.shade50,
                                    ),
                                    const SizedBox(width: 6),
                                    Chip(
                                      label: Text('Factura: F${_formatearCodigoSerie(_codigoSerie.text)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.blue.shade50,
                                    ),
                                    const SizedBox(width: 6),
                                    Chip(
                                      label: Text('Ticket: T${_formatearCodigoSerie(_codigoSerie.text)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.orange.shade50,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CampoTextoConfig(
                      etiqueta: 'Razón Social Fiscal',
                      valor: _razon.text,
                      onChanged: (v) => _razon.text = v,
                    ),
                    const SizedBox(height: 12),
                    CampoTextoConfig(
                      etiqueta: 'Dirección Fiscal',
                      valor: _direccion.text,
                      onChanged: (v) => _direccion.text = v,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CampoTextoConfig(
                            etiqueta: 'Teléfono / Celular de Contacto',
                            valor: _celular.text,
                            onChanged: (v) => _celular.text = v,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CampoTextoConfig(
                      etiqueta: 'Resolución de Autorización SUNAT',
                      valor: _resolucion.text,
                      onChanged: (v) => _resolucion.text = v,
                    ),
                    const SizedBox(height: 12),
                    CampoTextoConfig(
                      etiqueta: 'URL de Consulta de Validez SUNAT',
                      valor: _consultaUrl.text,
                      onChanged: (v) => _consultaUrl.text = v,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _guardando ? null : _guardarSede,
                        icon: _guardando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(LucideIcons.save, size: 16),
                        label: Text(_guardando ? 'Guardando...' : 'Guardar Datos Fiscales'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 2. Series y Correlativos de Comprobantes
          SeccionConfig(
            titulo: 'Series y Correlativos de Comprobantes',
            descripcion: 'Control y sincronización de numeraciones atómicas para Boletas, Facturas y Tickets.',
            filas: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _abrirDialogoNuevaSerie,
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Registrar Nueva Serie'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _guardando ? null : _generarSeriesEstandar,
                      icon: const Icon(LucideIcons.wand2, size: 16),
                      label: const Text('Generar Series de Sede (B/F/T)'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_series.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No hay series configuradas para esta sede.', style: TextStyle(color: Colors.grey)),
                )
              else
                for (final s in _series)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: s.tipoDocumento == 'factura'
                          ? Colors.blue.shade100
                          : (s.tipoDocumento == 'boleta' ? Colors.green.shade100 : Colors.orange.shade100),
                      child: Icon(
                        LucideIcons.fileText,
                        size: 20,
                        color: s.tipoDocumento == 'factura'
                            ? Colors.blue.shade800
                            : (s.tipoDocumento == 'boleta' ? Colors.green.shade800 : Colors.orange.shade800),
                      ),
                    ),
                    title: Text(
                      '${s.tipoDocumento.toUpperCase()} - SERIE: ${s.serie}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Último correlativo: ${s.ultimoNumero} (Siguiente: ${s.serie}-${(s.ultimoNumero + 1).toString().padLeft(8, '0')})',
                    ),
                    trailing: OutlinedButton.icon(
                      onPressed: () => _abrirDialogoCorrelativo(s),
                      icon: const Icon(LucideIcons.pencil, size: 14),
                      label: const Text('Modificar'),
                    ),
                  ),
            ],
          ),

          const SizedBox(height: 20),

          // 3. Cajas Físicas Registradas
          SeccionConfig(
            titulo: 'Cajas Físicas de la Sede',
            descripcion: 'Puntos de cobro y terminales registrados en el establecimiento.',
            filas: [
              if (_cajas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No hay cajas registradas.', style: TextStyle(color: Colors.grey)),
                )
              else
                for (final c in _cajas)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: const CircleAvatar(
                      backgroundColor: Colors.purple,
                      child: Icon(LucideIcons.store, size: 18, color: Colors.white),
                    ),
                    title: Text(
                      c['nombre']?.toString() ?? 'Caja',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Serie Boleta: ${c['serie_boleta'] ?? 'BA01'} | Serie Factura: ${c['serie_factura'] ?? 'FA01'} | Serie Ticket: ${c['serie_ticket'] ?? 'TA01'}',
                    ),
                    trailing: Chip(
                      label: Text(
                        (c['activa'] == true || c['estado'] == true) ? 'ACTIVA' : 'INACTIVA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: (c['activa'] == true || c['estado'] == true) ? Colors.green.shade800 : Colors.grey,
                        ),
                      ),
                      backgroundColor: (c['activa'] == true || c['estado'] == true) ? Colors.green.shade50 : Colors.grey.shade100,
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
