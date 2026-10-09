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
    defaultValue: '192.168.0.50',
  );

  static const int serverPort = int.fromEnvironment(
    'SERVER_PORT',
    defaultValue: 6050,
  );

  static String get defaultBaseUrl => 'http://$serverIp:$serverPort';
}
