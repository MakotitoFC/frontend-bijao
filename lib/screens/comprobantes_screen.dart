import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/comprobante.dart';
import '../services/api_client.dart';
import '../services/facturacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/abrir_enlace.dart';
import '../widgets/app_search_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/selector_rango_fechas.dart';
import '../widgets/tabla_app.dart';
import '../widgets/tabs_texto.dart';

String _error(Object e) => e is ApiException
    ? e.message
    : e.toString().replaceFirst('Exception: ', '');

// Registro de todas las boletas y facturas emitidas, por fecha. A diferencia
// del panel de Caja (que solo muestra el turno actual), aquí los comprobantes
// siguen estando después de cerrar caja.
class ComprobantesScreen extends StatefulWidget {
  const ComprobantesScreen({super.key});

  @override
  State<ComprobantesScreen> createState() => _ComprobantesScreenState();
}

class _ComprobantesScreenState extends State<ComprobantesScreen> {
  late DateTimeRange _rango = _hoy();
  // 'todos' | 'boleta' | 'factura'
  String _tipo = 'todos';
  final _busqueda = TextEditingController();
  List<Comprobante> _lista = const [];
  bool _cargando = true;
  String? _errorCarga;
  // Evita que una respuesta lenta pise a una consulta más reciente.
  int _consulta = 0;

