import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/utils/desglose_cobro.dart';

// En el resumen de Pagar las filas deben sumar el total: la cuenta, el recargo
// y las roturas. Caso real: cuenta de S/ 51.00, rotura de S/ 6.00 y recargo de
// tarjeta de S/ 2.04 → total S/ 59.04 (no 65.04).
void main() {
  test('por montos: las roturas no se cuentan dos veces', () {
    // Filas: tarjeta 51.00 + efectivo 80.00 = 131.00. La cuenta con la rotura
    // es 57.00, así que sobran 74.00 (vuelto).
    final d = desgloseCuentaYRoturas(
      porMontos: true,
      asignado: 131,
      sobraAplicable: 74,
      saldo: 51,
      cargos: 6,
    );
    expect(d.cuenta, 51);
    expect(d.roturas, 6);
    const recargo = 2.04;
    // Las filas del resumen suman el total que se cobra.
    expect(d.cuenta + recargo + d.roturas, closeTo(59.04, 0.001));
    expect(d.cuenta + d.roturas, 57);
  });

  test('un solo medio: la cuenta es el saldo y las roturas van aparte', () {
    final d = desgloseCuentaYRoturas(
      porMontos: false,
      asignado: 0,
      sobraAplicable: 0,
      saldo: 51,
      cargos: 6,
    );
    expect(d.cuenta, 51);
    expect(d.roturas, 6);
  });

  test('sin roturas no cambia nada', () {
    final d = desgloseCuentaYRoturas(
      porMontos: true,
      asignado: 60,
      sobraAplicable: 9,
      saldo: 51,
      cargos: 0,
    );
    expect(d.cuenta, 51);
    expect(d.roturas, 0);
  });

  test('un abono menor que la rotura no deja una cuenta negativa', () {
    final d = desgloseCuentaYRoturas(
      porMontos: true,
      asignado: 4,
      sobraAplicable: 0,
      saldo: 51,
      cargos: 6,
    );
    expect(d.roturas, 4);
    expect(d.cuenta, 0);
    expect(d.cuenta + d.roturas, 4);
  });

  test('sin nada cubierto, todo en cero', () {
    final d = desgloseCuentaYRoturas(
      porMontos: true,
      asignado: 0,
      sobraAplicable: 0,
      saldo: 51,
      cargos: 6,
    );
    expect(d.cuenta, 0);
    expect(d.roturas, 0);
  });
}
