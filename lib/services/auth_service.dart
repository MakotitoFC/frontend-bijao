import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario.dart';
import 'api_client.dart';

/// Servicio de Autenticación contra el backend de Go.
/// Gestiona login, sesión activa, almacenamiento de credenciales y permisos RBAC.
class AuthService {
  AuthService._() {
    ApiClient.instance.onSessionExpired = (message) {
      logout();
    };
  }
  static final AuthService instance = AuthService._();

  static const String _prefUserSession = 'auth_user_session';
  static const String _prefSavedEmail = 'auth_saved_email';

  final ValueNotifier<Usuario?> userNotifier = ValueNotifier<Usuario?>(null);

  Usuario? get currentUser => userNotifier.value;
  Usuario? get usuarioActual => userNotifier.value;
  bool get isAuthenticated => userNotifier.value != null && ApiClient.instance.hasToken;

  /// Restaura la sesión persistida al iniciar la app y valida contra el backend
  Future<Usuario?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefUserSession);
    if (jsonStr != null && ApiClient.instance.hasToken) {
      try {
        final map = jsonDecode(jsonStr);
        final user = Usuario.fromJson(map);

        // Validar token y verificar si el usuario sigue activo en la base de datos
        final me = await ApiClient.instance.get('/api/auth/me');
        if (me is Map<String, dynamic>) {
          userNotifier.value = user;
          return user;
        }
      } catch (e) {
        debugPrint('[AUTH] Sesión no válida o usuario inactivo: $e');
        await logout();
      }
    }
    userNotifier.value = null;
    return null;
  }

  /// Inicia sesión con usuario/email y password contra `POST /api/auth/login`
  Future<Usuario> login({
    required String usuario,
    required String password,
    bool rememberEmail = false,
  }) async {
    final body = {
      'usuario': usuario.trim(),
      'password': password,
    };

    final res = await ApiClient.instance.post('/api/auth/login', body: body);

    if (res is! Map<String, dynamic>) {
      throw ApiException(statusCode: 500, message: 'Respuesta inválida del servidor');
    }

    final token = res['access_token']?.toString();
    final refreshToken = res['refresh_token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException(statusCode: 500, message: 'El servidor no devolvió un token de acceso');
    }

    // 1. Guardar tokens JWT en ApiClient y SharedPreferences
    await ApiClient.instance.setToken(token, refreshToken);

    // 2. Parsear usuario y permisos
    final user = Usuario.fromJson(res);
    userNotifier.value = user;

    // 3. Persistir sesión de usuario
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUserSession, jsonEncode(user.toJson()));

    if (rememberEmail) {
      await prefs.setString(_prefSavedEmail, usuario.trim());
    } else {
      await prefs.remove(_prefSavedEmail);
    }

    return user;
  }

  /// Cierra la sesión activa
  Future<void> logout() async {
    userNotifier.value = null;
    await ApiClient.instance.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefUserSession);
  }

  /// Obtiene el correo/usuario recordado
  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefSavedEmail);
  }
}