  static DateTimeRange _hoy() {
    final h = DateUtils.dateOnly(DateTime.now());
    return DateTimeRange(start: h, end: h);
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final mia = ++_consulta;
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final lista = await FacturacionService.instance.listar(
        desde: _rango.start,
        hasta: _rango.end,
        tipoDocumento: _tipo == 'todos' ? null : _tipo,
      );
      if (!mounted || mia != _consulta) return;
      setState(() => _lista = lista);
    } catch (e) {
      if (mounted && mia == _consulta) {
        setState(() => _errorCarga = _error(e));
      }
    } finally {
      if (mounted && mia == _consulta) setState(() => _cargando = false);
    }
  }

  // Solo boletas y facturas (el ticket de venta es interno), más recientes
  // primero y con la búsqueda aplicada.
  List<Comprobante> get _filas {
    final q = _busqueda.text.trim().toLowerCase();
    final filas = [
      for (final c in _lista)
        if (c.esFiscal &&
            (_tipo == 'todos' || c.tipoDocumento == _tipo) &&
            (q.isEmpty ||
                c.numeroComprobante.toLowerCase().contains(q) ||
                c.clienteDenominacion.toLowerCase().contains(q) ||
                c.clienteNumDoc.toLowerCase().contains(q)))
          c,
    ];
    filas.sort(
      (a, b) => (b.fechaHora ?? DateTime(1970)).compareTo(
        a.fechaHora ?? DateTime(1970),
      ),
    );
    return filas;
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

  Color _color(Comprobante c) {
    if (c.anulado || c.rechazado) return AppColors.error;
    if (c.pendiente) return AppColors.naranja;
    return AppColors.primaryGreen;
  }

  String _fechaHora(Comprobante c) {
    final f = c.fechaHora;
    if (f == null) return '${c.fechaEmision} ${c.horaEmision}'.trim();
    String d2(int n) => n.toString().padLeft(2, '0');
    return '${d2(f.day)}/${d2(f.month)}/${f.year} ${d2(f.hour)}:${d2(f.minute)}';
  }

  Widget _etiqueta(String texto, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadii.tag),
    ),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );

  // Todos / Boletas / Facturas: segmentos pegados; el elegido va oscuro.
  Widget _grupoTipo() {
    const opciones = [
      ('todos', 'Todos'),
      ('boleta', 'Boletas'),
      ('factura', 'Facturas'),
    ];
    return TabsTexto(
      tabs: [
        for (final o in opciones)
          TabTexto(
            etiqueta: o.$2,
            activa: _tipo == o.$1,
            onTap: () {
              if (_tipo == o.$1) return;
              setState(() => _tipo = o.$1);
              _cargar();
            },
          ),
      ],
    );
  }

  static String _soles(double v) => 'S/ ${v.toStringAsFixed(2)}';

  // Día del comprobante ("2026-11-03"), sin la hora.
  String _dia(Comprobante c) => c.fechaEmision.length >= 10
      ? c.fechaEmision.substring(0, 10)
      : c.fechaEmision;

  String _diaCorto(String iso) {
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
  }

  // Misma tarjeta que los totales de Caja: en pantalla ancha, título con el
  // ícono a la derecha, monto grande con decimales grises y una línea de
  // detalle; en celular, la versión compacta con el ícono a la izquierda.
  Widget _tarjetaMonto(
    IconData icono,
    Color color,
    Color fondo,
    String titulo,
    double valor,
    String detalle,
  ) {
    final mini = AppBreakpoints.esMenorATablet(context);
    if (!mini) {
      final entero = valor.truncate().abs();
      final dec = (valor.abs() - entero).toStringAsFixed(2).substring(1);
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: fondo,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icono, size: 18, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'S/ $entero',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    TextSpan(
                      text: dec,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                detalle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: fondo),
            ),
            child: Icon(icono, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _soles(valor),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Montos del rango (sin anulados ni rechazados): boletas, facturas y total;
  // si el rango abarca varios días, además el total de cada fecha.
  Widget _resumen(List<Comprobante> filas) {
    final validas = [
      for (final c in filas)
        if (!c.anulado && !c.rechazado) c,
    ];
    double suma(Iterable<Comprobante> l) => l.fold(0.0, (s, c) => s + c.total);
    final boletas = validas.where((c) => c.tipoDocumento == 'boleta').toList();
    final facturas = validas
        .where((c) => c.tipoDocumento == 'factura')
        .toList();
    final porDia = <String, List<Comprobante>>{};
    for (final c in validas) {
      porDia.putIfAbsent(_dia(c), () => []).add(c);
    }
    final dias = porDia.keys.toList()..sort((a, b) => b.compareTo(a));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final mini = AppBreakpoints.esMenorATablet(context);
            final espacio = mini ? 8.0 : 12.0;
            final columnas = mini ? 2 : (c.maxWidth >= 560 ? 3 : 1);
            final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
            String n(int k, String uno, String varios) =>
                '$k ${k == 1 ? uno : varios}';
            final tarjetas = [
              _tarjetaMonto(
                LucideIcons.receipt,
                const Color(0xFF3B82F6),
                const Color(0xFFEFF6FF),
                'Boletas',
                suma(boletas),
                n(boletas.length, 'emitida', 'emitidas'),
              ),
              _tarjetaMonto(
                LucideIcons.fileText,
                const Color(0xFF8B5CF6),
                const Color(0xFFF5F3FF),
                'Facturas',
                suma(facturas),
                n(facturas.length, 'emitida', 'emitidas'),
              ),
              _tarjetaMonto(
                LucideIcons.wallet,
                AppColors.primaryGreen,
                const Color(0xFFECFDF5),
                'Total',
                suma(validas),
                n(validas.length, 'comprobante', 'comprobantes'),
              ),
            ];
            return Wrap(
              spacing: espacio,
              runSpacing: espacio,
              children: [
                for (final t in tarjetas) SizedBox(width: ancho, child: t),
              ],
            );
          },
        ),
        if (dias.length > 1) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final d in dias)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(AppRadii.tag),
                    ),
                    child: Text(
                      '${_diaCorto(d)} · ${porDia[d]!.length} · '
                      '${_soles(suma(porDia[d]!))}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _acciones(Comprobante c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (c.pdfTicketUrl != null || c.pdfA4Url != null)
          Tooltip(
            message: 'Ver PDF',
            child: IconButton(
              icon: const Icon(
                LucideIcons.fileText,
                size: 16,
                color: Colors.purple,
              ),
              onPressed: () => abrirEnlace(c.pdfA4Url ?? c.pdfTicketUrl!),
            ),
          ),
        if (c.puedeAnularse)
          Tooltip(
            message: 'Reimprimir en la ticketera de caja',
            child: IconButton(
              icon: const Icon(
                LucideIcons.printer,
                size: 16,
                color: Colors.blue,
              ),
              onPressed: () => _accion(
                () => FacturacionService.instance.reimprimir(c.id),
                'Enviado a la impresora de caja.',
              ),
            ),
          ),
        if (c.pendiente)
          Tooltip(
            message: 'Consultar el estado en SUNAT',
            child: IconButton(
              icon: const Icon(
                LucideIcons.refreshCw,
                size: 16,
                color: AppColors.naranja,
              ),
              onPressed: () => _accion(
                () => FacturacionService.instance.consultarEstado(c.id),
                'Estado consultado.',
              ),
            ),
          ),
      ],
    );
  }

  Widget _tabla(List<Comprobante> filas) {
    return TablaApp<Comprobante>(
      scrollInterno: true,
      porPagina: 8,
      filas: filas,
      columnas: [
        ColumnaTabla(
          titulo: 'Fecha',
          ancho: 150,
          ordenarPor: (c) => c.fechaHora ?? DateTime(1970),
          celda: (c) => TablaApp.texto(_fechaHora(c)),
        ),
        ColumnaTabla(
          titulo: 'Comprobante',
          ancho: 150,
          rol: RolTarjeta.titulo,
          ordenarPor: (c) => c.numeroComprobante,
          celda: (c) => Text(
            c.numeroComprobante,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              decoration: c.anulado ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        ColumnaTabla(
          titulo: 'Tipo',
          ancho: 100,
          ordenarPor: (c) => c.tipoEtiqueta,
          celda: (c) => Align(
            alignment: Alignment.centerLeft,
            child: _etiqueta(
              c.tipoEtiqueta,
              c.tipoDocumento == 'factura'
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFF3B82F6),
            ),
          ),
        ),
        ColumnaTabla(
          titulo: 'Cliente',
          flex: 1.4,
          anchoMin: 180,
          ordenarPor: (c) => c.clienteDenominacion.toLowerCase(),
          celda: (c) {
            final nombre = c.clienteDenominacion.isEmpty
                ? 'CLIENTES VARIOS'
                : c.clienteDenominacion;
            final doc = c.clienteNumDoc.isEmpty || c.clienteNumDoc == '00000000'
                ? null
                : c.clienteNumDoc;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TablaApp.texto(nombre),
                if (doc != null)
                  Text(
                    doc,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            );
          },
        ),
        ColumnaTabla(
          titulo: 'Total',
          ancho: 100,
          alineacion: Alignment.centerRight,
          ordenarPor: (c) => c.total,
          celda: (c) => TablaApp.texto('S/ ${c.total.toStringAsFixed(2)}'),
        ),
        ColumnaTabla(
          titulo: 'Estado',
          ancho: 120,
          rol: RolTarjeta.estado,
          ordenarPor: (c) => c.estadoEtiqueta,
          celda: (c) => Align(
            alignment: Alignment.centerLeft,
            child: _etiqueta(c.estadoEtiqueta, _color(c)),
          ),
        ),
        ColumnaTabla(
          titulo: 'Acciones',
          ancho: 130,
          rol: RolTarjeta.acciones,
          celda: _acciones,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filas = _filas;
    final margen = AppBreakpoints.esMobile(context) ? 16.0 : 24.0;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.fromLTRB(margen, 20, margen, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Comprobantes',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Boletas y facturas emitidas, sin importar el cierre de caja.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _grupoTipo(),
                SelectorRangoFechas(
                  valor: _rango,
                  conAtajos: false,
                  onChanged: (r) {
                    setState(() => _rango = r ?? _hoy());
                    _cargar();
                  },
                ),
                AppSearchField(
                  controller: _busqueda,
                  hint: 'Buscar...',
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            if (_errorCarga != null) ...[
              const SizedBox(height: 8),
              Text(
                'No se pudieron leer los comprobantes: $_errorCarga',
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ],
            if (filas.isNotEmpty) ...[
              const SizedBox(height: 12),
              _resumen(filas),
              const SizedBox(height: 4),
              Text(
                'Los montos no incluyen comprobantes anulados ni rechazados.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _cargando && _lista.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filas.isEmpty
                  ? Center(
                      child: Text(
                        'Sin comprobantes en este rango',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : _tabla(filas),
            ),
          ],
        ),
      ),
    );
  }
}
