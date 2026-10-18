// Configuración de las impresoras térmicas de la sede (`sede_config_impresora`).
class ConfigImpresora {
  final String cocinaIp;
  final bool cocinaHabilitada;
  final String cajaIp;
  final bool cajaHabilitada;
  final String logoPath;
  final bool cajaImprimirLogo;
  final bool pausarCola;
  final bool descartarAntiguosDias;
  final bool cocinaMostrarMozo;
  final bool cocinaMostrarFecha;
  final bool cocinaMostrarNotas;
  final bool cocinaMostrarTaper;
  // 'doble' o 'normal'.
  final String cocinaTamanoLetra;

  const ConfigImpresora({
    required this.cocinaIp,
    required this.cocinaHabilitada,
    required this.cajaIp,
    required this.cajaHabilitada,
    required this.logoPath,
    required this.cajaImprimirLogo,
    required this.pausarCola,
    required this.descartarAntiguosDias,
    required this.cocinaMostrarMozo,
    required this.cocinaMostrarFecha,
    required this.cocinaMostrarNotas,
    required this.cocinaMostrarTaper,
    required this.cocinaTamanoLetra,
  });

  factory ConfigImpresora.fromJson(Map<String, dynamic> json) =>
      ConfigImpresora(
        cocinaIp: json['cocina_ip']?.toString() ?? '',
        cocinaHabilitada: json['cocina_habilitada'] as bool? ?? true,
        cajaIp: json['caja_ip']?.toString() ?? '',
        cajaHabilitada: json['caja_habilitada'] as bool? ?? false,
        logoPath: json['logo_path']?.toString() ?? '',
        cajaImprimirLogo: json['caja_imprimir_logo'] as bool? ?? true,
        pausarCola: json['pausar_cola'] as bool? ?? false,
        descartarAntiguosDias: json['descartar_antiguos_dias'] as bool? ?? true,
        cocinaMostrarMozo: json['cocina_mostrar_mozo'] as bool? ?? true,
        cocinaMostrarFecha: json['cocina_mostrar_fecha'] as bool? ?? true,
        cocinaMostrarNotas: json['cocina_mostrar_notas'] as bool? ?? true,
        cocinaMostrarTaper: json['cocina_mostrar_taper'] as bool? ?? true,
        cocinaTamanoLetra: json['cocina_tamano_letra']?.toString() ?? 'doble',
      );

  Map<String, dynamic> toJson() => {
    'cocina_ip': cocinaIp,
    'cocina_habilitada': cocinaHabilitada,
    'caja_ip': cajaIp,
    'caja_habilitada': cajaHabilitada,
    'caja_imprimir_logo': cajaImprimirLogo,
    'descartar_antiguos_dias': descartarAntiguosDias,
    'cocina_mostrar_mozo': cocinaMostrarMozo,
    'cocina_mostrar_fecha': cocinaMostrarFecha,
    'cocina_mostrar_notas': cocinaMostrarNotas,
    'cocina_mostrar_taper': cocinaMostrarTaper,
    'cocina_tamano_letra': cocinaTamanoLetra,
  };
}

// Conexión física de cada impresora (el backend hace un ping a su IP).
class EstadoImpresoras {
  final String cocinaIp;
  final bool cocinaConectada;
  final bool cocinaHabilitada;
  final String cajaIp;
  final bool cajaConectada;
  final bool cajaHabilitada;
  final int colaPendientes;
  final int colaCompletados;
  final int colaErrores;
  final bool colaPausada;
  final String logoConfigurado;

  const EstadoImpresoras({
    this.cocinaIp = '',
    this.cocinaConectada = false,
    this.cocinaHabilitada = false,
    this.cajaIp = '',
    this.cajaConectada = false,
    this.cajaHabilitada = false,
    this.colaPendientes = 0,
    this.colaCompletados = 0,
    this.colaErrores = 0,
    this.colaPausada = false,
    this.logoConfigurado = '',
  });

