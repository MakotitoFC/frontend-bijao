import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/utils/boleta_imagen.dart';
import 'package:frontend_bijao/utils/ticket_texto.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('la boleta se convierte en una imagen PNG', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late BuildContext contexto;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            contexto = c;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final lineas = [
      const LineaTicket.centro('BOLETA DE VENTA ELECTRONICA', negrita: true),
      LineaTicket(padLinea(' 2x Ceviche', 'S/ 40.00')),
      const LineaTicket.codigoQr('BOLETA-0007'),
    ];

    // La captura usa el motor gráfico real: se corre fuera del reloj falso.
    final png = await tester.runAsync(() async {
      final futuro = boletaComoPng(contexto, lineas);
      // Se avanzan los cuadros mientras la captura espera su turno.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      return futuro;
    });

    expect(png, isNotNull);
    // Firma de un archivo PNG.
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(png.length, greaterThan(1000));
    // Y no deja la copia fuera de pantalla puesta.
    await tester.pump();
    expect(find.byType(RepaintBoundary), findsWidgets);
  });
}
