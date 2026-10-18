import 'package:flutter/foundation.dart';

import '../models/disponibilidad.dart';

// Configuración de stock de la sede y disponibilidad de platos de hoy. Se
// cargan desde el backend (`DisponibilidadService`).
final ValueNotifier<SedeConfigStock?> configStockNotifier = ValueNotifier(null);
final ValueNotifier<List<CartaDisponibilidad>> disponibilidadHoyNotifier =
    ValueNotifier([]);

enum TipoDisponibilidad {
  // Sin registro de hoy y la sede no exige apertura: se vende libre.
  libre,
  // Con registro pero sin cantidad (solo "agotado" manual): se vende.
  sinLimite,
  // Con cantidad registrada: quedan N.
  conCantidad,
  agotado,
  // Sin registro de hoy y la sede exige apertura diaria: no se vende.
  sinApertura,
}

class EstadoDisponibilidad {
  final TipoDisponibilidad tipo;
  final int? quedan;

  const EstadoDisponibilidad(this.tipo, {this.quedan});

  bool get vendible =>
      tipo != TipoDisponibilidad.agotado &&
      tipo != TipoDisponibilidad.sinApertura;

  // Texto corto para mostrar junto al plato; null cuando no hay nada que decir.
  String? get etiqueta => switch (tipo) {
    TipoDisponibilidad.agotado => 'Agotado hoy',
    TipoDisponibilidad.sinApertura => 'Sin abrir hoy',
    TipoDisponibilidad.conCantidad => 'Quedan $quedan',
    _ => null,
  };
}

// Aplica la misma regla que el backend al vender: primero la fila exacta
// (presentación/variante); si no existe, la general del plato. Sin ninguna
// fila, depende de si la sede exige apertura diaria.
EstadoDisponibilidad estadoDisponibilidadDe(
  String cartaId, {
  String? presentacionId,
  String? varianteId,
  SedeConfigStock? config,
  List<CartaDisponibilidad>? filas,
}) {
  final cfg = config ?? configStockNotifier.value;
  final lista = filas ?? disponibilidadHoyNotifier.value;

  CartaDisponibilidad? fila;
  for (final f in lista) {
    if (f.cartaId == cartaId &&
        f.cartaPresentacionId == presentacionId &&
        f.cartaVarianteId == varianteId) {
      fila = f;
      break;
    }
  }
  if (fila == null && (presentacionId != null || varianteId != null)) {
    for (final f in lista) {
      if (f.cartaId == cartaId && f.esGeneral) {
        fila = f;
        break;
      }
    }
  }

  if (fila == null) {
    return (cfg?.requiereAperturaDiaria ?? false)
        ? const EstadoDisponibilidad(TipoDisponibilidad.sinApertura)
        : const EstadoDisponibilidad(TipoDisponibilidad.libre);
  }
  if (fila.agotado)
    return const EstadoDisponibilidad(TipoDisponibilidad.agotado);

  final disponible = fila.cantidadDisponible;
  if (fila.cantidadInicial != null && disponible != null) {
    if (disponible <= 0 && !(cfg?.permiteSobreventa ?? false)) {
      return const EstadoDisponibilidad(TipoDisponibilidad.agotado);
    }
    return EstadoDisponibilidad(
      TipoDisponibilidad.conCantidad,
      quedan: disponible < 0 ? 0 : disponible,
    );
  }
  return const EstadoDisponibilidad(TipoDisponibilidad.sinLimite);
}

// Unidades que todavía se pueden pedir hoy de un plato (según lo que se
// registró en "Abrir el día"); null = sin tope (sin cantidad registrada o con
// sobreventa).
int? topeDeUnidades(
  String cartaId, {
  String? presentacionId,
  String? varianteId,
}) {
  if (configStockNotifier.value?.permiteSobreventa ?? false) return null;
  final e = estadoDisponibilidadDe(
    cartaId,
    presentacionId: presentacionId,
    varianteId: varianteId,
  );
  return e.tipo == TipoDisponibilidad.conCantidad ? (e.quedan ?? 0) : null;
}

// Fila general (sin presentación ni variante) de un plato hoy, si existe.
CartaDisponibilidad? filaGeneralDe(String cartaId) {
  for (final f in disponibilidadHoyNotifier.value) {
    if (f.cartaId == cartaId && f.esGeneral) return f;
  }
  return null;
}
