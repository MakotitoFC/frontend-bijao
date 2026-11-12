import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/utensilios_store.dart';
import '../models/utensilio_roto.dart';
import '../services/catalog_service.dart';
import '../services/rotura_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'dialogo_app.dart';
import 'pago_cuenta_empleado_dialog.dart';

// Aviso de Caja (Ingresos y salidas): las roturas de mozos que aún se deben a
// cuenta de su sueldo. "Cobrar roturas" abre la lista y, de ahí, el mismo
// diálogo de abono de Inventario: no hace falta cambiar de módulo. No aparece si
// no hay nada por cobrar (o si el usuario no puede leer las roturas).
class RoturasPorCobrarAviso extends StatefulWidget {
  // Se llama después de un abono, para que Caja relea sus movimientos.
  final VoidCallback? onCobrado;
  // Con la caja cerrada no se puede anotar el ingreso del abono.
  final bool cajaCerrada;

  const RoturasPorCobrarAviso({
    super.key,
    this.onCobrado,
    this.cajaCerrada = false,
  });

  @override
  State<RoturasPorCobrarAviso> createState() => _RoturasPorCobrarAvisoState();
}

List<UtensilioRoto> _porCobrar() => [
  for (final u in utensiliosRotos)
    if (u.porCobrar) u,
];

class _RoturasPorCobrarAvisoState extends State<RoturasPorCobrarAviso> {
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      await CatalogService.instance.cargarUtensiliosRotos();
    } catch (_) {
      // Sin permiso o sin red: se muestra lo que ya hubiera en memoria.
    }
    if (mounted) setState(() {});
  }

  Future<void> _abrir() async {
    await showBlurDialog<void>(
      context: context,
      builder: (_) => _ListaRoturasPorCobrar(
        cajaCerrada: widget.cajaCerrada,
        onCobrado: widget.onCobrado,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _porCobrar();
    if (pendientes.isEmpty) return const SizedBox.shrink();
    final total = pendientes.fold(0.0, (s, u) => s + u.saldo);
    final n = pendientes.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(AppRadii.tag),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(LucideIcons.hammer, size: 18, color: Colors.amber.shade800),
            Text(
              'Hay $n rotura${n == 1 ? '' : 's'} de mozos por cobrar · '
              'S/ ${total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            OutlinedButton(
              onPressed: _abrir,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSizes.control),
              ),
              child: const Text('Cobrar roturas'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaRoturasPorCobrar extends StatefulWidget {
  final bool cajaCerrada;
  final VoidCallback? onCobrado;

  const _ListaRoturasPorCobrar({required this.cajaCerrada, this.onCobrado});

  @override
  State<_ListaRoturasPorCobrar> createState() => _ListaRoturasPorCobrarState();
}

class _ListaRoturasPorCobrarState extends State<_ListaRoturasPorCobrar> {
  Future<void> _abonar(UtensilioRoto u) async {
    final pagado = await showBlurDialog<bool>(
      context: context,
      builder: (_) => PagoCuentaEmpleadoDialog(rotura: u),
    );
    if (pagado != true) return;
    try {
      await CatalogService.instance.cargarUtensiliosRotos();
    } catch (_) {}
    widget.onCobrado?.call();
    if (!mounted) return;
    setState(() {});
    if (_porCobrar().isEmpty) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lista = _porCobrar();
    return DialogoApp(
      titulo: 'Roturas por cobrar',
      ancho: 480,
      acciones: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
      children: [
        if (widget.cajaCerrada)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'La caja está cerrada: ábrela para anotar el ingreso del abono.',
              style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
            ),
          ),
        for (final u in lista)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${u.cantidad}x ${u.productoNombre ?? 'Item'}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        [
                          u.empleadoNombre ?? 'Empleado',
                          'Saldo S/ ${u.saldo.toStringAsFixed(2)} de '
                              'S/ ${u.costoTotal.toStringAsFixed(2)}',
                          if (notaSinCodigo(u.notas).isNotEmpty)
                            notaSinCodigo(u.notas),
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: widget.cajaCerrada ? null : () => _abonar(u),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.control),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                  child: const Text('Abonar'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
