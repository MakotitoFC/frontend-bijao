import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/turno.dart';
import '../services/caja_service.dart';
import '../theme/app_theme.dart';
import '../utils/blur_dialog.dart';
import 'app_toast.dart';
import 'dialogo_app.dart';

class TurnosConfigWidget extends StatefulWidget {
  const TurnosConfigWidget({super.key});

  @override
  State<TurnosConfigWidget> createState() => _TurnosConfigWidgetState();
}

class _TurnosConfigWidgetState extends State<TurnosConfigWidget> {
  List<Turno> _turnos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final list = await CajaService.instance.cargarTurnos();
      if (!mounted) return;
      setState(() {
        _turnos = list;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _crearOEditarTurno([Turno? turno]) async {
    final nombreCtrl = TextEditingController(text: turno?.nombre ?? '');
    final inicioCtrl = TextEditingController(text: turno?.horaInicio ?? '11:00');
    final finCtrl = TextEditingController(text: turno?.horaFin ?? '17:00');
    final ordenCtrl = TextEditingController(text: (turno?.orden ?? (_turnos.length + 1)).toString());

    final confirmado = await showBlurDialog<bool>(
      context: context,
      builder: (ctx) => AlertaApp(
        title: Text(turno == null ? 'Nuevo Turno de Caja' : 'Editar Turno'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del turno',
                  hintText: 'Ej. Turno Almuerzo, Turno Noche',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: inicioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hora inicio (HH:MM)',
                        hintText: '11:00',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: finCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hora fin (HH:MM)',
                        hintText: '17:00',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ordenCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Orden de secuencia',
                  hintText: '1',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      showAppToast(context, 'El nombre del turno es obligatorio', type: ToastType.error);
      return;
    }

    final orden = int.tryParse(ordenCtrl.text.trim()) ?? 1;

    try {
      if (turno == null) {
        await CajaService.instance.crearTurno(
          nombre: nombre,
          horaInicio: inicioCtrl.text.trim(),
          horaFin: finCtrl.text.trim(),
          orden: orden,
        );
        if (mounted) {
          showAppToast(context, 'Turno creado con éxito', type: ToastType.success);
        }
      } else {
        await CajaService.instance.actualizarTurno(
          turno.id,
          nombre: nombre,
          horaInicio: inicioCtrl.text.trim(),
          horaFin: finCtrl.text.trim(),
          orden: orden,
        );
        if (mounted) {
          showAppToast(context, 'Turno actualizado con éxito', type: ToastType.success);
        }
      }
      _cargar();
    } catch (e) {
      if (mounted) {
        showAppToast(context, e.toString(), type: ToastType.error);
      }
    }
  }

  Future<void> _toggleEstado(Turno turno) async {
    try {
      await CajaService.instance.actualizarTurno(turno.id, estado: !turno.estado);
      _cargar();
    } catch (e) {
      if (mounted) showAppToast(context, e.toString(), type: ToastType.error);
    }
  }

  Future<void> _eliminarTurno(Turno turno) async {
    final conf = await showBlurDialog<bool>(
      context: context,
      builder: (ctx) => AlertaApp(
        title: const Text('Eliminar Turno'),
        content: Text('¿Deseas eliminar el turno "${turno.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (conf != true || !mounted) return;

    try {
      await CajaService.instance.eliminarTurno(turno.id);
      if (mounted) showAppToast(context, 'Turno eliminado', type: ToastType.success);
      _cargar();
    } catch (e) {
      if (mounted) showAppToast(context, e.toString(), type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Turnos de Caja Operativos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Configura los turnos diarios de tu local para cierres y reportes independientes.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: () => _crearOEditarTurno(),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Nuevo Turno'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text(_error!, style: const TextStyle(color: AppColors.error)),
          ),
        if (_turnos.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text('No hay turnos registrados. Crea un turno para organizar tus aperturas.'),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _turnos.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, idx) {
                final t = _turnos[idx];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t.estado ? AppColors.primaryGreen.withOpacity(0.12) : Colors.grey.shade100,
                    child: Icon(
                      LucideIcons.clock,
                      size: 20,
                      color: t.estado ? AppColors.primaryGreen : Colors.grey.shade400,
                    ),
                  ),
                  title: Text(
                    t.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: t.estado ? Colors.black87 : Colors.grey.shade500,
                    ),
                  ),
                  subtitle: Text(
                    'Horario: ${t.horaInicio} - ${t.horaFin} · Orden #${t.orden}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: t.estado,
                        activeColor: AppColors.primaryGreen,
                        onChanged: (_) => _toggleEstado(t),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.edit2, size: 18),
                        onPressed: () => _crearOEditarTurno(t),
                        tooltip: 'Editar turno',
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.error),
                        onPressed: () => _eliminarTurno(t),
                        tooltip: 'Eliminar turno',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
