import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/api_client.dart';
import '../services/network_discovery_service.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';

/// Diálogo interactivo para ver y cambiar la IP del servidor de la laptop
/// con soporte para auto-descubrimiento en Wi-Fi (mDNS / UDP).
class ServerConnectionDialog extends StatefulWidget {
  const ServerConnectionDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ServerConnectionDialog(),
    );
  }

  @override
  State<ServerConnectionDialog> createState() => _ServerConnectionDialogState();
}

class _ServerConnectionDialogState extends State<ServerConnectionDialog> {
  late final TextEditingController _urlController;
  bool _isSearching = false;
  bool _isTesting = false;
  bool? _testSuccess;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiClient.instance.baseUrl);
    _checkCurrentStatus();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentStatus() async {
    setState(() => _isTesting = true);
    final ok = await NetworkDiscoveryService.pingServer(_urlController.text);
    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testSuccess = ok;
      _statusMessage = ok ? 'Conectado al servidor Bijao POS' : 'No se pudo conectar';
    });
  }

  Future<void> _runAutoDiscovery() async {
    setState(() {
      _isSearching = true;
      _statusMessage = 'Buscando laptop en la red WiFi (mDNS / UDP)...';
    });

    final discovered = await NetworkDiscoveryService.discoverServer(
      timeout: const Duration(seconds: 4),
    );

    if (!mounted) return;

    if (discovered != null) {
      _urlController.text = discovered.baseUrl;
      ApiClient.instance.setBaseUrl(discovered.baseUrl);
      setState(() {
        _isSearching = false;
        _testSuccess = true;
        _statusMessage = 'Servidor detectado vía ${discovered.method.toUpperCase()} (${discovered.ip})';
      });
      showAppToast(context, 'Servidor conectado: ${discovered.baseUrl}', type: ToastType.success);
    } else {
      setState(() {
        _isSearching = false;
        _statusMessage = 'No se encontró servidor automáticamente. Ingresa la IP manualmente.';
      });
      showAppToast(context, 'No se encontró servidor en la red WiFi', type: ToastType.warning);
    }
  }

  Future<void> _saveAndTest() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isTesting = true);
    final ok = await NetworkDiscoveryService.pingServer(url);
    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _testSuccess = ok;
      _statusMessage = ok ? 'Conexión exitosa' : 'Error al conectar a esa dirección';
    });

    if (ok) {
      ApiClient.instance.setBaseUrl(url);
      showAppToast(context, 'Dirección guardada correctamente', type: ToastType.success);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(LucideIcons.wifi, color: AppColors.primaryGreen, size: 22),
          const SizedBox(width: 10),
          const Text('Conexión con el Servidor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'La laptop del cajero actúa como servidor local. Los mozos se conectan vía Wi-Fi a esta dirección:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL del Backend',
                hintText: 'http://192.168.1.50:6050',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(LucideIcons.server, size: 18),
                suffixIcon: IconButton(
                  tooltip: 'Probar conexión',
                  icon: _isTesting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _testSuccess == true
                              ? LucideIcons.checkCircle
                              : _testSuccess == false
                                  ? LucideIcons.xCircle
                                  : LucideIcons.refreshCw,
                          color: _testSuccess == true
                              ? Colors.green
                              : _testSuccess == false
                                  ? Colors.red
                                  : Colors.grey,
                          size: 18,
                        ),
                  onPressed: _checkCurrentStatus,
                ),
              ),
            ),
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: _testSuccess == true ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              onPressed: _isSearching ? null : _runAutoDiscovery,
              icon: _isSearching
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.scan, size: 16),
              label: Text(_isSearching ? 'Buscando en Wi-Fi...' : 'Auto-detectar Servidor (mDNS / Bonjour)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        ElevatedButton(
          onPressed: _isTesting ? null : _saveAndTest,
          child: const Text('Guardar y Conectar'),
        ),
      ],
    );
  }
}
