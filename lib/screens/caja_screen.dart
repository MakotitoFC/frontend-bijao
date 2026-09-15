import 'package:flutter/material.dart';

import '../widgets/caja_resumen_tab.dart';

// Resumen de caja del día (ítem "Caja" del sidebar de escritorio).
class CajaScreen extends StatelessWidget {
  const CajaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: CajaResumenTab());
  }
}
