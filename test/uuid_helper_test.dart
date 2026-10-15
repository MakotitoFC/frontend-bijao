import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/utils/uuid_helper.dart';

void main() {
  test('acepta ids de ejemplo de la base y UUID v7', () {
    expect(UuidHelper.isValid('33333333-3333-3333-3333-333333333303'), true);
    expect(UuidHelper.isValid('33331111-1111-1111-1111-111111111103'), true);
    expect(UuidHelper.isValid(UuidHelper.v7()), true);
  });

  test('rechaza lo que no es UUID', () {
    expect(UuidHelper.isValid(''), false);
    expect(UuidHelper.isValid('taper-fila'), false);
    expect(UuidHelper.isValid('1234'), false);
  });
}
