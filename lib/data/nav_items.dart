import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/app_role.dart';
import '../models/nav_item.dart';

// Ítems del sidebar (mapeo directo del dashboard anterior, según lo
// acordado: Pedidos=Mesas y Pedidos, Productos=Carta, Pagos=Historial de
// pedidos y Cajas, Informes=Reportes, Configuración=ajustes del negocio).
// Inventario/Compras/Promociones no tienen ítem (ocultos por ahora, su
// código sigue intacto en el proyecto).
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
    clave: 'pedidos',
    label: 'Pedidos',
    icono: LucideIcons.clipboardList,
    rolesPermitidos: {AppRole.administrador, AppRole.mesero, AppRole.cajero},
  ),
  NavItem(
    clave: 'productos',
    label: 'Productos',
    icono: LucideIcons.store,
    rolesPermitidos: {AppRole.administrador, AppRole.mesero},
  ),
  NavItem(
    clave: 'cocina',
    label: 'Cocina',
    icono: LucideIcons.chefHat,
    rolesPermitidos: {AppRole.administrador, AppRole.trabajador},
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
      ),
      NavItem(
        clave: 'caja',
        label: 'Caja',
        icono: LucideIcons.wallet,
        rolesPermitidos: {AppRole.administrador, AppRole.cajero},
      ),
      NavItem(
        clave: 'reportes',
        label: 'Reportes',
        icono: LucideIcons.newspaper,
        rolesPermitidos: {AppRole.administrador},
      ),
    ],
  ),
  NavItem(
    clave: 'finanzas',
    label: 'Finanzas',
    icono: LucideIcons.landmark,
    rolesPermitidos: {AppRole.administrador},
  ),
  NavItem(
    clave: 'inventario',
    label: 'Inventario',
    icono: LucideIcons.boxes,
    rolesPermitidos: {AppRole.administrador},
  ),
  NavItem(
    clave: 'configuracion',
    label: 'Configuración',
    icono: LucideIcons.settings,
    rolesPermitidos: {AppRole.administrador},
  ),
];
