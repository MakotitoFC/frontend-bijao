import 'package:flutter/material.dart';

import '../models/utensilio_roto.dart';
import '../services/rotura_service.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'campo_texto.dart';
import 'dialogo_app.dart';

// Anular una rotura desde Inventario. Pide el motivo (obligatorio), avisa lo que
// se deshace (stock que vuelve al almacén e ingresos de Caja que se anulan) y,
// al confirmar, lo hace todo junto. La rotura no se borra: queda como anulada
// con su motivo. Devuelve true si se anuló.
class AnularRoturaDialog extends StatefulWidget {
  final UtensilioRoto rotura;

  const AnularRoturaDialog({super.key, required this.rotura});

  @override
  State<AnularRoturaDialog> createState() => _AnularRoturaDialogState();
}

class _AnularRoturaDialogState extends State<AnularRoturaDialog> {
  final _motivo = TextEditingController();
  EfectoAnulacion? _efecto;
  bool _anulando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    RoturaService.instance.efectoDeRotura(widget.rotura).then((e) {
      if (mounted) setState(() => _efecto = e);
    });
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _anular() async {
    if (_motivo.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el motivo de la anulación.');
      return;
    }
    setState(() {
      _anulando = true;
      _error = null;
    });
    try {
      final r = await RoturaService.instance.anularRotura(
        widget.rotura,
        motivo: _motivo.text,
      );
      if (!mounted) return;
      if (!r.completo) {
        showAppToast(
          context,
          'Rotura anulada, pero: ${r.avisos.join(' ')}',
          type: ToastType.error,
          duration: const Duration(seconds: 7),
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _anulando = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _efecto;
    final tieneCodigo = codigoDeRotura(widget.rotura.notas) != null;
    return DialogoApp(
      titulo: 'Anular rotura',
      ancho: 440,
      acciones: [
        OutlinedButton(
          onPressed: _anulando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _anulando ? null : _anular,
          child: const Text('Anular rotura'),
        ),
      ],
      children: [
        Text(
          'La rotura queda en la lista como anulada, con su motivo.',
          style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        if (!tieneCodigo)
          Text(
            'Es un registro antiguo: no se puede saber qué stock ni qué '
            'ingresos de Caja le corresponden. Si los hubo, anúlalos aparte.',
            style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
          )
        else if (e == null)
          Text(
            'Calculando lo que se deshará…',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          )
        else if (e.vacio)
          Text(
            'No tiene stock por devolver ni ingresos de Caja por anular.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          )
        else ...[
          if (e.stock.isNotEmpty) ...[
            Text(
              'Vuelve al almacén:',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
            for (final l in e.stock)
              Text('• $l', style: const TextStyle(fontSize: 13)),
          ],
          if (e.ingresosCaja > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Se anula${e.ingresosCaja == 1 ? '' : 'n'} '
              '${e.ingresosCaja} ingreso${e.ingresosCaja == 1 ? '' : 's'} de '
              'Caja por S/ ${e.montoCaja.toStringAsFixed(2)}. Si ya se cobró, '
              'devuelve ese dinero.',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ],
        const SizedBox(height: 14),
        CampoTexto(
          controller: _motivo,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Motivo de la anulación',
          ),
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
