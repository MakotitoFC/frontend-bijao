import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/mesas_store.dart';
import '../theme/app_theme.dart';

enum _LadoSilla { izquierda, derecha, arriba, abajo }

// Tarjeta de mesa (número de sillas según `Mesa.capacidad`). Si `unidas` no
// está vacío, dibuja una sola mesa ancha (varias mesas por pedido); si no
// entra en el ancho disponible, se dibuja compacta (`simplificada`).
class MesaCard extends StatelessWidget {
  static const double _cuerpoChico = 110;
  static const double _cuerpoGrande = 150;
  static const double _grosorSilla = 36;
  static const double _largoSilla = 56;
  static const double _radioPlano = 15;
  // Espacio ("wrap") entre cada silla y el cuerpo de la mesa.
  static const double _separacion = 6;

  final int numero;
  final List<int> unidas;
  final bool ocupada;
  final String? horaInicio;
  final double? monto;
  final String? mesero;
  final VoidCallback onTap;
  final VoidCallback? onDesunir;
  // Escala del dibujo (1 = escritorio, <1 = mobile/tablet).
  final double scale;
  // Fuerza la tarjeta compacta según el ancho disponible.
  final bool simplificada;

  const MesaCard({
    super.key,
    required this.numero,
    required this.ocupada,
    required this.onTap,
    this.unidas = const [],
    this.horaInicio,
    this.monto,
    this.mesero,
    this.onDesunir,
    this.scale = 1,
    this.simplificada = false,
  });

  static int sillasDe(int numero) => capacidadDe(numero);

  // Total de sillas de una mesa (unida o no).
  static int totalSillasDe(int numero, List<int> unidas) =>
      sillasDe(numero) + unidas.fold(0, (a, n) => a + sillasDe(n));

  static double anchoCuerpoDe(int numero) =>
      sillasDe(numero) >= 4 ? _cuerpoGrande : _cuerpoChico;

  // Reparte las sillas entre los 4 lados de la mesa.
  static ({int izquierda, int derecha, int arriba, int abajo}) _distribuir(
    int total,
  ) {
    if (total <= 1) {
      return (izquierda: 0, derecha: 0, arriba: total, abajo: 0);
    }
    final resto = total - 2;
    return (
      izquierda: 1,
      derecha: 1,
      arriba: (resto + 1) ~/ 2,
      abajo: resto ~/ 2,
    );
  }

  int get _totalSillas =>
      sillasDe(numero) + unidas.fold(0, (a, n) => a + sillasDe(n));

  bool get _unida => unidas.isNotEmpty;

  // Al unir mesas se suman sus sillas (ej. 2 + 4 + 2 = 8).
  ({int izquierda, int derecha, int arriba, int abajo}) get _conteoSillas =>
      _distribuir(_totalSillas);

  // El cuerpo crece a lo ancho si hacen falta más sillas arriba o abajo.
  Size get _tamanoCuerpo {
    final conteo = _conteoSillas;
    final porLado = conteo.arriba > conteo.abajo ? conteo.arriba : conteo.abajo;
    final anchoNecesario = porLado * (_largoSilla + 10) + 30;
    if (_unida) {
      final ancho =
          anchoCuerpoDe(numero) +
          unidas.fold(0.0, (a, n) => a + anchoCuerpoDe(n) + 8);
      return Size(
        ancho > anchoNecesario ? ancho : anchoNecesario,
        _cuerpoGrande,
      );
    }
    final base = _totalSillas >= 4 ? _cuerpoGrande : _cuerpoChico;
    return Size(base > anchoNecesario ? base : anchoNecesario, base);
  }

  String get _etiqueta =>
      _unida ? 'T-$numero+${unidas.join('+')}' : 'T-$numero';

