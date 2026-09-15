import '../models/app_role.dart';
import '../models/mock_user.dart';

// Semilla inicial (ver usuarios_store.dart para el estado mutable en memoria).
// TODO: reemplazar por la autenticación real contra `usuario` (servidor local / Supabase).
const usuariosIniciales = [
  MockUser(
    id: 'user1',
    nombre: 'Ana Torres',
    email: 'admin@bijao.com',
    password: 'admin123',
    rol: AppRole.administrador,
  ),
  MockUser(
    id: 'user2',
    nombre: 'Luis Ramírez',
    email: 'mesero@bijao.com',
    password: 'mesero123',
    rol: AppRole.mesero,
    sedeId: '1',
  ),
  MockUser(
    id: 'user3',
    nombre: 'Carla Quispe',
    email: 'cocina@bijao.com',
    password: 'cocina123',
    rol: AppRole.cocina,
    sedeId: '1',
  ),
];
