import 'package:flutter/material.dart';

// Refleja la tabla `horarios`: dia, inicio, fin, abierto.
class Horario {
  final String dia;
  final TimeOfDay? inicio;
  final TimeOfDay? fin;
  final bool abierto;

  const Horario({
    required this.dia,
    this.inicio,
    this.fin,
    this.abierto = true,
  });

  Horario copyWith({TimeOfDay? inicio, TimeOfDay? fin, bool? abierto}) =>
      Horario(
        dia: dia,
        inicio: inicio ?? this.inicio,
        fin: fin ?? this.fin,
        abierto: abierto ?? this.abierto,
      );
}
