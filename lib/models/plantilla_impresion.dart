class PlantillaImpresion {
  final String id;
  final String sedeId;
  final String tipoDocumento;
  final String nombrePlantilla;
  final int anchoPapelMm;
  final bool imprimirLogo;
  final bool imprimirQr;
  final bool imprimirMontoLetras;
  final bool imprimirDatosFiscales;
  final bool imprimirMozo;
  final bool imprimirTaper;
  final bool imprimirMesaZona;
  final String? encabezadoPersonalizado;
  final String? piePaginaPersonalizado;
  final String? mensajeFiscal;
  final String tamanioTitulo;
  final String tamanioCodigoOrden;
  final String tamanioPlato;
  final String? tamanioDescripcion;
  final Map<String, dynamic> configExtra;
  final bool activo;

  PlantillaImpresion({
    required this.id,
    required this.sedeId,
    required this.tipoDocumento,
    required this.nombrePlantilla,
    this.anchoPapelMm = 80,
    this.imprimirLogo = false,
    this.imprimirQr = true,
    this.imprimirMontoLetras = true,
    this.imprimirDatosFiscales = true,
    this.imprimirMozo = true,
    this.imprimirTaper = true,
    this.imprimirMesaZona = true,
    this.encabezadoPersonalizado,
    this.piePaginaPersonalizado,
    this.mensajeFiscal,
    this.tamanioTitulo = 'doble_alto',
    this.tamanioCodigoOrden = 'doble_alto',
    this.tamanioPlato = 'normal',
    this.tamanioDescripcion,
    this.configExtra = const {},
    this.activo = true,
  });

  factory PlantillaImpresion.fromJson(Map<String, dynamic> json) {
    return PlantillaImpresion(
      id: json['id']?.toString() ?? '',
      sedeId: json['sede_id']?.toString() ?? '',
      tipoDocumento: json['tipo_documento']?.toString() ?? '',
      nombrePlantilla: json['nombre_plantilla']?.toString() ?? 'Plantilla Estándar',
      anchoPapelMm: (json['ancho_papel_mm'] as num?)?.toInt() ?? 80,
      imprimirLogo: json['imprimir_logo'] == true,
      imprimirQr: json['imprimir_qr'] == true,
      imprimirMontoLetras: json['imprimir_monto_letras'] == true,
      imprimirDatosFiscales: json['imprimir_datos_fiscales'] == true,
      imprimirMozo: json['imprimir_mozo'] == true,
      imprimirTaper: json['imprimir_taper'] == true,
      imprimirMesaZona: json['imprimir_mesa_zona'] == true,
      encabezadoPersonalizado: json['encabezado_personalizado']?.toString(),
      piePaginaPersonalizado: json['pie_pagina_personalizado']?.toString(),
      mensajeFiscal: json['mensaje_fiscal']?.toString(),
      tamanioTitulo: json['tamanio_titulo']?.toString() ?? 'doble_alto',
      tamanioCodigoOrden: json['tamanio_codigo_orden']?.toString() ?? 'doble_alto',
      tamanioPlato: json['tamanio_plato']?.toString() ?? 'normal',
      tamanioDescripcion: json['tamanio_descripcion']?.toString(),
      configExtra: json['config_extra'] is Map<String, dynamic>
          ? json['config_extra'] as Map<String, dynamic>
          : {},
      activo: json['activo'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre_plantilla': nombrePlantilla,
      'ancho_papel_mm': anchoPapelMm,
      'imprimir_logo': imprimirLogo,
      'imprimir_qr': imprimirQr,
      'imprimir_monto_letras': imprimirMontoLetras,
      'imprimir_datos_fiscales': imprimirDatosFiscales,
      'imprimir_mozo': imprimirMozo,
      'imprimir_taper': imprimirTaper,
      'imprimir_mesa_zona': imprimirMesaZona,
      'encabezado_personalizado': encabezadoPersonalizado,
      'pie_pagina_personalizado': piePaginaPersonalizado,
      'mensaje_fiscal': mensajeFiscal,
      'tamanio_titulo': tamanioTitulo,
      'tamanio_codigo_orden': tamanioCodigoOrden,
      'tamanio_plato': tamanioPlato,
      'tamanio_descripcion': tamanioDescripcion,
      'config_extra': configExtra,
      'activo': activo,
    };
  }

  PlantillaImpresion copyWith({
    String? nombrePlantilla,
    int? anchoPapelMm,
    bool? imprimirLogo,
    bool? imprimirQr,
    bool? imprimirMontoLetras,
    bool? imprimirDatosFiscales,
    bool? imprimirMozo,
    bool? imprimirTaper,
    bool? imprimirMesaZona,
    String? encabezadoPersonalizado,
    String? piePaginaPersonalizado,
    String? mensajeFiscal,
    String? tamanioTitulo,
    String? tamanioCodigoOrden,
    String? tamanioPlato,
    String? tamanioDescripcion,
    Map<String, dynamic>? configExtra,
    bool? activo,
  }) {
    return PlantillaImpresion(
      id: id,
      sedeId: sedeId,
      tipoDocumento: tipoDocumento,
      nombrePlantilla: nombrePlantilla ?? this.nombrePlantilla,
      anchoPapelMm: anchoPapelMm ?? this.anchoPapelMm,
      imprimirLogo: imprimirLogo ?? this.imprimirLogo,
      imprimirQr: imprimirQr ?? this.imprimirQr,
      imprimirMontoLetras: imprimirMontoLetras ?? this.imprimirMontoLetras,
      imprimirDatosFiscales: imprimirDatosFiscales ?? this.imprimirDatosFiscales,
      imprimirMozo: imprimirMozo ?? this.imprimirMozo,
      imprimirTaper: imprimirTaper ?? this.imprimirTaper,
      imprimirMesaZona: imprimirMesaZona ?? this.imprimirMesaZona,
      encabezadoPersonalizado: encabezadoPersonalizado ?? this.encabezadoPersonalizado,
      piePaginaPersonalizado: piePaginaPersonalizado ?? this.piePaginaPersonalizado,
      mensajeFiscal: mensajeFiscal ?? this.mensajeFiscal,
      tamanioTitulo: tamanioTitulo ?? this.tamanioTitulo,
      tamanioCodigoOrden: tamanioCodigoOrden ?? this.tamanioCodigoOrden,
      tamanioPlato: tamanioPlato ?? this.tamanioPlato,
      tamanioDescripcion: tamanioDescripcion ?? this.tamanioDescripcion,
      configExtra: configExtra ?? this.configExtra,
      activo: activo ?? this.activo,
    );
  }
}
