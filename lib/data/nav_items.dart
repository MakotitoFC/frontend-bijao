import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/app_role.dart';
import '../models/nav_item.dart';

// Ítems del sidebar con permisos RBAC requeridos
const navItems = [
  NavItem(
    clave: 'inicio',
    label: 'Inicio',
    icono: LucideIcons.house,
    // El cajero entra directo a sus comandas: no tiene Inicio.
    rolesPermitidos: {
      AppRole.administrador,
      AppRole.mesero,
      AppRole.trabajador,
    },
  ),
  NavItem(
    clave: 'mesas',
    label: 'Mesas',
    icono: LucideIcons.layoutGrid,
    // Solo administración: el cajero no libera ni mueve mesas.
    rolesPermitidos: {AppRole.administrador},
    // El mozo elige la mesa dentro de "Nuevo pedido": no necesita esta vista,
    // aunque su rol tenga el permiso LEER.MESA.
    rolesOcultos: {AppRole.mesero, AppRole.cajero},
    permisoRequerido: 'LEER.MESA',
  ),
  NavItem(
    clave: 'pedidos',
    label: 'Pedidos',
    icono: LucideIcons.clipboardList,
    rolesPermitidos: {AppRole.administrador, AppRole.mesero, AppRole.cajero},
    permisoRequerido: 'LEER.PEDIDO',
  ),
  NavItem(
    clave: 'productos',
    label: 'Carta',
    icono: LucideIcons.utensilsCrossed,
    rolesPermitidos: {AppRole.administrador, AppRole.mesero},
    // Aunque el cajero tenga el permiso de leer la carta, no usa esta vista.
    rolesOcultos: {AppRole.cajero},
    permisoRequerido: 'LEER.CARTA',
  ),
  NavItem(
    clave: 'cocina',
    label: 'Cocina',
    icono: LucideIcons.chefHat,
    rolesPermitidos: {AppRole.administrador, AppRole.trabajador},
    // Cocina no es del mozo ni del cajero, aunque tengan permiso para leer
    // pedidos.
    rolesOcultos: {AppRole.mesero, AppRole.cajero},
    permisoRequerido: 'LEER.PEDIDO',
  ),
  NavItem(
    clave: 'ventas',
    label: 'Ventas',
    icono: LucideIcons.wallet,
    rolesPermitidos: {AppRole.administrador, AppRole.cajero},
    hijos: [
      NavItem(
        clave: 'historial_pedidos',
        label: 'Historial de pedidos',
        icono: LucideIcons.receipt,
        rolesPermitidos: {AppRole.administrador, AppRole.cajero},
        permisoRequerido: 'LEER.PEDIDOS',
      ),
      NavItem(
        clave: 'caja',
        label: 'Caja',
        icono: LucideIcons.wallet,
        rolesPermitidos: {AppRole.administrador, AppRole.cajero},
        permisoRequerido: 'LEER.PAGO',
      ),
      NavItem(
        clave: 'reportes',
        label: 'Reportes',
        icono: LucideIcons.newspaper,
        rolesPermitidos: {AppRole.administrador},
        // El cajero tiene LEER.MOVIMIENTO por la caja, pero no ve Reportes.
        rolesOcultos: {AppRole.cajero},
        permisoRequerido: 'LEER.MOVIMIENTO',
      ),
    ],
  ),
  // Vista "Finanzas" oculta por ahora: sin ítem en el menú no se puede abrir
  // (la pantalla sigue en `home_screen.dart` para activarla de nuevo).
  // NavItem(
  //   clave: 'finanzas',
  //   label: 'Finanzas',
  //   icono: LucideIcons.landmark,
  //   rolesPermitidos: {AppRole.administrador},
  //   permisoRequerido: 'LEER.MOVIMIENTO',
  // ),
  NavItem(
    clave: 'inventario',
    label: 'Inventario',
    icono: LucideIcons.boxes,
    rolesPermitidos: {AppRole.administrador},
    permisoRequerido: 'VER.VISTA_INVENTARIO',
  ),
  NavItem(
    clave: 'configuracion',
    label: 'Configuración',
    icono: LucideIcons.settings,
    rolesPermitidos: {AppRole.administrador},
    // El mozo y el cajero no entran a Configuración, aunque su rol traiga el
    // permiso de leer la sede.
    rolesOcultos: {AppRole.mesero, AppRole.cajero},
    permisoRequerido: 'LEER.SEDE',
  ),
];
