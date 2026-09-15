import 'package:hugeicons/hugeicons.dart';

import '../models/app_role.dart';
import '../models/nav_item.dart';

// Ítems del sidebar (mapeo directo del dashboard anterior, según lo
// acordado: Pedidos=Mesas y Pedidos, Productos=Carta, Pagos/Caja=el módulo
// dividido en dos, Informes=Reportes, Configuración=Usuarios).
// Inventario/Compras/Promociones no tienen ítem (ocultos por ahora, su
// código sigue intacto en el proyecto).
const navItems = [
  NavItem(
    clave: 'inicio',
    label: 'Inicio',
    icono: HugeIcons.strokeRoundedHome01,
    rolesPermitidos: {AppRole.administrador, AppRole.mesero, AppRole.cocina},
  ),
  NavItem(
    clave: 'pedidos',
    label: 'Pedidos',
    icono: HugeIcons.strokeRoundedClipboard,
    rolesPermitidos: {AppRole.administrador, AppRole.mesero},
  ),
  NavItem(
    clave: 'productos',
    label: 'Productos',
    icono: HugeIcons.strokeRoundedStore01,
    rolesPermitidos: {AppRole.administrador, AppRole.mesero},
  ),
  NavItem(
    clave: 'cocina',
    label: 'Cocina',
    icono: HugeIcons.strokeRoundedChefHat,
    rolesPermitidos: {AppRole.administrador, AppRole.cocina},
  ),
  NavItem(
    clave: 'pagos',
    label: 'Pagos',
    icono: HugeIcons.strokeRoundedWallet01,
    rolesPermitidos: {AppRole.administrador},
  ),
  NavItem(
    clave: 'caja',
    label: 'Caja',
    icono: HugeIcons.strokeRoundedCoins01,
    rolesPermitidos: {AppRole.administrador},
  ),
  NavItem(
    clave: 'informes',
    label: 'Informes',
    icono: HugeIcons.strokeRoundedNews,
    rolesPermitidos: {AppRole.administrador},
  ),
  NavItem(
    clave: 'configuracion',
    label: 'Configuración',
    icono: HugeIcons.strokeRoundedSettings01,
    rolesPermitidos: {AppRole.administrador},
  ),
];
