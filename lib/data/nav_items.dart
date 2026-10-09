import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/app_role.dart';
import '../models/nav_item.dart';

// Ítems del sidebar con permisos RBAC requeridos
const navItems = [
  NavItem(
    clave: 'inicio',
    label: 'Inicio',
    icono: LucideIcons.house,
    rolesPermitidos: {
      AppRole.administrador,
      AppRole.mesero,
      AppRole.cajero,
      AppRole.trabajador,
    },
  ),
  NavItem(
    clave: 'mesas',
    label: 'Mesas',
    icono: LucideIcons.layoutGrid,
    rolesPermitidos: {
      AppRole.administrador,
      AppRole.mesero,
      AppRole.cajero,
    },
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
    permisoRequerido: 'LEER.CARTA',
  ),
  NavItem(
    clave: 'cocina',
    label: 'Cocina',
    icono: LucideIcons.chefHat,
    rolesPermitidos: {AppRole.administrador, AppRole.trabajador},
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
        permisoRequerido: 'LEER.MOVIMIENTO',
      ),
    ],
  ),
  NavItem(
    clave: 'finanzas',
    label: 'Finanzas',
    icono: LucideIcons.landmark,
    rolesPermitidos: {AppRole.administrador},
    permisoRequerido: 'LEER.MOVIMIENTO',
  ),
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
    permisoRequerido: 'LEER.SEDE',
  ),
];
