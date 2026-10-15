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

  /// Valida si un string tiene formato de UUID (8-4-4-4-12 hexadecimal).
  ///
  /// No exige versión ni variante RFC: los datos de ejemplo de la base usan ids
  /// como `33333333-3333-3333-3333-333333333303`, que un chequeo estricto
  /// rechaza y hacía que la app los tratara como "sin id".
  static bool isValid(String id) => Uuid.isValidUUID(
    fromString: id,
    validationMode: ValidationMode.nonStrict,
  );
}
