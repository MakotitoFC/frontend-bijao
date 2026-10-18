import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pedido_line.dart';
import '../utils/linea_local_codec.dart';
import '../widgets/tupper_dialog.dart' show TupperConfigurado;

// Pedido que se está armando y todavía no se envió. Se guarda en el dispositivo
// (almacenamiento local de Flutter: en el APK de Android es SharedPreferences y
// en el navegador, localStorage) para que no se pierda al cambiar de vista, al
// minimizar la app o al cerrarla.
//
// Regla clave: en cuanto el pedido se envía al servidor, el borrador se borra
// del dispositivo de inmediato (`limpiarBorradorPedido`). Si se dejara, el
// pedido ya enviado volvería a aparecer como borrador y se podría duplicar.
// También se borra al cerrarlo con la "x", al volver a elegir el tipo de
// pedido, al cerrar sesión (no queda ninguna copia) y cuando pasan más de 30 minutos.
class BorradorPedido {
  final String usuarioId;
  // 'mesa', 'llevar' o 'delivery'.
  final String tipo;
  final int? mesaNumero;
  final String? mesaId;
  final List<PedidoLine> carrito;
  final bool descEmpleado;
  final double propina;
  final TupperConfigurado tupper;
  final String nombre;
  final String telefono;
  final String direccion;
  final String referencia;
  final String envio;
  final String notas;
  // true mientras el pedido se está enviando: si la app se cierra en ese
  // momento no se sabe si llegó al servidor, así que al volver se descarta en
  // vez de arriesgar un pedido duplicado.
  final bool enviando;
  final DateTime guardadoEn;

  BorradorPedido({
    required this.usuarioId,
    required this.tipo,
    required this.mesaNumero,
    required this.mesaId,
    required this.carrito,
    required this.descEmpleado,
    required this.propina,
    required this.tupper,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    required this.referencia,
    required this.envio,
    required this.notas,
    this.enviando = false,
    DateTime? guardadoEn,
  }) : guardadoEn = guardadoEn ?? DateTime.now();

  // ¿Hay algo que valga la pena conservar? Un pedido recién abierto, sin nada,
  // no se guarda.
  bool get tieneContenido =>
      carrito.isNotEmpty ||
      mesaNumero != null ||
      nombre.trim().isNotEmpty ||
      telefono.trim().isNotEmpty ||
      direccion.trim().isNotEmpty ||
      referencia.trim().isNotEmpty ||
      notas.trim().isNotEmpty ||
      propina > 0 ||
      descEmpleado;

  BorradorPedido conEnviando(bool valor) => BorradorPedido(
    usuarioId: usuarioId,
    tipo: tipo,
    mesaNumero: mesaNumero,
    mesaId: mesaId,
    carrito: carrito,
    descEmpleado: descEmpleado,
    propina: propina,
    tupper: tupper,
    nombre: nombre,
    telefono: telefono,
    direccion: direccion,
    referencia: referencia,
    envio: envio,
    notas: notas,
    enviando: valor,
    guardadoEn: guardadoEn,
  );

  Map<String, dynamic> toJson() => {
    'usuario_id': usuarioId,
    'tipo': tipo,
    'mesa_numero': mesaNumero,
    'mesa_id': mesaId,
    'carrito': [for (final l in carrito) lineaAJsonLocal(l)],
    'desc_empleado': descEmpleado,
    'propina': propina,
    'tupper': {
      'grande': tupper.grande,
      'precio_grande': tupper.precioGrande,
      'mediano': tupper.mediano,
      'precio_mediano': tupper.precioMediano,
    },
    'nombre': nombre,
    'telefono': telefono,
    'direccion': direccion,
    'referencia': referencia,
    'envio': envio,
    'notas': notas,
    'enviando': enviando,
    'guardado_en': guardadoEn.toIso8601String(),
  };

