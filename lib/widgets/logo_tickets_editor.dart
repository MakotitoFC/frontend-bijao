import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/logo_ticket_store.dart';
import '../services/api_client.dart';
import '../services/impresion_service.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';

// El mismo logo de la barra superior; es el que se usa si no se sube otro.
const _logoDeLaApp = 'assets/images/logo_bijao.png';

// Cambiar el logo que sale en los tickets de caja (.png, .jpg, .jpeg o .bmp).
// El servidor lo guarda y lo convierte para la ticketera. Se usa en
// Configuración › Negocio y en Configuración › Impresoras.
class LogoTicketsEditor extends StatefulWidget {
  const LogoTicketsEditor({super.key});

  @override
  State<LogoTicketsEditor> createState() => _LogoTicketsEditorState();
}

class _LogoTicketsEditorState extends State<LogoTicketsEditor> {
  Uint8List? _elegido;
  String? _nombre;
  String _rutaActual = '';
  bool _subiendo = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  // Si el servidor aún no tiene logo, sube el de la barra superior de la app
  // para que los tickets salgan con el logo actual sin hacer nada.
  Future<void> _iniciar() async {
    await cargarLogoTicketLocal();
    try {
      final c = await ImpresionService.instance.obtenerConfig();
      if (!mounted) return;
      setState(() => _rutaActual = c.logoPath);
      if (c.logoPath.isEmpty) await _subirLogoDeLaApp();
    } catch (_) {}
  }

  Future<void> _subirLogoDeLaApp() async {
    final datos = await rootBundle.load(_logoDeLaApp);
    final bytes = datos.buffer.asUint8List();
    final ruta = await ImpresionService.instance.subirLogo(
      bytes,
      'logo_bijao.png',
    );
    if (logoTicketLocal.value == null) await guardarLogoTicketLocal(bytes);
    if (mounted && ruta.isNotEmpty) setState(() => _rutaActual = ruta);
  }

  String _mensaje(Object e) => e is ApiException
      ? e.message
      : e.toString().replaceFirst('Exception: ', '');

  Future<void> _elegir() async {
    try {
      final r = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp'],
      );
      if (r.isEmpty) return;
      final f = r.first;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        _elegido = Uint8List.fromList(bytes);
        _nombre = f.name;
      });
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'No se pudo leer el archivo: ${_mensaje(e)}',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _subir() async {
    final bytes = _elegido;
    if (bytes == null) return;
    setState(() => _subiendo = true);
    try {
      final ruta = await ImpresionService.instance.subirLogo(
        bytes,
        _nombre ?? 'logo.png',
      );
      await guardarLogoTicketLocal(bytes);
      if (!mounted) return;
      setState(() {
        _rutaActual = ruta.isEmpty ? _rutaActual : ruta;
        _elegido = null;
        _nombre = null;
      });
      showAppToast(
        context,
        'Logo actualizado. Saldrá en los tickets de caja.',
        type: ToastType.success,
      );
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'No se pudo subir el logo: ${_mensaje(e)}',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final elegido = _elegido;
    return ValueListenableBuilder<Uint8List?>(
      valueListenable: logoTicketLocal,
      builder: (context, local, _) {
        final vista = elegido ?? local;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 96,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: vista != null
                    ? Image.memory(vista, fit: BoxFit.contain)
                    : Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          _logoDeLaApp,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Icon(
                            LucideIcons.image,
                            size: 24,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Logo de los tickets de caja',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      elegido != null
                          ? '${_nombre ?? 'imagen'} · sin subir aún'
                          : (_rutaActual.isEmpty
                                ? 'Logo de la app (barra superior). PNG, JPG o BMP.'
                                : 'En el servidor: $_rutaActual'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (elegido != null) ...[
                TextButton(
                  onPressed: _subiendo
                      ? null
                      : () => setState(() {
                          _elegido = null;
                          _nombre = null;
                        }),
                  child: const Text('Descartar'),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: _subiendo ? null : _subir,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                  child: const Text('Subir logo'),
                ),
              ] else
                OutlinedButton(
                  onPressed: _subiendo ? null : _elegir,
                  child: Text(
                    _rutaActual.isEmpty ? 'Elegir imagen' : 'Cambiar',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
