import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class DiscoveredServer {
  final String ip;
  final int port;
  final String method; // 'mdns', 'udp', 'cache', 'lan', 'subnet_scan', 'manual'

  const DiscoveredServer({
    required this.ip,
    required this.port,
    required this.method,
  });

  String get baseUrl => 'http://$ip:$port';
}

/// Servicio de descubrimiento automático de la laptop del cajero (servidor Go)
/// mediante mDNS (Bonjour), UDP Beacon, Subnet Sweep y verificación de salud HTTP.
class NetworkDiscoveryService {
  static const String _prefKeyServerUrl = 'server_api_url';
  static int get defaultPort => AppConfig.serverPort;
  static const int udpBeaconPort = 8989;

  /// Obtiene la URL base del servidor guardada en memoria persistente
  static Future<String?> getSavedServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyServerUrl);
  }

  /// Guarda la URL base confirmada del servidor
  static Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyServerUrl, url.trim().replaceAll(RegExp(r'/+$'), ''));
  }

  /// Verifica si una IP/URL específica responde con éxito al healthcheck
  static Future<bool> pingServer(String baseUrl, {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final cleanUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$cleanUrl/api/health');
      final resp = await http.get(uri).timeout(timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['status'] == 'ok' && data['app'] == 'bijao-pos';
      }
    } catch (_) {}
    return false;
  }

  /// Descubre el servidor en la red local probando:
  /// 1. URL guardada en SharedPreferences (rápido)
  /// 2. IP configurada por defecto (.env / AppConfig)
  /// 3. Localhost (si corre en la misma laptop en Desktop/Web)
  /// 4. Beacon / Broadcast UDP (puerto 8989)
  /// 5. mDNS / Bonjour (_bijao-server._tcp.local / joel.local)
  /// 6. Barrido rápido de la subred local (para Android cuando mDNS/UDP están bloqueados por el router)
  static Future<DiscoveredServer?> discoverServer({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    // 1. En Web (PWA / Safari / Chrome): verificar el origin del navegador
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null') {
        if (await pingServer(origin, timeout: const Duration(seconds: 2))) {
          final uri = Uri.parse(origin);
          final server = DiscoveredServer(ip: uri.host, port: uri.port, method: 'origen web');
          await saveServerUrl(server.baseUrl);
          return server;
        }
      }
    }

    // 2. Probar URL previamente guardada
    final savedUrl = await getSavedServerUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      if (await pingServer(savedUrl, timeout: const Duration(seconds: 2))) {
        final uri = Uri.parse(savedUrl);
        return DiscoveredServer(ip: uri.host, port: uri.port, method: 'cache');
      }
    }

    // 3. Probar IP preconfigurada en AppConfig (.env)
    final configuredUrl = AppConfig.defaultBaseUrl;
    if (await pingServer(configuredUrl, timeout: const Duration(seconds: 2))) {
      final server = DiscoveredServer(ip: AppConfig.serverIp, port: AppConfig.serverPort, method: 'config');
      await saveServerUrl(server.baseUrl);
      return server;
    }

    // 4. Si no es Web y estamos en la misma máquina local, probar localhost
    if (!kIsWeb) {
      if (await pingServer('http://127.0.0.1:$defaultPort', timeout: const Duration(milliseconds: 600))) {
        final server = DiscoveredServer(ip: '127.0.0.1', port: defaultPort, method: 'localhost');
        await saveServerUrl(server.baseUrl);
        return server;
      }
    }

    // 5. Probar UDP Broadcast (rápido y robusto en Wi-Fi)
    if (!kIsWeb) {
      final udpServer = await _discoverViaUDP(timeout: const Duration(seconds: 2));
      if (udpServer != null) {
        if (await pingServer(udpServer.baseUrl)) {
          await saveServerUrl(udpServer.baseUrl);
          return udpServer;
        }
      }
    }

    // 6. Probar mDNS / Bonjour
    if (!kIsWeb) {
      final mdnsServer = await _discoverViaMDNS(timeout: timeout);
      if (mdnsServer != null) {
        if (await pingServer(mdnsServer.baseUrl)) {
          await saveServerUrl(mdnsServer.baseUrl);
          return mdnsServer;
        }
      }
    }

    // 7. Probar hosts conocidos en la red Wi-Fi
    for (final host in [AppConfig.serverIp, 'joel.local']) {
      final cand = 'http://$host:$defaultPort';
      if (await pingServer(cand, timeout: const Duration(milliseconds: 1200))) {
        final uri = Uri.parse(cand);
        final server = DiscoveredServer(ip: uri.host, port: uri.port, method: 'lan');
        await saveServerUrl(server.baseUrl);
        return server;
      }
    }

    // 8. Escaneo rápido de la subred local (fallback definitivo para Android)
    if (!kIsWeb) {
      final scannedServer = await _scanSubnetForServer();
      if (scannedServer != null) {
        await saveServerUrl(scannedServer.baseUrl);
        return scannedServer;
      }
    }

    return null;
  }

  /// Escanea en paralelo las IPs más probables de la subred local
  static Future<DiscoveredServer?> _scanSubnetForServer() async {
    try {
      final baseIpParts = AppConfig.serverIp.split('.');
      if (baseIpParts.length != 4) return null;
      final subnetPrefix = '${baseIpParts[0]}.${baseIpParts[1]}.${baseIpParts[2]}';

      // Probar un grupo de IPs comunes en LAN (1 al 100)
      final candidates = <String>[];
      for (int i = 1; i <= 80; i++) {
        candidates.add('$subnetPrefix.$i');
      }

      final completer = Completer<DiscoveredServer?>();

      Future.wait(
        candidates.map((ip) async {
          if (completer.isCompleted) return;
          final candUrl = 'http://$ip:$defaultPort';
          final ok = await pingServer(candUrl, timeout: const Duration(milliseconds: 1500));
          if (ok && !completer.isCompleted) {
            completer.complete(DiscoveredServer(ip: ip, port: defaultPort, method: 'subnet_scan'));
          }
        }),
      ).then((_) {
        if (!completer.isCompleted) completer.complete(null);
      });

      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  /// Escucha el beacon UDP o envía consulta "BIJAO_DISCOVER"
  static Future<DiscoveredServer?> _discoverViaUDP({required Duration timeout}) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final completer = Completer<DiscoveredServer?>();

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            try {
              final text = utf8.decode(datagram.data);
              final json = jsonDecode(text);
              if (json['app'] == 'bijao-pos' && json['server_ip'] != null) {
                final ip = json['server_ip'].toString();
                final port = (json['port'] as num?)?.toInt() ?? defaultPort;
                if (!completer.isCompleted) {
                  completer.complete(DiscoveredServer(ip: ip, port: port, method: 'udp'));
                }
              }
            } catch (_) {}
          }
        }
      });

      // Enviar solicitud de descubrimiento por broadcast
      final query = utf8.encode('BIJAO_DISCOVER');
      socket.send(query, InternetAddress('255.255.255.255'), udpBeaconPort);

      // Temporizador de timeout
      Future.delayed(timeout, () {
        if (!completer.isCompleted) completer.complete(null);
      });

      final result = await completer.future;
      socket.close();
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Busca el servicio mDNS "_bijao-server._tcp.local"
  static Future<DiscoveredServer?> _discoverViaMDNS({required Duration timeout}) async {
    try {
      final client = MDnsClient();
      await client.start();

      DiscoveredServer? found;
      final ptrResource = '_bijao-server._tcp.local';

      await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(ptrResource),
      ).timeout(timeout, onTimeout: (sink) => sink.close())) {
        await for (final SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          await for (final IPAddressResourceRecord ipRecord in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            found = DiscoveredServer(
              ip: ipRecord.address.address,
              port: srv.port,
              method: 'mdns',
            );
            break;
          }
          if (found != null) break;
        }
        if (found != null) break;
      }

      client.stop();
      return found;
    } catch (_) {
      return null;
    }
  }
}
