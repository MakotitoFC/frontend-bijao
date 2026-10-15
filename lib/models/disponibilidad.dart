// Cantidades diarias de platos (tablas `sede_config_stock` y
// `carta_disponibilidad`).

// Cómo maneja el stock diario una sede (`sede_config_stock`).
class SedeConfigStock {
  final String sedeId;
  // true: un plato sin registro del día NO se vende; false: se vende libre.
  final bool requiereAperturaDiaria;
  // true: se puede seguir vendiendo aunque la cantidad llegue a 0.
  final bool permiteSobreventa;
  // true: al llegar a 0 el plato queda agotado automáticamente.
  final bool autoAgotar;

  const SedeConfigStock({
    required this.sedeId,
    this.requiereAperturaDiaria = false,
    this.permiteSobreventa = false,
    this.autoAgotar = true,
  });

  factory SedeConfigStock.fromJson(Map<String, dynamic> json) =>
      SedeConfigStock(
        sedeId: json['sede_id']?.toString() ?? '',
        requiereAperturaDiaria: json['requiere_apertura_diaria'] == true,
        permiteSobreventa: json['permite_sobreventa'] == true,
        autoAgotar: json['auto_agotar'] != false,
      );

  SedeConfigStock copyWith({
    bool? requiereAperturaDiaria,
    bool? permiteSobreventa,
    bool? autoAgotar,
  }) => SedeConfigStock(
    sedeId: sedeId,
    requiereAperturaDiaria:
        requiereAperturaDiaria ?? this.requiereAperturaDiaria,
    permiteSobreventa: permiteSobreventa ?? this.permiteSobreventa,
    autoAgotar: autoAgotar ?? this.autoAgotar,
  );
}

// Disponibilidad de un plato en un día (`carta_disponibilidad`). Sin
// presentación ni variante es la fila general del plato.
class CartaDisponibilidad {
  final String id;
  final String sedeId;
  final String fecha; // YYYY-MM-DD
  final String cartaId;
  final String? cartaPresentacionId;
  final String? cartaVarianteId;
  // null = sin control de cantidad (solo se marca agotado).
  final int? cantidadInicial;
  final int? cantidadDisponible;
  final bool agotado;
  final String? motivoAgotado; // 'cantidad' | 'manual' | 'sin_insumo'
  final int version;
  final String? platoNombre;

  const CartaDisponibilidad({
    required this.id,
    required this.sedeId,
    required this.fecha,
    required this.cartaId,
    this.cartaPresentacionId,
    this.cartaVarianteId,
    this.cantidadInicial,
    this.cantidadDisponible,
    this.agotado = false,
    this.motivoAgotado,
    this.version = 1,
    this.platoNombre,
  });

  bool get esGeneral => cartaPresentacionId == null && cartaVarianteId == null;

  factory CartaDisponibilidad.fromJson(Map<String, dynamic> json) =>
      CartaDisponibilidad(
        id: json['id']?.toString() ?? '',
        sedeId: json['sede_id']?.toString() ?? '',
        fecha: json['fecha']?.toString() ?? '',
        cartaId: json['carta_id']?.toString() ?? '',
        cartaPresentacionId: json['carta_presentacion_id']?.toString(),
        cartaVarianteId: json['carta_variante_id']?.toString(),
        cantidadInicial: (json['cantidad_inicial'] as num?)?.toInt(),
        cantidadDisponible: (json['cantidad_disponible'] as num?)?.toInt(),
        agotado: json['agotado'] == true,
        motivoAgotado: json['motivo_agotado']?.toString(),
        version: (json['version'] as num?)?.toInt() ?? 1,
        platoNombre: json['plato_nombre']?.toString(),
      );
}

// Cantidad predeterminada de un plato para la apertura del día
// (`carta_stock_base`). `diaSemana` null = todos los días (0 = domingo).
class CartaStockBase {
  final String id;
  final String cartaId;
  final String? cartaPresentacionId;
  final String? cartaVarianteId;
  final int? diaSemana;
  final int cantidadPredeterminada;

  const CartaStockBase({
    required this.id,
    required this.cartaId,
    this.cartaPresentacionId,
    this.cartaVarianteId,
    this.diaSemana,
    required this.cantidadPredeterminada,
  });

  // Fila general: todos los días, sin presentación ni variante.
  bool get esGeneral =>
      diaSemana == null &&
      cartaPresentacionId == null &&
      cartaVarianteId == null;

  factory CartaStockBase.fromJson(Map<String, dynamic> json) => CartaStockBase(
    id: json['id']?.toString() ?? '',
    cartaId: json['carta_id']?.toString() ?? '',
    cartaPresentacionId: json['carta_presentacion_id']?.toString(),
    cartaVarianteId: json['carta_variante_id']?.toString(),
    diaSemana: (json['dia_semana'] as num?)?.toInt(),
    cantidadPredeterminada:
        (json['cantidad_predeterminada'] as num?)?.toInt() ?? 0,
  );
}

