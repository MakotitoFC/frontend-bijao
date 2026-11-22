import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'network_discovery_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  ApiException({required this.statusCode, required this.message, this.details});

  @override
  String toString() => message;
}

enum _RefreshResult { ok, rejected, networkError }

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String _prefToken = 'auth_jwt_token';
  static const String _prefRefreshToken = 'auth_refresh_token';
  final http.Client _http = http.Client();
  String? _jwtToken;
  String? _refreshToken;
  late String _baseUrl = _getDefaultBaseUrl();
  Completer<_RefreshResult>? _refreshCompleter;

  void Function(String message)? onSessionExpired;

  static String _getDefaultBaseUrl() {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null') {
        return origin;
      }
    }
    return AppConfig.defaultBaseUrl;
  }

  String get baseUrl => _baseUrl;
  bool get hasToken => _jwtToken != null && _jwtToken!.isNotEmpty;
  String? get accessToken => _jwtToken;
  String? get refreshToken => _refreshToken;

  /// Inicializa la URL del servidor y recupera tokens guardados
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString(_prefToken);
    _refreshToken = prefs.getString(_prefRefreshToken);

    // 1. En Web (PWA en iPhone / Navegador): la app se sirve desde el mismo servidor
    // Siempre tomamos el origin del navegador como base automática
    if (kIsWeb) {
      final currentOrigin = Uri.base.origin;
      if (currentOrigin.isNotEmpty && currentOrigin != 'null') {
        _baseUrl = currentOrigin;
        await NetworkDiscoveryService.saveServerUrl(_baseUrl);
        return;
      }
    }

    // 2. En dispositivos nativos (Android APK / Windows Desktop):
    final savedUrl = await NetworkDiscoveryService.getSavedServerUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    } else {
      // Intentar auto-descubrimiento en red local (mDNS / UDP)
      final discovered = await NetworkDiscoveryService.discoverServer(
        timeout: const Duration(seconds: 2),
      );
      if (discovered != null) {
        _baseUrl = discovered.baseUrl;
      } else {
        _baseUrl = _getDefaultBaseUrl();
      }
    }
  }

  void setBaseUrl(String url) {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    NetworkDiscoveryService.saveServerUrl(_baseUrl);
  }

  Future<void> setToken(String? token, [String? refreshToken]) async {
    _jwtToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(_prefToken, token);
    } else {
      await prefs.remove(_prefToken);
    }

    if (refreshToken != null) {
      _refreshToken = refreshToken;
      await prefs.setString(_prefRefreshToken, refreshToken);
    } else if (token == null) {
      _refreshToken = null;
      await prefs.remove(_prefRefreshToken);
    }
  }

  String? getToken() => _jwtToken;

  Map<String, String> _headers({Map<String, String>? extra}) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (_jwtToken != null && _jwtToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_jwtToken';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$_baseUrl$cleanPath';
    return Uri.parse(fullUrl).replace(queryParameters: queryParams);
  }

  Future<_RefreshResult> _tryRefreshToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return _RefreshResult.rejected;
    }
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    final completer = Completer<_RefreshResult>();
    _refreshCompleter = completer;
    var resultado = _RefreshResult.networkError;
    try {
      final uri = _buildUri('/api/auth/refresh');
      final resp = await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': _refreshToken}),
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map<String, dynamic> &&
            decoded['access_token'] != null) {
          final newAccess = decoded['access_token'].toString();
          final newRefresh =
              decoded['refresh_token']?.toString() ?? _refreshToken;
          await setToken(newAccess, newRefresh);
          resultado = _RefreshResult.ok;
        } else {
          resultado = _RefreshResult.rejected;
        }
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        resultado = _RefreshResult.rejected;
      } else {
        resultado = _RefreshResult.networkError;
      }
    } catch (e) {
      debugPrint('[ApiClient] Error refrescando token (red/timeout): $e');
      resultado = _RefreshResult.networkError;
    } finally {
      _refreshCompleter = null;
      if (!completer.isCompleted) {
        completer.complete(resultado);
      }
    }
    return resultado;
  }

  Future<dynamic> _processResponse(
    http.Response response, {
    String? path,
    Future<dynamic> Function()? retryCall,
  }) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String message = 'Error en el servidor (${response.statusCode})';
    if (decoded is Map && decoded['error'] != null) {
      message = decoded['error'].toString();
    } else if (decoded is String && decoded.isNotEmpty) {
      message = decoded;
    }

    // Interceptar 401 si no es llamada de login, refresh ni PIN de supervisor
    // (un PIN incorrecto responde 401 y no debe cerrar la sesión).
    if (response.statusCode == 401 &&
        path != '/api/auth/login' &&
        path != '/api/auth/refresh' &&
        path != '/api/auth/validar-pin-supervisor') {
      final refresh = retryCall != null
          ? await _tryRefreshToken()
          : _RefreshResult.rejected;
      if (refresh == _RefreshResult.ok) {
        return retryCall!();
      }
      if (refresh == _RefreshResult.networkError) {
        throw ApiException(
          statusCode: 0,
          message:
              'Sin conexión estable con el servidor al renovar sesión. Intenta de nuevo.',
          details: decoded,
        );
      }
      await setToken(null);
      onSessionExpired?.call(message);
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      details: decoded,
    );
  }

  // Descarga un archivo (por ejemplo una imagen) con la sesión iniciada.
  // Devuelve null si no hay archivo o la sesión no sirve.
  Future<Uint8List?> descargarBytes(
    String path, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (!hasToken) return null;
    try {
      final resp = await _http
          .get(_buildUri(path, null), headers: _headers())
          .timeout(timeout);
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
      return resp.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final resp = await _http.get(uri, headers: _headers()).timeout(timeout);
      return await _processResponse(
        resp,
        path: path,
        retryCall: () => get(path, queryParams: queryParams, timeout: timeout),
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'No se pudo conectar al servidor ($baseUrl): $e',
      );
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic body,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    try {
      final uri = _buildUri(path);
      final resp = await _http
          .post(
            uri,
            headers: _headers(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      return await _processResponse(
        resp,
        path: path,
        retryCall: () => post(path, body: body, timeout: timeout),
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'No se pudo conectar al servidor ($baseUrl): $e',
      );
    }
  }

  Future<dynamic> put(
    String path, {
    dynamic body,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    try {
      final uri = _buildUri(path);
      final resp = await _http
          .put(
            uri,
            headers: _headers(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      return await _processResponse(
        resp,
        path: path,
        retryCall: () => put(path, body: body, timeout: timeout),
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'No se pudo conectar al servidor ($baseUrl): $e',
      );
    }
  }

  Future<dynamic> patch(
    String path, {
    dynamic body,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    try {
      final uri = _buildUri(path);
      final resp = await _http
          .patch(
            uri,
            headers: _headers(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      return await _processResponse(
        resp,
        path: path,
        retryCall: () => patch(path, body: body, timeout: timeout),
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'No se pudo conectar al servidor ($baseUrl): $e',
      );
    }
  }

  // Sube un archivo (multipart) en el campo [campo].
  Future<dynamic> subirArchivo(
    String path, {
    required List<int> bytes,
    required String nombreArchivo,
    String campo = 'file',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final peticion = http.MultipartRequest('POST', _buildUri(path));
      peticion.headers.addAll(_headers()..remove('Content-Type'));
      peticion.files.add(
        http.MultipartFile.fromBytes(campo, bytes, filename: nombreArchivo),
      );
      final respuesta = await http.Response.fromStream(
        await _http.send(peticion).timeout(timeout),
      );
      return await _processResponse(respuesta, path: path);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'No se pudo subir el archivo ($baseUrl): $e',
      );
    }
  }

  Future<dynamic> delete(
    String path, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    try {
      final uri = _buildUri(path);
      final resp = await _http
          .delete(uri, headers: _headers())
          .timeout(timeout);
      return await _processResponse(
        resp,
        path: path,
        retryCall: () => delete(path, timeout: timeout),
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'No se pudo conectar al servidor ($baseUrl): $e',
      );
    }
  }

  /// Envía silenciosamente errores no capturados del cliente al servidor para trazabilidad en logs
  static Future<void> registrarErrorRemoto({
    required String mensaje,
    String? stack,
    String nivel = 'ERROR',
    String? ruta,
    String? usuario,
  }) async {
    try {
      final base = ApiClient.instance.baseUrl;
      final uri = Uri.parse('$base/api/v1/telemetria/frontend-log');
      final payload = jsonEncode({
        'nivel': nivel,
        'mensaje': mensaje,
        'stack': stack ?? '',
        'ruta': ruta ?? (kIsWeb ? Uri.base.toString() : ''),
        'usuario': usuario ?? 'desconocido',
        'user_agent': kIsWeb ? 'Flutter Web' : defaultTargetPlatform.name,
      });
      await ApiClient.instance._http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Ignorar errores de conexión al reportar telemetría para evitar bucles
    }
  }
}
