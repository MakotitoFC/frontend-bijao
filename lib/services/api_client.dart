import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'network_discovery_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String _prefToken = 'auth_jwt_token';
  static const String _prefRefreshToken = 'auth_refresh_token';
  String? _jwtToken;
  String? _refreshToken;
  late String _baseUrl = _getDefaultBaseUrl();
  bool _isRefreshing = false;

  void Function(String message)? onSessionExpired;

  static String _getDefaultBaseUrl() {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null') {
        return origin;
      }
    }
    return 'http://192.168.0.243:6050';
  }

  String get baseUrl => _baseUrl;
  bool get hasToken => _jwtToken != null && _jwtToken!.isNotEmpty;
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

  Future<bool> _tryRefreshToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty || _isRefreshing) {
      return false;
    }
    _isRefreshing = true;
    try {
      final uri = _buildUri('/api/auth/refresh');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['access_token'] != null) {
          final newAccess = decoded['access_token'].toString();
          final newRefresh = decoded['refresh_token']?.toString() ?? _refreshToken;
          await setToken(newAccess, newRefresh);
          _isRefreshing = false;
          return true;
        }
      }
    } catch (e) {
      debugPrint('[ApiClient] Error refrescando token: $e');
    }
    _isRefreshing = false;
    return false;
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

    // Interceptar 401 si no es llamada de login ni refresh
    if (response.statusCode == 401 && path != '/api/auth/login' && path != '/api/auth/refresh') {
      if (retryCall != null && await _tryRefreshToken()) {
        return retryCall();
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

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final resp = await http.get(uri, headers: _headers()).timeout(timeout);
      return await _processResponse(
        resp,
        path: path,
        retryCall: () => get(path, queryParams: queryParams, timeout: timeout),
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'No se pudo conectar al servidor ($baseUrl): $e');
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final uri = _buildUri(path);
      final resp = await http.post(
        uri,
        headers: _headers(),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(timeout);
      return await _processResponse(
        resp,
        path: path,
        retryCall: () => post(path, body: body, timeout: timeout),
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'No se pudo conectar al servidor ($baseUrl): $e');
    }
  }

  Future<dynamic> put(
    String path, {
    dynamic body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final uri = _buildUri(path);
      final resp = await http.put(
        uri,
        headers: _headers(),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(timeout);
      return await _processResponse(
        resp,
        path: path,
        retryCall: () => put(path, body: body, timeout: timeout),
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'No se pudo conectar al servidor ($baseUrl): $e');
    }
  }

  Future<dynamic> delete(
    String path, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final uri = _buildUri(path);
      final resp = await http.delete(uri, headers: _headers()).timeout(timeout);
      return await _processResponse(
        resp,
        path: path,
        retryCall: () => delete(path, timeout: timeout),
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'No se pudo conectar al servidor ($baseUrl): $e');
    }
  }
}