  factory BorradorPedido.fromJson(Map<String, dynamic> j) {
    final t = (j['tupper'] as Map?) ?? const {};
    return BorradorPedido(
      usuarioId: j['usuario_id']?.toString() ?? '',
      tipo: j['tipo']?.toString() ?? 'mesa',
      mesaNumero: (j['mesa_numero'] as num?)?.toInt(),
      mesaId: j['mesa_id']?.toString(),
      carrito: [
        for (final l in (j['carrito'] as List? ?? const []))
          lineaDeJsonLocal(l as Map<String, dynamic>),
      ],
      descEmpleado: j['desc_empleado'] == true,
      propina: (j['propina'] as num?)?.toDouble() ?? 0,
      tupper: (
        grande: (t['grande'] as num?)?.toInt() ?? 0,
        precioGrande: (t['precio_grande'] as num?)?.toDouble() ?? 0,
        mediano: (t['mediano'] as num?)?.toInt() ?? 0,
        precioMediano: (t['precio_mediano'] as num?)?.toDouble() ?? 0,
      ),
      nombre: j['nombre']?.toString() ?? '',
      telefono: j['telefono']?.toString() ?? '',
      direccion: j['direccion']?.toString() ?? '',
      referencia: j['referencia']?.toString() ?? '',
      envio: j['envio']?.toString() ?? '',
      notas: j['notas']?.toString() ?? '',
      enviando: j['enviando'] == true,
      guardadoEn:
          DateTime.tryParse(j['guardado_en']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

const _prefijoClave = 'borrador_pedido_';
// Un pedido a medias no debe quedarse guardado mucho tiempo.
const _vigencia = Duration(minutes: 30);

String _clave(String usuarioId) => '$_prefijoClave$usuarioId';

BorradorPedido? _borrador;

BorradorPedido? get borradorPedido => _borrador;

// Guarda el borrador en memoria y en el dispositivo (o lo borra de ambos si es
// null).
set borradorPedido(BorradorPedido? valor) {
  final anterior = _borrador;
  _borrador = valor;
  _avisarCambio();
  if (valor != null) {
    unawaited(_escribir(valor));
  } else if (anterior != null) {
    unawaited(_borrarDelDispositivo(anterior.usuarioId));
  }
}

// Sube cada vez que el borrador aparece o desaparece (el menú lo escucha para
// mostrar el aviso de "pedido sin confirmar").
final ValueNotifier<int> borradorRevision = ValueNotifier<int>(0);

// El borrador se guarda al destruirse una pantalla: no se puede avisar a otras
// en ese mismo instante, por eso se espera al fin del cuadro.
void _avisarCambio() {
  try {
    final b = SchedulerBinding.instance;
    b.addPostFrameCallback((_) => borradorRevision.value++);
    b.ensureVisualUpdate();
  } catch (_) {
    borradorRevision.value++;
  }
}

Future<void> _escribir(BorradorPedido b) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(_clave(b.usuarioId), jsonEncode(b.toJson()));
  } catch (e) {
    debugPrint('[borrador] No se pudo guardar en el dispositivo: $e');
  }
}

Future<void> _borrarDelDispositivo(String usuarioId) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.remove(_clave(usuarioId));
  } catch (e) {
    debugPrint('[borrador] No se pudo borrar del dispositivo: $e');
  }
}

// Borrador del usuario indicado, si lo hay.
BorradorPedido? borradorDe(String usuarioId) =>
    _borrador?.usuarioId == usuarioId ? _borrador : null;

// Guarda el borrador en el dispositivo y espera a que termine (para usarlo justo
// antes de enviar el pedido).
Future<void> guardarBorradorYEsperar(BorradorPedido b) async {
  _borrador = b;
  await _escribir(b);
}

// El pedido ya se envió (o se cerró): se borra de inmediato de la memoria y del
// dispositivo, y se espera a que el borrado termine.
Future<void> descartarBorradorYEsperar() async {
  final anterior = _borrador;
  _borrador = null;
  _avisarCambio();
  if (anterior != null) await _borrarDelDispositivo(anterior.usuarioId);
}

// Igual que la anterior, sin esperar (para cerrar con la "x" o al volver atrás).
void limpiarBorradorPedido() => borradorPedido = null;

// Al cerrar sesión: no queda ninguna copia, ni en memoria ni en el dispositivo.
Future<void> borrarTodoBorradorDe(String? usuarioId) async {
  _borrador = null;
  _avisarCambio();
  if (usuarioId != null) await _borrarDelDispositivo(usuarioId);
}

// Al iniciar sesión: recupera el borrador que ese usuario dejó en el
// dispositivo. Lo descarta si tiene más de 30 minutos o si se estaba enviando
// cuando la app se cerró.
Future<void> cargarBorradorGuardado(String usuarioId) async {
  try {
    final p = await SharedPreferences.getInstance();
    final texto = p.getString(_clave(usuarioId));
    if (texto == null) return;
    final b = BorradorPedido.fromJson(
      jsonDecode(texto) as Map<String, dynamic>,
    );
    final vencido = DateTime.now().difference(b.guardadoEn) > _vigencia;
    if (b.enviando ||
        vencido ||
        !b.tieneContenido ||
        b.usuarioId != usuarioId) {
      await p.remove(_clave(usuarioId));
      return;
    }
    _borrador = b;
    _avisarCambio();
  } catch (e) {
    // Dato dañado: se borra para no volver a fallar.
    debugPrint('[borrador] Borrador ilegible, se descarta: $e');
    await _borrarDelDispositivo(usuarioId);
  }
}

// Solo para pruebas: simula que la app se cerró (se pierde la memoria, pero lo
// guardado en el dispositivo sigue ahí).
@visibleForTesting
void olvidarBorradorEnMemoria() {
  _borrador = null;
  _avisarCambio();
}
