import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generador de identificadores únicos basados en tiempo (UUID v7 - RFC 9562).
///
/// Permite ordenamiento cronológico nativo, inserciones B-Tree eficientes en
/// PostgreSQL y generación offline en dispositivos móviles sin colisiones.
class UuidHelper {
  UuidHelper._();

  /// Genera un nuevo UUID v7 ordenado por tiempo (timestamp actual en ms).
  static String v7() => _uuid.v7();

  /// Valida si un string tiene formato válido de UUID.
  static bool isValid(String id) => Uuid.isValidUUID(fromString: id);
}
