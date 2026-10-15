import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../data/inventario_store.dart';
import '../../data/utensilios_store.dart';
import '../../models/rbac.dart';
import '../../models/utensilio_roto.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/blur_dialog.dart';
import '../app_search_field.dart';
import '../app_tag.dart';
import '../app_toast.dart';
import '../pago_cuenta_empleado_dialog.dart';
import '../tabs_desplazables.dart';
import '../utensilio_roto_form_dialog.dart';
import 'inventario_comun.dart';

// Inventario > Utensilios rotos: roturas de menaje que el empleado paga a cuenta
// de su sueldo o repone en físico.
class PaginaUtensilios extends StatefulWidget {
  const PaginaUtensilios({super.key});

  @override
  State<PaginaUtensilios> createState() => _PaginaUtensiliosState();
}

class _PaginaUtensiliosState extends State<PaginaUtensilios> {
  String _busqueda = '';
  String _filtro = 'todos'; // todos, cobro, reposicion, resueltos
  bool _cargando = false;
  List<UserRBACModel> _empleados = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await Future.wait([
        CatalogService.instance.cargarUtensiliosRotos(),
        CatalogService.instance.cargarProductosInventario(),
        CatalogService.instance.cargarUsuariosRBAC(),
      ]);
      if (mounted) {
        setState(() {
          _empleados = res[2] as List<UserRBACModel>;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _nombreProducto(UtensilioRoto u) {
    if (u.productoNombre != null && u.productoNombre!.isNotEmpty) {
      return u.productoNombre!;
    }
    return productosInventario
            .where((p) => p.id == u.productoInventarioId)
            .map((p) => p.nombre)
            .firstOrNull ??
        'Producto';
  }

  String _nombreEmpleado(UtensilioRoto u) {
    if (u.empleadoNombre != null && u.empleadoNombre!.isNotEmpty) {
      return u.empleadoNombre!;
    }
    return _empleados
            .where((e) => e.id == u.empleadoId)
            .map((e) => e.usuario)
            .firstOrNull ??
        'Empleado';
  }

  Future<void> _registrar() async {
    final r = await showBlurDialog<bool>(
      context: context,
      builder: (_) => const UtensilioRotoFormDialog(),
    );
    if (r == true) _cargar();
  }

  Future<void> _abonarPago(UtensilioRoto u) async {
    final pagado = await showBlurDialog<bool>(
      context: context,
      builder: (_) => PagoCuentaEmpleadoDialog(rotura: u),
    );
    if (pagado == true) _cargar();
  }

  Future<void> _marcarRepuesto(UtensilioRoto u) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Confirmar reposición',
      mensaje:
          '¿Confirmar que el empleado ya repuso "${_nombreProducto(u)}" en '
          'físico? El registro quedará resuelto.',
      etiqueta: 'Confirmar',
      peligro: false,
    );
    if (!ok) return;
    try {
      await CatalogService.instance.actualizarUtensilioRoto(
        u.copyWith(done: true),
      );
      if (!mounted) return;
      showAppToast(
        context,
        'Reposición registrada como completada',
        type: ToastType.success,
      );
      _cargar();
    } catch (e) {
      if (mounted) showAppToast(context, 'Error: $e', type: ToastType.error);
    }
  }

  Future<void> _eliminar(UtensilioRoto u) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar registro',
      mensaje: '¿Eliminar el registro de rotura de "${_nombreProducto(u)}"?',
    );
    if (!ok) return;
    try {
      await CatalogService.instance.eliminarUtensilioRoto(u.id);
      if (!mounted) return;
      showAppToast(context, 'Registro eliminado', type: ToastType.success);
      _cargar();
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error al eliminar: $e', type: ToastType.error);
      }
    }
  }

  List<UtensilioRoto> get _filtrados {
    final q = _busqueda.trim().toLowerCase();
    return utensiliosRotos.where((u) {
      if (q.isNotEmpty) {
        final enNombre = _nombreProducto(u).toLowerCase().contains(q);
        final enEmpleado = _nombreEmpleado(u).toLowerCase().contains(q);
        final enNotas = (u.notas ?? '').toLowerCase().contains(q);
        if (!enNombre && !enEmpleado && !enNotas) return false;
      }
      return switch (_filtro) {
        'cobro' => u.isPagado,
        'reposicion' => u.isRepuesto,
        'resueltos' => u.done,
        _ => true,
      };
    }).toList();
  }

  Widget _estado(UtensilioRoto u) {
    if (u.done) {
      return const EtiquetaFila('Resuelto', color: AppColors.primaryGreen);
    }
    if (u.isPagado) {
      return EtiquetaFila('A cuenta de sueldo', color: Colors.amber.shade800);
    }
    if (u.isRepuesto) {
      return EtiquetaFila('Por reponer', color: Colors.blue.shade700);
    }
    return const SizedBox.shrink();
  }

  Widget _fila(UtensilioRoto u) {
    final saldo = (u.costoTotal - u.totalPagado).clamp(0.0, u.costoTotal);
    final progreso = u.costoTotal > 0
        ? (u.totalPagado / u.costoTotal).clamp(0.0, 1.0)
        : 1.0;
    final notas = (u.notas ?? '').isNotEmpty ? ' · ${u.notas}' : '';
    return FilaInventario(
      titulo: tituloConEtiquetas('${u.cantidad}x ${_nombreProducto(u)}', [
        _estado(u),
      ]),
      detalle: '${_nombreEmpleado(u)} · ${fechaCorta(u.fecha)}$notas',
      controles: [
        Text(
          'S/ ${u.costoTotal.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        if (!u.done && u.isPagado)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton(
              onPressed: () => _abonarPago(u),
              child: const Text('Abonar pago'),
            ),
          ),
        if (!u.done && u.isRepuesto)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton(
              onPressed: () => _marcarRepuesto(u),
              child: const Text('Confirmar reposición'),
            ),
          ),
        IconButton(
          tooltip: 'Eliminar registro',
          onPressed: () => _eliminar(u),
          icon: const Icon(
            LucideIcons.trash2,
            size: 16,
            color: AppColors.error,
          ),
        ),
      ],
      extra: u.isPagado
          ? Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progreso,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      color: u.done
                          ? AppColors.primaryGreen
                          : Colors.amber.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Abonado S/ ${u.totalPagado.toStringAsFixed(2)} de S/ ${u.costoTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        saldo > 0
                            ? 'Saldo S/ ${saldo.toStringAsFixed(2)}'
                            : 'Saldado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: saldo > 0
                              ? AppColors.error
                              : AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _filtroChip(String etiqueta, String valor) => AppTag(
    etiqueta: etiqueta,
    activo: _filtro == valor,
    onTap: () => setState(() => _filtro = valor),
  );

  @override
  Widget build(BuildContext context) {
    final costo = utensiliosRotos.fold(0.0, (s, u) => s + u.costoTotal);
    final pendientes = utensiliosRotos.where((u) => !u.done).length;
    final resueltos = utensiliosRotos.where((u) => u.done).length;
    final lista = _filtrados;
    return PaginaInventario(
      secciones: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CabeceraSeccion(
              titulo: 'Utensilios rotos',
              descripcion:
                  'Registra roturas para descontar del stock y cobrar o '
                  'reponer con el empleado.',
            ),
            const SizedBox(height: 14),
            FilaKpi(
              tarjetas: [
                TarjetaKpi(
                  icono: Icons.payments_outlined,
                  color: Colors.orange.shade600,
                  titulo: 'Costo acumulado',
                  valor: 'S/ ${costo.toStringAsFixed(2)}',
                ),
                TarjetaKpi(
                  icono: Icons.pending_actions,
                  color: Colors.amber.shade700,
                  titulo: 'Pendientes',
                  valor: '$pendientes',
                ),
                TarjetaKpi(
                  icono: Icons.check_circle_outline,
                  color: AppColors.primaryGreen,
                  titulo: 'Resueltos',
                  valor: '$resueltos',
                ),
              ],
            ),
          ],
        ),
        SeccionInventario(
          titulo: 'Registros',
          accion: BotonNuevo(etiqueta: 'Rotura', onPressed: _registrar),
          barra: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AppSearchField(
                  hint: 'Buscar por producto o empleado...',
                  onChanged: (v) => setState(() => _busqueda = v),
                ),
              ),
              const SizedBox(height: 12),
              TabsDesplazables(
                child: Row(
                  children: [
                    _filtroChip('Todos', 'todos'),
                    _filtroChip('Por cobrar', 'cobro'),
                    _filtroChip('Por reponer', 'reposicion'),
                    _filtroChip('Resueltos', 'resueltos'),
                  ],
                ),
              ),
            ],
          ),
          mensajeVacio: _cargando && utensiliosRotos.isEmpty
              ? 'Cargando…'
              : (utensiliosRotos.isEmpty
                    ? 'Aún no hay roturas registradas.'
                    : 'Ningún registro coincide con los filtros.'),
          filas: [for (final u in lista) _fila(u)],
        ),
      ],
    );
  }
}
