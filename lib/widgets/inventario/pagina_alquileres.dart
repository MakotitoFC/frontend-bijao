import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../data/inventario_store.dart';
import '../../services/alquiler_service.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/blur_dialog.dart';
import '../alquiler_dialog.dart';
import '../app_search_field.dart';
import '../app_toast.dart';
import '../campo_texto.dart';
import '../dialogo_app.dart';
import '../tabs_texto.dart';
import 'inventario_comun.dart';

// Inventario > Movimientos > Alquileres: manteles y otro menaje que se alquila.
// Cada alquiler es un ingreso de Caja y una salida del almacén; al devolverlo
// vuelve al almacén. Aquí se registran, editan y anulan.
class PaginaAlquileres extends StatefulWidget {
  const PaginaAlquileres({super.key});

  @override
  State<PaginaAlquileres> createState() => _PaginaAlquileresState();
}

class _PaginaAlquileresState extends State<PaginaAlquileres> {
  String _busqueda = '';
  String _filtro = 'todos'; // todos, afuera, devueltos, anulados
  bool _cargando = true;
  List<Alquiler> _lista = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    try {
      await CatalogService.instance.cargarProductosInventario();
      final lista = await AlquilerService.instance.listar();
      if (mounted) setState(() => _lista = lista);
    } catch (_) {
      // Sin conexión: se queda lo que ya había.
    }
    if (mounted) setState(() => _cargando = false);
  }

  String _producto(Alquiler a) =>
      productosInventario
          .where((p) => p.id == a.productoId)
          .firstOrNull
          ?.nombre ??
      'Producto';

  Future<void> _nuevo([Alquiler? editar]) async {
    final r = await showBlurDialog<bool>(
      context: context,
      builder: (_) => AlquilerDialog(alquiler: editar),
    );
    if (r != true || !mounted) return;
    showAppToast(
      context,
      editar == null
          ? 'Alquiler cobrado y registrado en Caja.'
          : 'Alquiler actualizado.',
      type: ToastType.success,
    );
    await _cargar();
  }

  Future<void> _devolver(Alquiler a) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Devolver alquiler',
      mensaje:
          '¿El cliente ya devolvió ${a.cantidad}× ${_producto(a)}? Las '
          'unidades vuelven al almacén.',
      etiqueta: 'Devolver',
      peligro: false,
    );
    if (!ok || !mounted) return;
    try {
      await AlquilerService.instance.devolver(a);
      if (!mounted) return;
      showAppToast(
        context,
        'Devuelto: ${a.cantidad}× ${_producto(a)} volvió al almacén.',
        type: ToastType.success,
      );
      await _cargar();
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _anular(Alquiler a) async {
    final motivo = await showBlurDialog<String>(
      context: context,
      builder: (_) => _MotivoDialog(
        titulo: 'Anular alquiler',
        aviso:
            'Se anula el ingreso de Caja y ${a.devuelto ? 'se deshacen la salida y la devolución' : 'las unidades vuelven al almacén'}. '
            'El registro queda visible como anulado.',
      ),
    );
    if (motivo == null || !mounted) return;
    try {
      await AlquilerService.instance.anular(a, motivo: motivo);
      if (!mounted) return;
      showAppToast(context, 'Alquiler anulado.', type: ToastType.success);
      await _cargar();
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          type: ToastType.error,
        );
      }
    }
  }

  List<Alquiler> get _filtrados {
    final q = _busqueda.trim().toLowerCase();
    return [
      for (final a in _lista)
        if ((q.isEmpty ||
                _producto(a).toLowerCase().contains(q) ||
                a.cliente.toLowerCase().contains(q) ||
                (a.notas ?? '').toLowerCase().contains(q)) &&
            switch (_filtro) {
              'afuera' => a.afuera,
              'devueltos' => a.devuelto && !a.anulado,
              'anulados' => a.anulado,
              _ => true,
            })
          a,
    ];
  }

  TabTexto _tab(String etiqueta, String valor, int cantidad) => TabTexto(
    etiqueta: etiqueta,
    cantidad: cantidad,
    activa: _filtro == valor,
    onTap: () => setState(() => _filtro = valor),
  );

  Widget _fila(Alquiler a) {
    final fecha = fechaCorta(a.movimiento.fecha);
    final detalle = [
      fecha,
      if (a.cliente.isNotEmpty) a.cliente,
      'S/ ${a.monto.toStringAsFixed(2)}',
      a.movimiento.medioPagoNombre,
      if (a.anulado && a.movimiento.motivoAnulacion != null)
        'Motivo: ${a.movimiento.motivoAnulacion}',
    ].where((x) => x.isNotEmpty).join(' · ');
    return FilaInventario(
      titulo: tituloConEtiquetas('${a.cantidad}× ${_producto(a)}', [
        if (a.anulado)
          const EtiquetaFila('Anulado', color: AppColors.error)
        else if (a.devuelto)
          const EtiquetaFila('Devuelto', color: AppColors.primaryGreen)
        else
          EtiquetaFila('Afuera', color: Colors.amber.shade800),
      ], activo: !a.anulado),
      detalle: detalle,
      controles: [
        if (a.afuera)
          OutlinedButton(
            onPressed: () => _devolver(a),
            child: const Text('Devolver'),
          ),
        if (!a.anulado) ...[
          IconButton(
            tooltip: 'Editar',
            onPressed: () => _nuevo(a),
            icon: Icon(
              LucideIcons.pencil,
              size: 16,
              color: Colors.grey.shade700,
            ),
          ),
          IconButton(
            tooltip: 'Anular',
            onPressed: () => _anular(a),
            icon: const Icon(LucideIcons.ban, size: 16, color: AppColors.error),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtrados;
    return PaginaListaFija(
      reiniciarCon: '$_busqueda|$_filtro',
      cabecera: CabeceraSeccion(
        titulo: 'Alquileres',
        descripcion:
            'Manteles y otro menaje que se alquila. Cada alquiler cobra en '
            'Caja y saca el producto del almacén hasta que lo devuelven.',
        accion: BotonNuevo(etiqueta: 'Alquiler', onPressed: () => _nuevo()),
      ),
      barra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppSearchField(
              hint: 'Buscar...',
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
          const SizedBox(height: 12),
          TabsTexto(
            tabs: [
              _tab('Todos', 'todos', _lista.length),
              _tab('Afuera', 'afuera', _lista.where((a) => a.afuera).length),
              _tab(
                'Devueltos',
                'devueltos',
                _lista.where((a) => a.devuelto && !a.anulado).length,
              ),
              _tab(
                'Anulados',
                'anulados',
                _lista.where((a) => a.anulado).length,
              ),
            ],
          ),
        ],
      ),
      mensajeVacio: _cargando && _lista.isEmpty
          ? 'Cargando…'
          : (_lista.isEmpty
                ? 'Aún no hay alquileres. Registra el primero con "Alquiler".'
                : 'Ningún alquiler coincide con los filtros.'),
      filas: [for (final a in lista) _fila(a)],
    );
  }
}

// Pide el motivo de una anulación. Devuelve el texto o null si se cancela.
class _MotivoDialog extends StatefulWidget {
  final String titulo;
  final String aviso;

  const _MotivoDialog({required this.titulo, required this.aviso});

  @override
  State<_MotivoDialog> createState() => _MotivoDialogState();
}

class _MotivoDialogState extends State<_MotivoDialog> {
  final _motivo = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoApp(
      titulo: widget.titulo,
      ancho: 440,
      acciones: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () {
            if (_motivo.text.trim().isEmpty) {
              setState(() => _error = 'Escribe el motivo de la anulación.');
              return;
            }
            Navigator.of(context).pop(_motivo.text.trim());
          },
          child: const Text('Anular'),
        ),
      ],
      children: [
        Text(
          widget.aviso,
          style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 14),
        CampoTexto(
          controller: _motivo,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Motivo de la anulación',
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(fontSize: 12.5, color: AppColors.error),
          ),
        ],
      ],
    );
  }
}
