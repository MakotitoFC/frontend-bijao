import 'dart:typed_data';

import '../data/logo_ticket_store.dart';
import '../theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/plantilla_impresion.dart';
import '../services/impresion_service.dart';
import '../services/facturacion_service.dart';
import 'app_select.dart';
import 'app_switch.dart';
import 'app_tag.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'fila_responsiva.dart';
import 'logo_tickets_editor.dart';

class PlantillasImpresionEditor extends StatefulWidget {
  const PlantillasImpresionEditor({super.key});

  @override
  State<PlantillasImpresionEditor> createState() =>
      _PlantillasImpresionEditorState();
}

class _PlantillasImpresionEditorState extends State<PlantillasImpresionEditor> {
  final _servicio = ImpresionService.instance;

  final List<Map<String, String>> _tiposDocumento = [
    {'tipo': 'CUENTA_CONSUMO', 'nombre': 'Cuenta de Consumo'},
    {'tipo': 'COMANDA_COCINA', 'nombre': 'Comanda Cocina'},
    {'tipo': 'TICKET_VENTA', 'nombre': 'Ticket de Venta'},
    {'tipo': 'BOLETA_ELECTRONICA', 'nombre': 'Boleta Electrónica'},
    {'tipo': 'FACTURA_ELECTRONICA', 'nombre': 'Factura Electrónica'},
  ];

