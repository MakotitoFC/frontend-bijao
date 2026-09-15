import 'package:flutter/material.dart';

import '../data/promociones_store.dart';
import '../models/promocion.dart';
import 'promocion_form_screen.dart';

// CRUD de promociones (solo Administrador).
class PromocionesScreen extends StatefulWidget {
  const PromocionesScreen({super.key});

  @override
  State<PromocionesScreen> createState() => _PromocionesScreenState();
}

class _PromocionesScreenState extends State<PromocionesScreen> {
  Future<void> _crear() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PromocionFormScreen()),
    );
    if (creado == true) setState(() {});
  }

  Future<void> _editar(Promocion promocion) async {
    final editado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PromocionFormScreen(promocion: promocion),
      ),
    );
    if (editado == true) setState(() {});
  }

  Future<void> _eliminar(Promocion promocion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar promoción'),
        content: Text('¿Eliminar "${promocion.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      setState(() => eliminarPromocion(promocion.id));
    }
  }

  String _formatearFecha(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promociones')),
      floatingActionButton: FloatingActionButton(
        onPressed: _crear,
        child: const Icon(Icons.add),
      ),
      body: promociones.isEmpty
          ? const Center(child: Text('Aún no hay promociones'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: promociones.length,
              itemBuilder: (context, index) {
                final promocion = promociones[index];
                return Card(
                  child: ListTile(
                    title: Text(promocion.nombre),
                    subtitle: Text(
                      '${_formatearFecha(promocion.fechaInicio)} - ${_formatearFecha(promocion.fechaFin)}'
                      '${promocion.activa ? '' : ' · Inactiva'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(label: Text(promocion.etiqueta)),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editar(promocion),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _eliminar(promocion),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
