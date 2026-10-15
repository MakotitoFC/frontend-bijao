import 'package:flutter/material.dart';

import '../models/carta_item.dart';
import '../services/api_client.dart';

// Foto de un plato: la que está guardada en el servidor (`url_imagen`) o, si no
// hay, un ícono. Rellena el espacio que le da quien la usa.
class ImagenPlato extends StatelessWidget {
  final CartaItem item;
  final double tamanoIcono;

  const ImagenPlato({super.key, required this.item, this.tamanoIcono = 30});

  // El servidor devuelve la ruta relativa (/uploads/...): se completa con su
  // dirección.
  static String? direccionDe(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    final base = ApiClient.instance.baseUrl;
    return url.startsWith('/') ? '$base$url' : '$base/$url';
  }

  Widget _marcador() => Center(
    child: Icon(
      Icons.restaurant_outlined,
      size: tamanoIcono,
      color: Colors.grey.shade400,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final direccion = direccionDe(item.urlImagen);
    return ColoredBox(
      color: const Color(0xFFF1F3F0),
      child: item.imagenBytes != null
          ? Image.memory(
              item.imagenBytes!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          : (direccion != null
                ? Image.network(
                    direccion,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, _, _) => _marcador(),
                    loadingBuilder: (context, child, progreso) =>
                        progreso == null ? child : _marcador(),
                  )
                : _marcador()),
    );
  }
}
