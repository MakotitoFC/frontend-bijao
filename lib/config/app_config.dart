/// Configuración global de conexión al backend
///
/// Permite inyectar variables en tiempo de compilación mediante:
/// `flutter build apk --dart-define-from-file=.env`
/// o variables individuales:
/// `flutter run --dart-define=SERVER_IP=192.168.0.50`
///
/// Si no se definen parámetros al compilar, toma por defecto los valores establecidos aquí.
class AppConfig {
  static const String serverIp = String.fromEnvironment(
    'SERVER_IP',
    defaultValue: '192.168.0.169',
  );

  static const int serverPort = int.fromEnvironment(
    'SERVER_PORT',
    defaultValue: 6050,
  );

  // Pedidos por `/api/v1/mozo/pedidos` (precios calculados por el backend,
  // táper en fila aparte, versiones y operaciones del mozo). Para volver al
  // servicio anterior: `--dart-define=USAR_API_MOZO=false`.
  static const bool usarApiPedidosMozo = bool.fromEnvironment(
    'USAR_API_MOZO',
    defaultValue: true,
  );

  static String get defaultBaseUrl => 'http://$serverIp:$serverPort';
}
