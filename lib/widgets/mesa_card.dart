import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_theme.dart';

enum _LadoSilla { izquierda, derecha, arriba, abajo }

// Tarjeta de mesa dibujada solo con divs (Container + BorderRadius), sin
// SVG: el cuerpo es un rectángulo con radio 30, las sillas son rectángulos
// con un lado totalmente redondeado (semicírculo, hacia afuera) y el lado
// opuesto (pegado a la mesa) con esquinas de 15px. La cantidad de sillas
// (2 o 4) no viene de la base de datos (no hay columna de capacidad en
// `mesa`); se deriva de forma estable a partir del número de mesa para que
// no cambie en cada rebuild, simulando variedad "aleatoria".
// Si `numeroPareja` no es null, esta mesa está unida a otra (mesa_pedido
// admite varias mesas por pedido) y se dibuja como una sola mesa ancha.
class MesaCard extends StatelessWidget {
  static const double _cuerpoChico = 110;
  static const double _cuerpoGrande = 150;
  static const double _grosorSilla = 36;
  static const double _largoSilla = 56;
  static const double _radioPlano = 15;
  // Espacio ("wrap") entre cada silla y el cuerpo de la mesa.
  static const double _separacion = 6;

  final int numero;
  final int? numeroPareja;
  final bool ocupada;
  final String? horaInicio;
  final double? monto;
  final VoidCallback onTap;
  final VoidCallback? onDesunir;

  const MesaCard({
    super.key,
    required this.numero,
    required this.ocupada,
    required this.onTap,
    this.numeroPareja,
    this.horaInicio,
    this.monto,
    this.onDesunir,
  });

  static int sillasDe(int numero) => Random(numero).nextBool() ? 4 : 2;

  static double anchoCuerpoDe(int numero) =>
      sillasDe(numero) == 4 ? _cuerpoGrande : _cuerpoChico;

  bool get _unida => numeroPareja != null;

  // Al unir dos mesas se suman sus sillas (ej. 2 + 4 = 6): izquierda/derecha
  // quedan en los extremos (1 cada una) y el resto se reparte entre arriba
  // y abajo, a lo largo del lado compartido.
  ({int izquierda, int derecha, int arriba, int abajo}) get _conteoSillas {
    if (_unida) {
      final total = sillasDe(numero) + sillasDe(numeroPareja!);
      final porLado = (total - 2) ~/ 2;
      return (izquierda: 1, derecha: 1, arriba: porLado, abajo: porLado);
    }
    final sillas = sillasDe(numero);
    return sillas == 4
        ? (izquierda: 1, derecha: 1, arriba: 1, abajo: 1)
        : (izquierda: 1, derecha: 1, arriba: 0, abajo: 0);
  }

  Size get _tamanoCuerpo {
    if (_unida) {
      return Size(
        anchoCuerpoDe(numero) + anchoCuerpoDe(numeroPareja!) + 8,
        _cuerpoGrande,
      );
    }
    final lado = anchoCuerpoDe(numero);
    return Size(lado, lado);
  }

  String get _etiqueta => _unida ? 'T-$numero+$numeroPareja' : 'T-$numero';

