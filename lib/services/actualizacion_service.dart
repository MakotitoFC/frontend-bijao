import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api_client.dart';

// Última versión del APK que informa el servidor.
class VersionApp {
  final int codigo;
  final String nombre;
  // Ruta (o URL completa) desde donde se descarga el APK.
  final String url;
  // Si es true, el aviso no se puede posponer.
  final bool obligatoria;
  final String notas;

  const VersionApp({
    required this.codigo,
    required this.nombre,
    required this.url,
    this.obligatoria = false,
    this.notas = '',
  });

  // Acepta {"android": {...}} o los campos sueltos; null si faltan datos.
  static VersionApp? desdeJson(dynamic json) {
    if (json is! Map) return null;
    final m = json['android'] is Map ? json['android'] as Map : json;
    final codigo = int.tryParse('${m['version_code'] ?? ''}');
    final url = m['url']?.toString() ?? '';
    if (codigo == null || url.isEmpty) return null;
    return VersionApp(
      codigo: codigo,
      nombre: m['version_name']?.toString() ?? '',
      url: url,
      obligatoria: m['obligatoria'] == true,
      notas: m['notas']?.toString() ?? '',
    );
  }
}

// Avisa de un APK nuevo: compara el número de compilación instalado (lo que va
// después del "+" en pubspec.yaml) con el que informa el servidor.
class ActualizacionService {
  ActualizacionService._();
  static final instance = ActualizacionService._();

  // Solo se avisa una vez por sesión.
  bool _avisado = false;

  // Solo el APK de Android se actualiza así: la web se recarga sola y iOS no
  // usa APK.
  static bool get aplica =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool hayVersionNueva(int instalada, VersionApp? remota) =>
      remota != null && remota.codigo > instalada;

  // La versión nueva, o null si no hay, no aplica o no se pudo consultar (sin
  // servidor o sin el endpoint no se molesta al usuario).
  Future<VersionApp?> buscar({
    Future<int> Function()? instalada,
    Future<dynamic> Function()? consultar,
  }) async {
    if (_avisado) return null;
    if (instalada == null && !aplica) return null;
    try {
      final actual = await (instalada ?? _codigoInstalado)();
      final json =
          await (consultar ??
              () => ApiClient.instance.get(
                '/api/v1/app/version',
                timeout: const Duration(seconds: 6),
              ))();
      final remota = VersionApp.desdeJson(json);
      return hayVersionNueva(actual, remota) ? remota : null;
    } catch (_) {
      return null;
    }
  }

  void marcarAvisado() => _avisado = true;

  Future<int> _codigoInstalado() async =>
      int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

  // Dirección completa de descarga del APK.
  static Uri urlDescarga(VersionApp v) {
    final u = Uri.parse(v.url);
    if (u.hasScheme) return u;
    final base = ApiClient.instance.baseUrl;
    return Uri.parse('$base${v.url.startsWith('/') ? '' : '/'}${v.url}');
  }
}
