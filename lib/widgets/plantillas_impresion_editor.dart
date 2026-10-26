import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/plantilla_impresion.dart';
import '../services/impresion_service.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'app_toast.dart';
import 'campo_texto.dart';

class PlantillasImpresionEditor extends StatefulWidget {
  const PlantillasImpresionEditor({super.key});

  @override
  State<PlantillasImpresionEditor> createState() => _PlantillasImpresionEditorState();
}

class _PlantillasImpresionEditorState extends State<PlantillasImpresionEditor> {
  final _servicio = ImpresionService.instance;

  final List<Map<String, String>> _tiposDocumento = [
    {'tipo': 'COMANDA_COCINA', 'nombre': 'Comanda Cocina'},
    {'tipo': 'TICKET_VENTA', 'nombre': 'Ticket de Venta'},
    {'tipo': 'BOLETA_ELECTRONICA', 'nombre': 'Boleta Electrónica'},
    {'tipo': 'FACTURA_ELECTRONICA', 'nombre': 'Factura Electrónica'},
    {'tipo': 'CUENTA_CONSUMO', 'nombre': 'Cuenta de Consumo'},
  ];

  String _tipoSeleccionado = 'COMANDA_COCINA';
  PlantillaImpresion? _plantillaActual;
  bool _cargando = true;
  bool _guardando = false;

