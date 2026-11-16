import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../data/inventario_periodo.dart';
import '../../data/inventario_store.dart';
import '../../models/inventario_movimiento.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/reporte_inventario.dart';
import '../../utils/reporte_inventario_pdf.dart';
import '../app_toast.dart';
import '../tabs_texto.dart';
import 'inventario_comun.dart';

// Inventario > Reportes: qué entró, qué salió y cómo quedó el stock en el día
// elegido (un día a la vez, como el historial de ventas). Se descarga en PDF del
// día que esté elegido.
class PaginaReportes extends StatefulWidget {
  const PaginaReportes({super.key});

  @override
  State<PaginaReportes> createState() => _PaginaReportesState();
}

class _PaginaReportesState extends State<PaginaReportes> {
  String _vista = 'productos'; // productos | movimientos
  bool _cargando = true;
  String? _error;

  DateTimeRange get _periodo => periodoInventarioNotifier.value;

  @override
  void initState() {
    super.initState();
    periodoInventarioNotifier.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    periodoInventarioNotifier.removeListener(_cargar);
    super.dispose();
  }

  // Del libro de inventario se pide solo desde el inicio del periodo hasta hoy
  // (lo posterior hace falta para llegar al stock final de cada producto) y el
  // stock actual. Al cambiar el periodo se vuelve a pedir.
  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    String? error;
    try {
      await Future.wait([
        CatalogService.instance.cargarMovimientosInventario(
          desde: _periodo.start,
        ),
        CatalogService.instance.cargarProductosInventario(),
      ]);
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) {
      setState(() {
        _cargando = false;
        _error = error;
      });
    }
  }

  // Sin armar una lista aparte: se recorre lo que ya está cargado.
  Iterable<InventarioMovimiento> get _todos =>
      movimientosInventario.values.expand((lista) => lista);

  ReporteInventarioDia get _reporte => calcularReporteInventario(
    desde: _periodo.start,
    hasta: _periodo.end,
    movimientos: _todos,
    productos: productosInventario,
  );

  bool _generando = false;

  // Genera el PDF del día elegido y lo descarga (en la web baja como archivo; en
  // el celular y en escritorio abre el guardado).
  Future<void> _descargar(ReporteInventarioDia r) async {
    if (_generando) return;
    setState(() => _generando = true);
    try {
      final bytes = await reporteInventarioPdf(r, unidadDe: unidadDe);
      await FilePicker.saveFile(
        fileName:
            'inventario-${fechaIso(r.dia)}${r.esUnDia ? '' : '-al-${fechaIso(r.hasta)}'}.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      if (!mounted) return;
      showAppToast(
        context,
        r.esUnDia
            ? 'Reporte del ${fechaCorta(r.dia)} descargado.'
            : 'Reporte del ${fechaCorta(r.dia)} al ${fechaCorta(r.hasta)} descargado.',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'No se pudo generar el PDF: '
        '${e.toString().replaceFirst('Exception: ', '')}',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Widget _filaProducto(FilaReporteProducto p) {
    final u = unidadDe(p.unidadId);
    final neto = p.neto;
    return FilaInventario(
      titulo: nombreFila(p.nombre),
      detalle:
          'Inicio ${cantidadTexto(p.inicio)} · '
          'Entró ${cantidadTexto(p.entradas)} · '
          'Salió ${cantidadTexto(p.salidas)} · '
          'Final ${cantidadTexto(p.fin)} $u',
      controles: [
        Text(
          '${neto > 0 ? '+' : ''}${cantidadTexto(neto)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: neto > 0
                ? AppColors.primaryGreen
                : (neto < 0 ? AppColors.error : Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _filaMovimiento(InventarioMovimiento m) {
    final entrada = m.tipoMovimiento.esEntrada;
    final detalle = [
      horaCorta(m.fecha),
      if ((m.usuarioNombre ?? '').isNotEmpty) m.usuarioNombre!,
      if ((m.notas ?? '').isNotEmpty) m.notas!,
    ].join(' · ');
    return FilaInventario(
      titulo: tituloConEtiquetas(m.productoNombre ?? 'Producto', [
        EtiquetaFila(
          m.tipoMovimiento.tipoMovimiento,
          color: entrada ? AppColors.primaryGreen : AppColors.error,
        ),
      ]),
      detalle: detalle,
      controles: [
        Text(
          '${entrada ? '+' : '-'}${cantidadTexto(m.cantidad)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: entrada ? AppColors.primaryGreen : AppColors.error,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _reporte;
    final porProducto = _vista == 'productos';
    final cantidad = porProducto ? r.productos.length : r.movimientos.length;
    return PaginaListaFija(
      reiniciarCon: '$_vista|${fechaIso(_periodo.start)}|${fechaIso(_periodo.end)}',
      cantidad: cantidad,
      filaEn: (i) => porProducto
          ? _filaProducto(r.productos[i])
          : _filaMovimiento(r.movimientos[r.movimientos.length - 1 - i]),
      cabecera: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CabeceraSeccion(
            titulo: 'Reportes',
            descripcion:
                'Qué entró, qué salió y cómo quedó el stock en las fechas que '
                'elijas arriba.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _cargando || _generando || r.vacio
                    ? null
                    : () => _descargar(r),
                icon: const Icon(LucideIcons.download, size: 16),
                label: Text(_generando ? 'Generando…' : 'Descargar PDF'),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _cargando ? null : _cargar,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CifrasDelDia(
            tarjetas: [
              TarjetaKpi(
                icono: LucideIcons.arrowLeftRight,
                color: Colors.blueGrey,
                titulo: 'Movimientos',
                valor: '${r.movimientos.length}',
              ),
              TarjetaKpi(
                icono: LucideIcons.arrowDownLeft,
                color: AppColors.primaryGreen,
                titulo: 'Entradas',
                valor: '${r.cantidadEntradas}',
              ),
              TarjetaKpi(
                icono: LucideIcons.arrowUpRight,
                color: AppColors.error,
                titulo: 'Salidas',
                valor: '${r.cantidadSalidas}',
              ),
              TarjetaKpi(
                icono: LucideIcons.wallet,
                color: Colors.orange.shade700,
                titulo: 'Costo de compras',
                valor: 'S/ ${r.costoEntradas.toStringAsFixed(2)}',
              ),
            ],
          ),
        ],
      ),
      barra: TabsTexto(
        tabs: [
          TabTexto(
            etiqueta: 'Por producto',
            activa: porProducto,
            onTap: () => setState(() => _vista = 'productos'),
          ),
          TabTexto(
            etiqueta: 'Detalle',
            activa: !porProducto,
            onTap: () => setState(() => _vista = 'movimientos'),
          ),
        ],
      ),
      mensajeVacio: _cargando
          ? 'Cargando…'
          : (_error != null
                ? 'No se pudo leer el inventario: $_error'
                : 'No hubo movimientos de inventario en esas fechas.'),
    );
  }
}

// Las cifras del día: cuatro en una fila si caben y dos por fila en celular,
// para que la lista de abajo conserve sitio.
class _CifrasDelDia extends StatelessWidget {
  final List<Widget> tarjetas;

  const _CifrasDelDia({required this.tarjetas});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth < 560 ? 2 : tarjetas.length;
        final ancho = (c.maxWidth - 12 * (columnas - 1)) / columnas;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in tarjetas) SizedBox(width: ancho, child: t),
          ],
        );
      },
    );
  }
}
