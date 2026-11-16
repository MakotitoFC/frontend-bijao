import 'package:flutter/foundation.dart';

import '../models/disponibilidad.dart';
import 'cartas_store.dart';

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
  // El producto de inventario del que depende el plato está en 0. Se puede pedir
  // salvo que la sede lo bloquee (Configuración > Stock).
  agotadoInventario,
  // El producto de inventario del que depende el plato está por agotarse. Se vende
  // normal: solo se avisa.
  stockBajoInventario,
}

class EstadoDisponibilidad {
  final TipoDisponibilidad tipo;
  final int? quedan;

  const EstadoDisponibilidad(this.tipo, {this.quedan});

  bool get vendible =>
      tipo != TipoDisponibilidad.agotado &&
      tipo != TipoDisponibilidad.sinApertura &&
      !(tipo == TipoDisponibilidad.agotadoInventario &&
          (configStockNotifier.value?.bloquearAgotadoInventario ?? false));

  // Texto corto para mostrar junto al plato; null cuando no hay nada que decir.
  String? get etiqueta => switch (tipo) {
    TipoDisponibilidad.agotado => 'Agotado hoy',
    TipoDisponibilidad.sinApertura => 'Sin abrir hoy',
    TipoDisponibilidad.agotadoInventario => 'Agotado',
    TipoDisponibilidad.stockBajoInventario =>
      quedan != null ? 'Quedan $quedan' : 'Por agotarse',
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

  // "Agotado hoy" marcado a mano.
  if (fila != null && fila.agotado) {
    return const EstadoDisponibilidad(TipoDisponibilidad.agotado);
  }
  // Agotado en inventario (el servidor lo calcula con el stock de los insumos).
  if (cartaPorId(cartaId)?.agotadoInventario ?? false) {
    return const EstadoDisponibilidad(TipoDisponibilidad.agotadoInventario);
  }
  final bajo = cartaPorId(cartaId);
  if (bajo?.stockBajoInventario ?? false) {
    return EstadoDisponibilidad(
      TipoDisponibilidad.stockBajoInventario,
      quedan: bajo!.quedanInventario,
    );
  }
  // La apertura diaria y la cantidad diaria ya no limitan las ventas: sin fila de
  // hoy, el plato se vende libre.
  if (fila == null) return const EstadoDisponibilidad(TipoDisponibilidad.libre);

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
  // Sin tope por cantidad diaria: el stock de inventario no limita los pedidos.
  return null;
}

// Fila general (sin presentación ni variante) de un plato hoy, si existe.
CartaDisponibilidad? filaGeneralDe(String cartaId) {
  for (final f in disponibilidadHoyNotifier.value) {
    if (f.cartaId == cartaId && f.esGeneral) return f;
  }
  return null;
}