  // Controladores de texto
  final _nombreCtrl = TextEditingController();
  final _encabezadoCtrl = TextEditingController();
  final _pieCtrl = TextEditingController();
  final _mensajeFiscalCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarPlantilla(_tipoSeleccionado);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _encabezadoCtrl.dispose();
    _pieCtrl.dispose();
    _mensajeFiscalCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPlantilla(String tipo) async {
    setState(() {
      _cargando = true;
      _tipoSeleccionado = tipo;
    });

    try {
      final res = await _servicio.obtenerPlantilla(tipo);
      if (!mounted) return;
      final p = PlantillaImpresion.fromJson(res);
      setState(() {
        _plantillaActual = p;
        _nombreCtrl.text = p.nombrePlantilla;
        _encabezadoCtrl.text = p.encabezadoPersonalizado ?? '';
        _pieCtrl.text = p.piePaginaPersonalizado ?? '';
        _mensajeFiscalCtrl.text = p.mensajeFiscal ?? '';
      });
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error cargando plantilla: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarCambios() async {
    if (_plantillaActual == null) return;

    setState(() => _guardando = true);
    try {
      final actual = _plantillaActual!.copyWith(
        nombrePlantilla: _nombreCtrl.text.trim(),
        encabezadoPersonalizado: _encabezadoCtrl.text.trim().isEmpty ? null : _encabezadoCtrl.text.trim(),
        piePaginaPersonalizado: _pieCtrl.text.trim().isEmpty ? null : _pieCtrl.text.trim(),
        mensajeFiscal: _mensajeFiscalCtrl.text.trim().isEmpty ? null : _mensajeFiscalCtrl.text.trim(),
      );

      final res = await _servicio.actualizarPlantilla(_tipoSeleccionado, actual.toJson());
      if (!mounted) return;
      setState(() {
        _plantillaActual = PlantillaImpresion.fromJson(res);
      });
      showAppToast(context, 'Plantilla guardada correctamente', type: ToastType.success);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error al guardar plantilla: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fileText, color: AppColors.primaryGreen, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diseño y Partes de Documentos (Low-Code)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Personaliza qué bloques, textos y tamaños de fuente se imprimen en cada tipo de comanda o comprobante.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (_guardando)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              else
                ElevatedButton.icon(
                  onPressed: _guardarCambios,
                  icon: const Icon(LucideIcons.save, size: 16),
                  label: const Text('Guardar Plantilla'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Pestañas / Selector de Tipo de Documento
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tiposDocumento.map((td) {
                final sel = td['tipo'] == _tipoSeleccionado;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(td['nombre']!),
                    selected: sel,
                    onSelected: (v) {
                      if (v) _cargarPlantilla(td['tipo']!);
                    },
                    selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: sel ? AppColors.primaryGreen : Colors.black87,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          if (_cargando)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_plantillaActual == null)
            const Text('No se pudo cargar la configuración de esta plantilla')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final esAncho = constraints.maxWidth > 900;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna 1: Controles de Configuración
                    Expanded(
                      flex: esAncho ? 6 : 1,
                      child: _buildFormularioConfig(context),
                    ),
                    if (esAncho) ...[
                      const SizedBox(width: 24),
                      // Columna 2: Vista Previa en Vivo (Simulador de Papel Térmico)
                      Expanded(
                        flex: 5,
                        child: _buildVistaPreviaTicket(context),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFormularioConfig(BuildContext context) {
    final p = _plantillaActual!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CampoTexto(
          controller: _nombreCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre de la Plantilla',
            prefixIcon: Icon(LucideIcons.tag, size: 18),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Partes y Bloques Visibles',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Logotipo'),
              selected: p.imprimirLogo,
              onSelected: (v) => setState(() => _plantillaActual = p.copyWith(imprimirLogo: v)),
            ),
            if (p.tipoDocumento != 'COMANDA_COCINA')
              FilterChip(
                label: const Text('Código QR'),
                selected: p.imprimirQr,
                onSelected: (v) => setState(() => _plantillaActual = p.copyWith(imprimirQr: v)),
              ),
            if (p.tipoDocumento != 'COMANDA_COCINA')
              FilterChip(
                label: const Text('Monto en Letras'),
                selected: p.imprimirMontoLetras,
                onSelected: (v) => setState(() => _plantillaActual = p.copyWith(imprimirMontoLetras: v)),
              ),
            if (p.tipoDocumento != 'COMANDA_COCINA')
              FilterChip(
                label: const Text('Datos Fiscales / RUC'),
                selected: p.imprimirDatosFiscales,
                onSelected: (v) => setState(() => _plantillaActual = p.copyWith(imprimirDatosFiscales: v)),
              ),
            FilterChip(
              label: const Text('Nombre del Mozo'),
              selected: p.imprimirMozo,
              onSelected: (v) => setState(() => _plantillaActual = p.copyWith(imprimirMozo: v)),
            ),
            FilterChip(
              label: const Text('Modalidad / Táper'),
              selected: p.imprimirTaper,
              onSelected: (v) => setState(() => _plantillaActual = p.copyWith(imprimirTaper: v)),
            ),
            FilterChip(
              label: const Text('Mesa / Zona'),
              selected: p.imprimirMesaZona,
              onSelected: (v) => setState(() => _plantillaActual = p.copyWith(imprimirMesaZona: v)),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Text(
          'Tamaños de Fuente ESC/POS (Low-Code)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppSelect<String>(
                label: 'Título Principal',
                value: p.tamanioTitulo,
                items: const [
                  AppSelectItem(value: 'normal', label: 'Normal'),
                  AppSelectItem(value: 'doble_alto', label: 'Doble Alto'),
                  AppSelectItem(value: 'doble_ancho', label: 'Doble Ancho'),
                  AppSelectItem(value: 'grande', label: 'Grande (2x2)'),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _plantillaActual = p.copyWith(tamanioTitulo: v));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppSelect<String>(
                label: 'Número de Orden',
                value: p.tamanioCodigoOrden,
                items: const [
                  AppSelectItem(value: 'normal', label: 'Normal'),
                  AppSelectItem(value: 'doble_alto', label: 'Doble Alto'),
                  AppSelectItem(value: 'doble_ancho', label: 'Doble Ancho'),
                  AppSelectItem(value: 'grande', label: 'Grande (2x2)'),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _plantillaActual = p.copyWith(tamanioCodigoOrden: v));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppSelect<String>(
                label: 'Nombre de Plato',
                value: p.tamanioPlato,
                items: const [
                  AppSelectItem(value: 'normal', label: 'Normal'),
                  AppSelectItem(value: 'doble_alto', label: 'Doble Alto'),
                  AppSelectItem(value: 'grande', label: 'Grande (2x2)'),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _plantillaActual = p.copyWith(tamanioPlato: v));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        CampoTexto(
          controller: _encabezadoCtrl,
          decoration: const InputDecoration(
            labelText: 'Encabezado Personalizado (Opcional)',
            prefixIcon: Icon(LucideIcons.heading, size: 18),
          ),
        ),
        const SizedBox(height: 12),
        CampoTexto(
          controller: _mensajeFiscalCtrl,
          decoration: const InputDecoration(
            labelText: 'Mensaje Fiscal o Leyenda Legal',
            prefixIcon: Icon(LucideIcons.scale, size: 18),
          ),
        ),
        const SizedBox(height: 12),
        CampoTexto(
          controller: _pieCtrl,
          decoration: const InputDecoration(
            labelText: 'Pie de Página / Despedida',
            prefixIcon: Icon(LucideIcons.alignCenter, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildVistaPreviaTicket(BuildContext context) {
    final p = _plantillaActual!;

    double fontSizeTitulo = 14;
    FontWeight fontWeightTitulo = FontWeight.bold;
    if (p.tamanioTitulo == 'grande' || p.tamanioTitulo == 'doble_alto') {
      fontSizeTitulo = 18;
    }

    double fontSizeOrden = 14;
    if (p.tamanioCodigoOrden == 'grande' || p.tamanioCodigoOrden == 'doble_alto') {
      fontSizeOrden = 18;
    }

    double fontSizePlato = 13;
    if (p.tamanioPlato == 'grande' || p.tamanioPlato == 'doble_alto') {
      fontSizePlato = 15;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'VISTA PREVIA EN VIVO (80 mm)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 1.2,
            ),
          ),
          const Divider(thickness: 1, height: 16),

          // Logo simulado
          if (p.imprimirLogo) ...[
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
                child: const Icon(LucideIcons.store, color: Colors.black87, size: 28),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Datos Sede
          if (p.imprimirDatosFiscales) ...[
            const Text(
              'RESTAURANTE BIJAO S.A.C.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
            ),
            const Text(
              'RUC: 20608543211',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
            ),
            const Text(
              'CAL. Los Brillantes 421B - Trujillo',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
            ),
            const SizedBox(height: 6),
          ],

          // Encabezado personalizado si existe
          if (_encabezadoCtrl.text.trim().isNotEmpty) ...[
            Text(
              _encabezadoCtrl.text.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 4),
          ],

          // Título del documento
          Text(
            p.tipoDocumento == 'COMANDA_COCINA'
                ? '*** COMANDA COCINA ***'
                : (p.tipoDocumento == 'FACTURA_ELECTRONICA'
                    ? 'FACTURA ELECTRONICA'
                    : (p.tipoDocumento == 'BOLETA_ELECTRONICA'
                        ? 'BOLETA ELECTRONICA'
                        : (p.tipoDocumento == 'CUENTA_CONSUMO' ? 'PRECUENTA' : 'TICKET DE VENTA'))),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSizeTitulo,
              fontWeight: fontWeightTitulo,
              color: Colors.black,
            ),
          ),

          // Número / Código de Orden
          Text(
            p.tipoDocumento == 'COMANDA_COCINA'
                ? 'ORDEN #0004'
                : (p.tipoDocumento == 'FACTURA_ELECTRONICA'
                    ? 'FA01-00000004'
                    : (p.tipoDocumento == 'BOLETA_ELECTRONICA' ? 'BA01-00000012' : 'TA01-00000028')),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSizeOrden,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const Text('------------------------------------------------', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', color: Colors.black54)),

          // Metadatos
          if (p.imprimirMesaZona)
            const Text('MESA: 04 (SALON)', style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
          if (p.imprimirMozo)
            const Text('Mozo: Jose Alva', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black)),
          const Text('Fecha: 26/10/2026 12:45:10', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black)),

          const Text('================================================', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', color: Colors.black54)),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CANT  DESCRIPCION', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
              Text('TOTAL', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
            ],
          ),
          const Text('------------------------------------------------', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', color: Colors.black54)),

          // Platos simulados
          Text('[1x] 1/2 chaufa especial', style: TextStyle(fontFamily: 'monospace', fontSize: fontSizePlato, fontWeight: FontWeight.bold, color: Colors.black)),
          if (p.imprimirTaper)
            const Text('      > [PARA LLEVAR / TAPER] <', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black87)),
          const SizedBox(height: 4),

          Text('[2x] Aguajina - Jarra', style: TextStyle(fontFamily: 'monospace', fontSize: fontSizePlato, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 6),

          const Text('================================================', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', color: Colors.black54)),

          // Totales si no es comanda
          if (p.tipoDocumento != 'COMANDA_COCINA') ...[
            const Text('OP. GRAVADA: S/   89.83', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black)),
            const Text('IGV (18%):   S/   16.17', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black)),
            const Text('TOTAL: S/ 106.00', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
            const Text('------------------------------------------------', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', color: Colors.black54)),
          ],

          // Monto en letras
          if (p.imprimirMontoLetras && p.tipoDocumento != 'COMANDA_COCINA') ...[
            const Text('SON: CIENTO SEIS Y 00/100 SOLES', style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black)),
            const Text('------------------------------------------------', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', color: Colors.black54)),
          ],

          // QR simulado
          if (p.imprimirQr && p.tipoDocumento != 'COMANDA_COCINA') ...[
            const SizedBox(height: 6),
            Center(
              child: Container(
                width: 70,
                height: 70,
                color: Colors.black12,
                child: const Icon(LucideIcons.qrCode, size: 50, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Mensajes legales y pie
          if (_mensajeFiscalCtrl.text.trim().isNotEmpty)
            Text(_mensajeFiscalCtrl.text.trim(), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54)),
          if (_pieCtrl.text.trim().isNotEmpty)
            Text(_pieCtrl.text.trim(), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),

          const SizedBox(height: 12),
          const Center(child: Text('- - -  Corte  - - -', style: TextStyle(fontSize: 10, color: Colors.grey))),
        ],
      ),
    );
  }
}