  @override
  Widget build(BuildContext context) {
    if (simplificada) return _cardCompacta(context);

    final cuerpo = _tamanoCuerpo * scale;
    final grosorSilla = _grosorSilla * scale;
    final largoSilla = _largoSilla * scale;
    final separacion = _separacion * scale;
    // Libre = verde, ocupada = rojo.
    final base = ocupada ? AppColors.error : AppColors.primaryGreen;
    final fondo = Color.alphaBlend(base.withValues(alpha: 0.62), Colors.white);
    final textoPrincipal = Colors.white;
    final textoSecundario = Colors.white.withValues(alpha: 0.9);
    final colorSilla = base.withValues(alpha: 0.22);

    final anchoTotal = cuerpo.width + (grosorSilla + separacion) * 2;
    final altoTotal = cuerpo.height + (grosorSilla + separacion) * 2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      width: anchoTotal,
      height: altoTotal,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ..._construirSillas(
            anchoTotal,
            altoTotal,
            colorSilla,
            grosorSilla,
            largoSilla,
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            left: grosorSilla + separacion,
            top: grosorSilla + separacion,
            width: cuerpo.width,
            height: cuerpo.height,
            child: Material(
              color: fondo,
              borderRadius: BorderRadius.circular(30 * scale),
              child: InkWell(
                borderRadius: BorderRadius.circular(30 * scale),
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.all(14 * scale),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _etiqueta,
                            style: TextStyle(
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w700,
                              color: textoPrincipal,
                            ),
                          ),
                          const Spacer(),
                          if (ocupada && mesero != null) ...[
                            _filaDato(
                              LucideIcons.user,
                              mesero!,
                              textoSecundario,
                              scale,
                            ),
                            SizedBox(height: 4 * scale),
                          ],
                          if (ocupada && monto != null) ...[
                            _filaDato(
                              LucideIcons.wallet,
                              'S/ ${monto!.toStringAsFixed(2)}',
                              textoSecundario,
                              scale,
                            ),
                            SizedBox(height: 4 * scale),
                          ],
                          if (ocupada && horaInicio != null)
                            _filaDato(
                              LucideIcons.clock,
                              horaInicio!,
                              textoSecundario,
                              scale,
                            )
                          else
                            Text(
                              ocupada ? 'Ocupada' : 'Libre',
                              style: TextStyle(
                                fontSize: 12 * scale,
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
                              child: Icon(
                                LucideIcons.unlink,
                                size: 16 * scale,
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

  // Tarjeta compacta: mesas unidas + total de clientes, sin dibujar sillas.
  Widget _cardCompacta(BuildContext context) {
    final base = ocupada ? AppColors.error : AppColors.primaryGreen;
    final fondo = Color.alphaBlend(base.withValues(alpha: 0.62), Colors.white);
    final textoPrincipal = Colors.white;
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 168,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.link, size: 15, color: textoPrincipal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _etiqueta,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textoPrincipal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (ocupada && mesero != null) ...[
                _filaDato(
                  LucideIcons.user,
                  mesero!,
                  textoPrincipal.withValues(alpha: 0.85),
                  1,
                ),
                const SizedBox(height: 4),
              ],
              _filaDato(
                LucideIcons.users,
                '$_totalSillas clientes',
                textoPrincipal.withValues(alpha: 0.85),
                1,
              ),
              const SizedBox(height: 4),
              Text(
                ocupada ? 'Ocupada' : 'Libre',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textoPrincipal.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Ubica cada silla según su lado.
  List<Widget> _construirSillas(
    double anchoTotal,
    double altoTotal,
    Color color,
    double grosorSilla,
    double largoSilla,
  ) {
    final conteo = _conteoSillas;
    final widgets = <Widget>[];

    if (conteo.izquierda > 0) {
      widgets.add(
        Positioned(
          left: 0,
          top: (altoTotal - largoSilla) / 2,
          child: _silla(_LadoSilla.izquierda, color, grosorSilla, largoSilla),
        ),
      );
    }
    if (conteo.derecha > 0) {
      widgets.add(
        Positioned(
          right: 0,
          top: (altoTotal - largoSilla) / 2,
          child: _silla(_LadoSilla.derecha, color, grosorSilla, largoSilla),
        ),
      );
    }
    for (var i = 0; i < conteo.arriba; i++) {
      final left = anchoTotal * (i + 1) / (conteo.arriba + 1) - largoSilla / 2;
      widgets.add(
        Positioned(
          top: 0,
          left: left,
          child: _silla(_LadoSilla.arriba, color, grosorSilla, largoSilla),
        ),
      );
    }
    for (var i = 0; i < conteo.abajo; i++) {
      final left = anchoTotal * (i + 1) / (conteo.abajo + 1) - largoSilla / 2;
      widgets.add(
        Positioned(
          bottom: 0,
          left: left,
          child: _silla(_LadoSilla.abajo, color, grosorSilla, largoSilla),
        ),
      );
    }
    return widgets;
  }

  // Dibuja una silla.
  Widget _silla(
    _LadoSilla lado,
    Color color,
    double grosorSilla,
    double largoSilla,
  ) {
    final horizontal = lado == _LadoSilla.arriba || lado == _LadoSilla.abajo;
    final ancho = horizontal ? largoSilla : grosorSilla;
    final alto = horizontal ? grosorSilla : largoSilla;
    final radioRedondo = (horizontal ? alto : ancho) / 2;
    final plano = Radius.circular(_radioPlano * scale);
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

    // Espacio entre sillas del mismo lado.
    return Padding(
      padding: EdgeInsets.all(3 * scale),
      child: Container(
        width: ancho,
        height: alto,
        decoration: BoxDecoration(color: color, borderRadius: radio),
      ),
    );
  }

  Widget _filaDato(IconData icono, String texto, Color color, double escala) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 13 * escala, color: color),
        SizedBox(width: 4 * escala),
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11 * escala, color: color),
          ),
        ),
      ],
    );
  }
}
