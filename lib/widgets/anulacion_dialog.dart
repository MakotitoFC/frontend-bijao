import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';
import 'dialogo_app.dart';
import 'campo_texto.dart';

// Datos de una anulación: el motivo es obligatorio; la foto es opcional.
class ResultadoAnulacion {
  final String motivo;
  final int cantidad;
  final List<int>? foto;
  final String? nombreFoto;

  const ResultadoAnulacion({
    required this.motivo,
    required this.cantidad,
    this.foto,
    this.nombreFoto,
  });
}

// Anular un pedido o un producto (total o parcialmente, con [maxCantidad] > 1).
class AnulacionDialog extends StatefulWidget {
  final String titulo;
  final String detalle;
  final int maxCantidad;

  const AnulacionDialog({
    super.key,
    required this.titulo,
    required this.detalle,
    this.maxCantidad = 1,
  });

  @override
  State<AnulacionDialog> createState() => _AnulacionDialogState();
}

class _AnulacionDialogState extends State<AnulacionDialog> {
  final _motivo = TextEditingController();
  late int _cantidad = widget.maxCantidad;
  List<int>? _foto;
  String? _nombreFoto;
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto() async {
    try {
      final archivos = await FilePicker.pickFiles(type: FileType.image);
      if (archivos.isEmpty) return;
      final f = archivos.first;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        _foto = bytes;
        _nombreFoto = f.name;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo leer la foto: $e');
    }
  }

  void _confirmar() {
    final motivo = _motivo.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'Escribe el motivo de la anulación.');
      return;
    }
    Navigator.of(context).pop(
      ResultadoAnulacion(
        motivo: motivo,
        cantidad: _cantidad,
        foto: _foto,
        nombreFoto: _nombreFoto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esMobile = AppBreakpoints.esMobile(context);
    final ancho = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.white,
      borderRadius: esMobile
          ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))
          : BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: esMobile ? ancho : 420,
          maxWidth: esMobile ? ancho : 420,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            esMobile ? 28 : 22,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.titulo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  BotonCerrarCircular(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SeparadorDialogo(),
              Text(
                widget.detalle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              if (widget.maxCantidad > 1) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Unidades a anular',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      onPressed: _cantidad > 1
                          ? () => setState(() => _cantidad--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$_cantidad de ${widget.maxCantidad}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      onPressed: _cantidad < widget.maxCantidad
                          ? () => setState(() => _cantidad++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              CampoTexto(
                controller: _motivo,
                autofocus: true,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Motivo (obligatorio)',
                  hintText: 'Ej. el cliente se arrepintió, plato mal preparado',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _elegirFoto,
                icon: const Icon(LucideIcons.camera, size: 16),
                label: Text(
                  _nombreFoto == null
                      ? 'Adjuntar foto (opcional)'
                      : 'Foto: $_nombreFoto',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _confirmar,
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text(
                  'Anular',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
