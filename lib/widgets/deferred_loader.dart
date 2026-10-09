import 'package:flutter/material.dart';

/// Componente que envuelve la carga bajo demanda de módulos Flutter Web diferidos (deferred loading).
/// Permite reducir el tamaño de main.dart.js descargando pantallas secundarias solo cuando el usuario las abre.
class DeferredWidget extends StatefulWidget {
  final Future<void> Function() loader;
  final Widget Function() builder;

  const DeferredWidget({
    super.key,
    required this.loader,
    required this.builder,
  });

  @override
  State<DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<DeferredWidget> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(
                      'No se pudo cargar la vista: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _loadFuture = widget.loader();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          return widget.builder();
        }
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }
}