  @override
  Widget build(BuildContext context) {
    final cuerpo = _tamanoCuerpo;
    final fondo = ocupada ? AppColors.mesaOcupada : Colors.white;
    final borde = ocupada ? AppColors.mesaOcupada : const Color(0xFFE0E0E0);
    final textoPrincipal = ocupada ? Colors.white : Colors.black87;
    final textoSecundario = ocupada
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.grey.shade500;
    // Las sillas se dibujan fuera del cuerpo de la mesa, sobre el fondo de
    // la página: se mantienen del mismo gris siempre (libre u ocupada) para
    // que nunca queden invisibles por bajo contraste.
    const colorSilla = Color(0xFFE0E0E0);

    final anchoTotal = cuerpo.width + (_grosorSilla + _separacion) * 2;
    final altoTotal = cuerpo.height + (_grosorSilla + _separacion) * 2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      width: anchoTotal,
      height: altoTotal,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ..._construirSillas(anchoTotal, altoTotal, colorSilla),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            left: _grosorSilla + _separacion,
            top: _grosorSilla + _separacion,
            width: cuerpo.width,
            height: cuerpo.height,
            child: Material(
              color: fondo,
              borderRadius: BorderRadius.circular(30),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: borde),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _etiqueta,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: textoPrincipal,
                            ),
                          ),
                          const Spacer(),
                          if (ocupada && monto != null) ...[
                            _filaDato(
                              HugeIcons.strokeRoundedWallet01,
                              'S/ ${monto!.toStringAsFixed(2)}',
                              textoSecundario,
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (ocupada && horaInicio != null)
                            _filaDato(
                              HugeIcons.strokeRoundedClock01,
                              horaInicio!,
                              textoSecundario,
                            )
                          else
                            Text(
                              ocupada ? 'Ocupada' : 'Libre',
                              style: TextStyle(
                                fontSize: 12,
                                color: textoSecundario,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      if (_unida && onDesunir != null)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: InkWell(
                            onTap: onDesunir,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedUnlink01,
                                size: 16,
                                color: textoPrincipal,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Coloca izquierda/derecha centradas verticalmente (1 cada una); arriba y
  // abajo se reparten en `n` sillas espaciadas uniformemente a lo ancho.
  List<Widget> _construirSillas(
    double anchoTotal,
    double altoTotal,
    Color color,
  ) {
    final conteo = _conteoSillas;
    final widgets = <Widget>[];

    if (conteo.izquierda > 0) {
      widgets.add(
        Positioned(
          left: 0,
          top: (altoTotal - _largoSilla) / 2,
          child: _silla(_LadoSilla.izquierda, color),
        ),
      );
    }
    if (conteo.derecha > 0) {
      widgets.add(
        Positioned(
          right: 0,
          top: (altoTotal - _largoSilla) / 2,
          child: _silla(_LadoSilla.derecha, color),
        ),
      );
    }
    for (var i = 0; i < conteo.arriba; i++) {
      final left = anchoTotal * (i + 1) / (conteo.arriba + 1) - _largoSilla / 2;
      widgets.add(
        Positioned(top: 0, left: left, child: _silla(_LadoSilla.arriba, color)),
      );
    }
    for (var i = 0; i < conteo.abajo; i++) {
      final left = anchoTotal * (i + 1) / (conteo.abajo + 1) - _largoSilla / 2;
      widgets.add(
        Positioned(
          bottom: 0,
          left: left,
          child: _silla(_LadoSilla.abajo, color),
        ),
      );
    }
    return widgets;
  }

  // Una silla: rectángulo con un lado totalmente redondo (semicírculo, hacia
  // afuera de la mesa) y el lado pegado a la mesa con esquinas de 15px.
  Widget _silla(_LadoSilla lado, Color color) {
    final horizontal = lado == _LadoSilla.arriba || lado == _LadoSilla.abajo;
    final ancho = horizontal ? _largoSilla : _grosorSilla;
    final alto = horizontal ? _grosorSilla : _largoSilla;
    final radioRedondo = (horizontal ? alto : ancho) / 2;
    const plano = Radius.circular(_radioPlano);
    final redondo = Radius.circular(radioRedondo);

    late final BorderRadius radio;
    switch (lado) {
      case _LadoSilla.izquierda:
        radio = BorderRadius.only(
          topLeft: redondo,
          bottomLeft: redondo,
          topRight: plano,
          bottomRight: plano,
        );
      case _LadoSilla.derecha:
        radio = BorderRadius.only(
          topRight: redondo,
          bottomRight: redondo,
          topLeft: plano,
          bottomLeft: plano,
        );
      case _LadoSilla.arriba:
        radio = BorderRadius.only(
          topLeft: redondo,
          topRight: redondo,
          bottomLeft: plano,
          bottomRight: plano,
        );
      case _LadoSilla.abajo:
        radio = BorderRadius.only(
          bottomLeft: redondo,
          bottomRight: redondo,
          topLeft: plano,
          topRight: plano,
        );
    }

    // Padding leve para que, cuando hay varias sillas por lado, quede un
    // pequeño espacio entre cada una en vez de tocarse.
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Container(
        width: ancho,
        height: alto,
        decoration: BoxDecoration(color: color, borderRadius: radio),
      ),
    );
  }

  Widget _filaDato(List<List<dynamic>> icono, String texto, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icono, size: 13, color: color),
        const SizedBox(width: 4),
        Text(texto, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