  factory EstadoImpresoras.fromJson(Map<String, dynamic> json) =>
      EstadoImpresoras(
        cocinaIp: json['cocina_ip']?.toString() ?? '',
        cocinaConectada: json['cocina_conectada'] == true,
        cocinaHabilitada: json['cocina_habilitada'] == true,
        cajaIp: json['caja_ip']?.toString() ?? '',
        cajaConectada: json['caja_conectada'] == true,
        cajaHabilitada: json['caja_habilitada'] == true,
        colaPendientes: (json['cola_pendientes'] as num?)?.toInt() ?? 0,
        colaCompletados: (json['cola_completados'] as num?)?.toInt() ?? 0,
        colaErrores: (json['cola_errores'] as num?)?.toInt() ?? 0,
        colaPausada: json['cola_pausada'] == true,
        logoConfigurado: json['logo_configurado']?.toString() ?? '',
      );
}

// Un trabajo de impresión de la cola.
class TrabajoImpresion {
  final String id;
  final String pedidoId;
  // 'comanda_cocina', 'comanda_adicional', 'reimpresion'...
  final String tipo;
  final String codigoOrden; // '#0001'
  // 'pendiente', 'imprimiendo', 'completado', 'error', 'cancelado', 'expirado',
  // 'simulado'.
  final String estado;
  final int intentos;
  final String? error;
  final DateTime? creado;

  const TrabajoImpresion({
    required this.id,
    required this.pedidoId,
    required this.tipo,
    required this.codigoOrden,
    required this.estado,
    required this.intentos,
    this.error,
    this.creado,
  });

  factory TrabajoImpresion.fromJson(Map<String, dynamic> json) =>
      TrabajoImpresion(
        id: json['id']?.toString() ?? '',
        pedidoId: json['pedido_id']?.toString() ?? '',
        tipo: json['tipo']?.toString() ?? '',
        codigoOrden: json['codigo_orden']?.toString() ?? '',
        estado: json['estado']?.toString() ?? '',
        intentos: (json['intentos'] as num?)?.toInt() ?? 0,
        error: json['error_msg']?.toString() ?? json['error']?.toString(),
        creado: DateTime.tryParse(json['created_at']?.toString() ?? '')
            ?.toLocal(),
      );

  // Se puede volver a mandar si no se imprimió.
  bool get sePuedeReintentar =>
      estado == 'error' || estado == 'cancelado' || estado == 'expirado';

  String get etiquetaTipo => switch (tipo) {
    'comanda_cocina' => 'Comanda de cocina',
    'comanda_adicional' => 'Adicional de cocina',
    'reimpresion' => 'Reimpresión',
    _ => tipo.replaceAll('_', ' '),
  };

  String get etiquetaEstado => switch (estado) {
    'pendiente' => 'Pendiente',
    'imprimiendo' => 'Imprimiendo',
    'completado' => 'Impreso',
    'error' => 'Con error',
    'cancelado' => 'Cancelado',
    'expirado' => 'Omitido por cambio de día',
    'simulado' => 'Simulado',
    _ => estado,
  };
}

class ColaImpresion {
  final int pendientes;
  final int completados;
  final int conError;
  final List<TrabajoImpresion> trabajos;

  const ColaImpresion({
    this.pendientes = 0,
    this.completados = 0,
    this.conError = 0,
    this.trabajos = const [],
  });

  factory ColaImpresion.fromJson(Map<String, dynamic> json) => ColaImpresion(
    pendientes: (json['pendientes'] as num?)?.toInt() ?? 0,
    completados: (json['completados'] as num?)?.toInt() ?? 0,
    conError: (json['con_error'] as num?)?.toInt() ?? 0,
    trabajos: [
      for (final j in (json['jobs'] as List? ?? const []))
        if (j is Map<String, dynamic>) TrabajoImpresion.fromJson(j),
    ],
  );
}
