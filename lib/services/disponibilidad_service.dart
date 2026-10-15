import 'dart:developer' as developer;

import '../data/disponibilidad_store.dart';
import '../models/disponibilidad.dart';
import 'api_client.dart';
import 'auth_service.dart';

// Cantidades diarias de platos: configuración de la sede, apertura del día y
// marcar "se acabó". Usa /api/sede-config-stock y /api/carta-disponibilidad.
class DisponibilidadService {
  DisponibilidadService._();
  static final DisponibilidadService instance = DisponibilidadService._();

  final ApiClient _api = ApiClient.instance;

  String? get _sedeId {
    final id = AuthService.instance.currentUser?.sedeId;
    return (id == null || id.isEmpty) ? null : id;
  }

  // Fecha local de hoy (YYYY-MM-DD).
  static String fechaHoy() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  // Carga la configuración de la sede y la disponibilidad de hoy. Si el usuario
  // no tiene permiso de lectura queda vacío: el backend valida igual al vender.
  Future<void> cargarHoy() async {
    final sedeId = _sedeId;
    if (sedeId == null) return;
    await Future.wait([_cargarConfig(sedeId), _cargarFilas(sedeId)]);
  }

  Future<void> _cargarConfig(String sedeId) async {
    try {
      final res = await _api.get('/api/sede-config-stock/$sedeId');
      if (res is Map<String, dynamic>) {
        configStockNotifier.value = SedeConfigStock.fromJson(res);
      }
    } catch (e) {
      developer.log(
        '[DisponibilidadService] Error al leer la configuración: $e',
      );
    }
  }

  Future<void> _cargarFilas(String sedeId) async {
    try {
      final res = await _api.get(
        '/api/carta-disponibilidad?sede_id=$sedeId&fecha=${fechaHoy()}',
      );
      if (res is List) {
        disponibilidadHoyNotifier.value = [
          for (final f in res)
            CartaDisponibilidad.fromJson(f as Map<String, dynamic>),
        ];
      }
    } catch (e) {
      developer.log(
        '[DisponibilidadService] Error al leer la disponibilidad: $e',
      );
    }
  }

  Future<SedeConfigStock> guardarConfig({
    bool? requiereAperturaDiaria,
    bool? permiteSobreventa,
    bool? autoAgotar,
  }) async {
    final sedeId = _sedeId;
    if (sedeId == null) {
      throw Exception('El usuario no tiene una sede asignada');
    }
    final res = await _api.put(
      '/api/sede-config-stock/$sedeId',
      body: {
        'requiere_apertura_diaria': ?requiereAperturaDiaria,
        'permite_sobreventa': ?permiteSobreventa,
        'auto_agotar': ?autoAgotar,
      },
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('Respuesta inesperada al guardar la configuración');
    }
    final cfg = SedeConfigStock.fromJson(res);
    configStockNotifier.value = cfg;
    return cfg;
  }

  // Marca un plato como agotado hoy, o lo reabre. Si hoy no tiene fila general
  // la crea (sin control de cantidad).
  Future<void> marcarAgotado(String cartaId, bool agotado) async {
    final sedeId = _sedeId;
    if (sedeId == null) {
      throw Exception('El usuario no tiene una sede asignada');
    }
    final fila = filaGeneralDe(cartaId);
    if (fila != null) {
      await _api.put(
        '/api/carta-disponibilidad/${fila.id}/agotado',
        body: {'agotado': agotado, if (agotado) 'motivo_agotado': 'manual'},
      );
    } else if (agotado) {
      await _api.post(
        '/api/carta-disponibilidad',
        body: {
          'sede_id': sedeId,
          'fecha': fechaHoy(),
          'carta_id': cartaId,
          'agotado': true,
          'motivo_agotado': 'manual',
        },
      );
    } else {
      return; // sin fila no hay nada que reabrir
    }
    await _cargarFilas(sedeId);
  }

  // Cantidades base (`carta_stock_base`): lo que se precarga en la apertura.
  Future<List<CartaStockBase>> cargarStockBase() async {
    final res = await _api.get('/api/carta-stock-base');
    if (res is! List) return const [];
    return [
      for (final f in res) CartaStockBase.fromJson(f as Map<String, dynamic>),
    ];
  }

  // Fija la cantidad base de un plato para todos los días.
  Future<void> guardarStockBase(String cartaId, int cantidad) async {
    await _api.post(
      '/api/carta-stock-base',
      body: {'carta_id': cartaId, 'cantidad_predeterminada': cantidad},
    );
  }

  Future<void> eliminarStockBase(String id) async {
    await _api.delete('/api/carta-stock-base/$id');
  }

  // Apertura del día en lote. Con [usarBase] precarga las cantidades de
  // `carta_stock_base`; [items] sobrescribe o agrega platos concretos.
  Future<void> aperturaDiaria({
    bool usarBase = false,
    List<AperturaItem> items = const [],
  }) async {
    final sedeId = _sedeId;
    if (sedeId == null) {
      throw Exception('El usuario no tiene una sede asignada');
    }
    await _api.post(
      '/api/carta-disponibilidad/apertura-batch',
      body: {
        'sede_id': sedeId,
        'fecha': fechaHoy(),
        'usar_base': usarBase,
        if (items.isNotEmpty) 'items': [for (final i in items) i.toJson()],
      },
    );
    await _cargarFilas(sedeId);
  }
}

// Una línea de la apertura del día: cantidad inicial (null = sin límite) y/o
// agotado.
class AperturaItem {
  final String cartaId;
  final int? cantidadInicial;
  final bool? agotado;

  const AperturaItem({
    required this.cartaId,
    this.cantidadInicial,
    this.agotado,
  });

  Map<String, dynamic> toJson() => {
    'carta_id': cartaId,
    'cantidad_inicial': ?cantidadInicial,
    'agotado': ?agotado,
  };
}