  String _tipoSeleccionado = 'CUENTA_CONSUMO';
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
    _nombreCtrl.addListener(_onFieldChanged);
    _encabezadoCtrl.addListener(_onFieldChanged);
    _pieCtrl.addListener(_onFieldChanged);
    _mensajeFiscalCtrl.addListener(_onFieldChanged);
    _cargarPlantilla(_tipoSeleccionado);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nombreCtrl.removeListener(_onFieldChanged);
    _encabezadoCtrl.removeListener(_onFieldChanged);
    _pieCtrl.removeListener(_onFieldChanged);
    _mensajeFiscalCtrl.removeListener(_onFieldChanged);
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
        showAppToast(
          context,
          'Error cargando plantilla: $e',
          type: ToastType.error,
        );
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
        encabezadoPersonalizado: _encabezadoCtrl.text.trim().isEmpty
            ? null
            : _encabezadoCtrl.text.trim(),
        piePaginaPersonalizado: _pieCtrl.text.trim().isEmpty
            ? null
            : _pieCtrl.text.trim(),
        mensajeFiscal: _mensajeFiscalCtrl.text.trim().isEmpty
            ? null
            : _mensajeFiscalCtrl.text.trim(),
      );

      final res = await _servicio.actualizarPlantilla(
        _tipoSeleccionado,
        actual.toJson(),
      );
      if (!mounted) return;
      setState(() {
        _plantillaActual = PlantillaImpresion.fromJson(res);
      });
      showAppToast(
        context,
        'Plantilla guardada correctamente',
        type: ToastType.success,
      );
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'Error al guardar plantilla: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Misma estructura que las demás secciones de Configuración: título,
    // descripción en gris y el contenido en una tarjeta blanca.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título y "Guardar plantilla": con poco ancho el botón baja bajo el
        // título en vez de apretarlo.
        LayoutBuilder(
          builder: (context, c) {
            final titulo = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Diseño y partes de documentos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                if (!AppBreakpoints.esMobile(context)) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Elige qué bloques, textos y tamaños de letra se imprimen en cada comanda o comprobante.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ],
            );
            final accion = _guardando
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton.icon(
                    onPressed: _guardarCambios,
                    icon: const Icon(LucideIcons.save, size: 16),
                    label: const Text('Guardar plantilla'),
                  );
            if (c.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [titulo, const SizedBox(height: 12), accion],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titulo),
                const SizedBox(width: 12),
                accion,
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // Tipo de documento
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final td in _tiposDocumento)
                AppTag(
                  etiqueta: td['nombre']!,
                  activo: td['tipo'] == _tipoSeleccionado,
                  onTap: () => _cargarPlantilla(td['tipo']!),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: _cargando
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _plantillaActual == null
              ? const Text(
                  'No se pudo cargar la configuración de esta plantilla',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final esAncho = constraints.maxWidth > 760;
                    if (!esAncho) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFormularioConfig(context),
                          const SizedBox(height: 24),
                          _buildVistaPreviaTicket(context),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _buildFormularioConfig(context),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 5,
                          child: _buildVistaPreviaTicket(context),
                        ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const LogoTicketsEditor(),
        ),
      ],
    );
  }

  Widget _subtitulo(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
    ),
  );

  // Un bloque del documento: nombre y un interruptor, en una fila con borde.
  Widget _bloque(String etiqueta, bool valor, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          AppSwitch(value: valor, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildFormularioConfig(BuildContext context) {
    final p = _plantillaActual!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilaResponsiva.fila(
          children: [
            Expanded(
              flex: 3,
              child: CampoTexto(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Plantilla',
                  prefixIcon: Icon(LucideIcons.tag, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppSelect<String>(
                label: 'Lugar de Impresión',
                value:
                    (p.configExtra['lugar_impresion']?.toString() ??
                    (p.tipoDocumento == 'COMANDA_COCINA' ? 'cocina' : 'caja')),
                items: const [
                  AppSelectItem(value: 'caja', label: 'Caja (USB por defecto)'),
                  AppSelectItem(value: 'cocina', label: 'Cocina (Red/LAN)'),
                  AppSelectItem(value: 'barra', label: 'Barra / Bar'),
                ],
                onChanged: (v) {
                  if (v != null) {
                    final extra = Map<String, dynamic>.from(p.configExtra);
                    extra['lugar_impresion'] = v;
                    setState(
                      () => _plantillaActual = p.copyWith(configExtra: extra),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _subtitulo('Partes del documento'),
        LayoutBuilder(
          builder: (context, c) {
            final dos = c.maxWidth >= 420;
            final ancho = dos ? (c.maxWidth - 10) / 2 : c.maxWidth;
            final comanda = p.tipoDocumento == 'COMANDA_COCINA';
            Widget item(String e, bool v, ValueChanged<bool> f) =>
                SizedBox(width: ancho, child: _bloque(e, v, f));
            return Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                item(
                  'Logotipo',
                  p.imprimirLogo,
                  (v) => setState(
                    () => _plantillaActual = p.copyWith(imprimirLogo: v),
                  ),
                ),
                if (!comanda)
                  item(
                    'Código QR',
                    p.imprimirQr,
                    (v) => setState(
                      () => _plantillaActual = p.copyWith(imprimirQr: v),
                    ),
                  ),
                if (!comanda)
                  item(
                    'Monto en letras',
                    p.imprimirMontoLetras,
                    (v) => setState(
                      () =>
                          _plantillaActual = p.copyWith(imprimirMontoLetras: v),
                    ),
                  ),
                if (!comanda)
                  item(
                    'Datos fiscales / RUC',
                    p.imprimirDatosFiscales,
                    (v) => setState(
                      () => _plantillaActual = p.copyWith(
                        imprimirDatosFiscales: v,
                      ),
                    ),
                  ),
                item(
                  'Nombre del mozo',
                  p.imprimirMozo,
                  (v) => setState(
                    () => _plantillaActual = p.copyWith(imprimirMozo: v),
                  ),
                ),
                item(
                  'Modalidad / Táper',
                  p.imprimirTaper,
                  (v) => setState(
                    () => _plantillaActual = p.copyWith(imprimirTaper: v),
                  ),
                ),
                item(
                  'Mesa / Zona',
                  p.imprimirMesaZona,
                  (v) => setState(
                    () => _plantillaActual = p.copyWith(imprimirMesaZona: v),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        _subtitulo('Tamaños de letra'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 160,
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
                  if (v != null) {
                    setState(
                      () => _plantillaActual = p.copyWith(tamanioTitulo: v),
                    );
                  }
                },
              ),
            ),
            SizedBox(
              width: 160,
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
                  if (v != null) {
                    setState(
                      () => _plantillaActual = p.copyWith(tamanioCodigoOrden: v),
                    );
                  }
                },
              ),
            ),
            SizedBox(
              width: 160,
              child: AppSelect<String>(
                label: 'Nombre de Plato',
                value: p.tamanioPlato,
                items: const [
                  AppSelectItem(value: 'normal', label: 'Normal'),
                  AppSelectItem(value: 'doble_alto', label: 'Doble Alto'),
                  AppSelectItem(value: 'grande', label: 'Grande (2x2)'),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(
                      () => _plantillaActual = p.copyWith(tamanioPlato: v),
                    );
                  }
                },
              ),
            ),
            SizedBox(
              width: 160,
              child: AppSelect<String>(
                label: 'Notas y Extras',
                value: p.tamanioDescripcion ?? 'normal',
                items: const [
                  AppSelectItem(value: 'normal', label: 'Normal (Recomendado)'),
                  AppSelectItem(value: 'doble_alto', label: 'Doble Alto'),
                  AppSelectItem(value: 'grande', label: 'Grande (2x2)'),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(
                      () => _plantillaActual = p.copyWith(tamanioDescripcion: v),
                    );
                  }
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

    final isComanda = p.tipoDocumento == 'COMANDA_COCINA';
    final isTicket = p.tipoDocumento == 'TICKET_VENTA';
    final isBoleta = p.tipoDocumento == 'BOLETA_ELECTRONICA';
    final isFactura = p.tipoDocumento == 'FACTURA_ELECTRONICA';
    final isCuenta = p.tipoDocumento == 'CUENTA_CONSUMO';
    final isDocFiscal = isBoleta || isFactura;

    // El logo se imprime en comprobantes y tickets (excepto comanda de cocina)
    final mostrarLogo = p.imprimirLogo && !isComanda;

    // Limpieza de encabezado
    final encabezado = _encabezadoCtrl.text.trim();
    final tieneEncabezado = encabezado.isNotEmpty &&
        encabezado.toUpperCase() != 'NULL' &&
        encabezado.toLowerCase() != '<null>';

    // Limpieza de mensaje fiscal
    final mensajeFiscal = _mensajeFiscalCtrl.text.trim();
    final tieneMensajeFiscal = mensajeFiscal.isNotEmpty &&
        mensajeFiscal.toUpperCase() != 'NULL' &&
        mensajeFiscal.toLowerCase() != '<null>';

    // Limpieza de pie
    final pie = _pieCtrl.text.trim();
    final tienePie = pie.isNotEmpty &&
        pie.toUpperCase() != 'NULL' &&
        pie.toLowerCase() != '<null>';

    // Tamaños de fuentes
    double fontSizeTitulo = 14;
    FontWeight fontWeightTitulo = FontWeight.bold;
    if (p.tamanioTitulo == 'grande' || p.tamanioTitulo == 'doble_alto') {
      fontSizeTitulo = 18;
    }

    double fontSizeOrden = 14;
    if (p.tamanioCodigoOrden == 'grande' ||
        p.tamanioCodigoOrden == 'doble_alto') {
      fontSizeOrden = 18;
    }

    double fontSizePlato = 13;
    if (p.tamanioPlato == 'grande' || p.tamanioPlato == 'doble_alto') {
      fontSizePlato = 15;
    }

    // Tamaño de notas / extras
    final tamDesc = p.tamanioDescripcion ?? 'normal';
    double fontSizeDesc = 11;
    // Si el plato es normal, la nota no debe ser mayor al plato
    if (p.tamanioPlato == 'normal') {
      fontSizeDesc = 11;
    } else if (tamDesc == 'grande' || tamDesc == 'doble_alto') {
      fontSizeDesc = 14;
    }

    // IGV dinámico para documentos fiscales
    final igvPct = FacturacionService.instance.cachedConfig?.igvPorcentaje ?? 10.5;
    final igvLabel = (igvPct % 1 == 0)
        ? '${igvPct.toInt()}%'
        : '${igvPct.toStringAsFixed(1)}%';
    const totalFiscal = 120.00;
    final gravadaFiscal = totalFiscal / (1.0 + (igvPct / 100.0));
    final igvFiscal = totalFiscal - gravadaFiscal;

    final papel = Container(
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

          // Logo (si está habilitado para este documento)
          if (mostrarLogo) ...[
            Center(
              child: ValueListenableBuilder<Uint8List?>(
                valueListenable: logoTicketLocal,
                builder: (context, bytes, _) {
                  if (bytes != null) {
                    return Image.memory(bytes, height: 48, fit: BoxFit.contain);
                  }
                  return Image.asset(
                    'assets/images/logo_bijao.png',
                    height: 44,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26),
                      ),
                      child: const Icon(
                        LucideIcons.store,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],

          // Encabezado personalizado si existe (y no es NULL)
          if (!isComanda && tieneEncabezado) ...[
            Text(
              encabezado,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
          ],

          // Datos Sede (Nunca en Comanda)
          if (!isComanda && p.imprimirDatosFiscales) ...[
            const Text(
              'SERVICIOS MULTIPLES EL BIJAO E.I.R.L.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: Colors.black,
              ),
            ),
            const Text(
              'RUC: 20540005371',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.black,
              ),
            ),
            const Text(
              'CAL. LOS BRILLANTES NRO. 421 URB. SANTA INES\nTRUJILLO - LA LIBERTAD',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: Colors.black,
              ),
            ),
            const Text(
              'Tel: 999999999',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Título del documento
          Text(
            isComanda
                ? (tieneEncabezado ? encabezado : '*** COMANDA COCINA ***')
                : (isFactura
                    ? 'FACTURA ELECTRONICA'
                    : (isBoleta
                        ? 'BOLETA DE VENTA ELECTRONICA'
                        : (isCuenta
                            ? 'CUENTA DE CONSUMO\nNo es comprobante de pago'
                            : 'TICKET DE VENTA'))),
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
            isComanda
                ? 'ORDEN #0002'
                : (isFactura
                    ? 'FA01-00000004'
                    : (isBoleta
                        ? 'BA01-00000009'
                        : (isCuenta ? 'ORDEN #0002' : 'TA01-00000028'))),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSizeOrden,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const Text(
            '------------------------------------------------',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'monospace', color: Colors.black54),
          ),

          // Datos del cliente (Ticket Llevar/Delivery o Fiscales)
          if (isDocFiscal) ...[
            Text(
              isFactura
                  ? 'CLIENTE: INGENIERIA Y CONSTRUCCION S.A.C.'
                  : 'CLIENTE: CLIENTES VARIOS',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.black,
              ),
            ),
            if (isFactura)
              const Text(
                'RUC: 20601234567',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.black,
                ),
              ),
            const SizedBox(height: 2),
          ] else if (isTicket) ...[
            const Text(
              'CLIENTE: JUAN PEREZ (PARA LLEVAR)',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const Text(
              'TEL: 987654321',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 2),
          ],

          // Metadatos
          if (p.imprimirMesaZona)
            const Text(
              'MESA: 01 (ZONA A)',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          if (p.imprimirMozo)
            const Text(
              'Mozo: Alexis',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.black,
              ),
            ),
          const Text(
            'Fecha: 08/11/2026 20:22:40',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.black,
            ),
          ),

          const Text(
            '================================================',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'monospace', color: Colors.black54),
          ),

          // Encabezado de columnas
          if (isComanda)
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CANT  DESCRIPCION',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'MODALIDAD',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.black,
                  ),
                ),
              ],
            )
          else
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CANT  DESCRIPCION',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'TOTAL',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.black,
                  ),
                ),
              ],
            ),

          const Text(
            '------------------------------------------------',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'monospace', color: Colors.black54),
          ),

          // Items simulados
          if (isComanda) ...[
            Text(
              '[1x] CECINA A LO POBRE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSizePlato,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              '  * NOTA: CON ZARZA',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSizeDesc,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (p.imprimirTaper)
              const Text(
                '  > [PARA LLEVAR / TAPER] <',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Colors.black87,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              '[1x] TACACHO CON CECINA',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSizePlato,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '1x  1/2 chaufa',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: fontSizePlato,
                      color: Colors.black,
                    ),
                  ),
                ),
                Text(
                  'S/  18.00',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: fontSizePlato,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            if (p.imprimirTaper)
              const Text(
                '  > [PARA LLEVAR / TAPER] <',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Colors.black87,
                ),
              ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '1x  1/2 Tira Cerdo',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: fontSizePlato,
                      color: Colors.black,
                    ),
                  ),
                ),
                Text(
                  'S/  40.00',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: fontSizePlato,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '1x  BOTELLA UVACHADO',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: fontSizePlato,
                      color: Colors.black,
                    ),
                  ),
                ),
                Text(
                  'S/  60.00',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: fontSizePlato,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            Text(
              '  * NOTA: BIEN HELADA',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSizeDesc,
                color: Colors.black87,
              ),
            ),
          ],
          const SizedBox(height: 6),

          const Text(
            '================================================',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'monospace', color: Colors.black54),
          ),

          // Totales si no es comanda
          if (!isComanda) ...[
            if (isDocFiscal) ...[
              Text(
                'OP. GRAVADA: S/ ${gravadaFiscal.toStringAsFixed(2).padLeft(7)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.black,
                ),
              ),
              Text(
                'IGV ($igvLabel): S/ ${igvFiscal.toStringAsFixed(2).padLeft(7)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.black,
                ),
              ),
              Text(
                'TOTAL: S/ ${totalFiscal.toStringAsFixed(2).padLeft(7)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ] else ...[
              const Text(
                'TOTAL: S/  118.00',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
            const Text(
              '------------------------------------------------',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', color: Colors.black54),
            ),
          ],

          // Monto en letras (solo fiscal)
          if (p.imprimirMontoLetras && isDocFiscal) ...[
            const Text(
              'SON: CIENTO VEINTE Y 00/100 SOLES',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.black,
              ),
            ),
            const Text(
              '------------------------------------------------',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', color: Colors.black54),
            ),
          ],

          // QR simulado (solo fiscal)
          if (p.imprimirQr && isDocFiscal) ...[
            const SizedBox(height: 6),
            Center(
              child: Container(
                width: 70,
                height: 70,
                color: Colors.black12,
                child: const Icon(
                  LucideIcons.qrCode,
                  size: 50,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Mensajes legales y pie
          if (tieneMensajeFiscal && !isComanda)
            Text(
              mensajeFiscal,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Colors.black54,
              ),
            ),
          if (tienePie)
            Text(
              pie,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

          const SizedBox(height: 12),
          const Center(
            child: Text(
              '- - -  Corte  - - -',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: papel,
        ),
      ),
    );
  }
}
