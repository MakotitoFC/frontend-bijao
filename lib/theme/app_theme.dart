import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Paleta de Bijao: verde menta #0CAB7B sobre navbar oscuro #1F1F1F, header
// #FFFFFC y fondo de vistas #F5F6FF.
class AppColors {
  static const Color primaryGreen = Color(0xFF0CAB7B);
  static const Color primaryGreenDark = Color(0xFF098A63);
  static const Color accentGold = Color(0xFFC98A3E);
  static const Color background = Color(0xFFF5F6FF);
  static const Color navbar = Color(0xFF1F1F1F);
  static const Color header = Color(0xFFFFFFFC);

  static const Color success = Color(0xFF2E7D4F);
  static const Color error = Color(0xFFC24444);
  static const Color warning = Color(0xFFC98A3E);
  static const Color info = Color(0xFF3D6B8C);

  // Paleta específica del Login (pantalla "Sistema POS / Control total").
  static const Color loginDarkPanel = Color(
    0xFF14261F,
  ); // aproximado: no especificado, tomado de la referencia
  static const Color loginAccentGreen = Color(0xFF41FD7F);
  static const Color loginMutedGreen = Color(0xFF8DBA91);
  static const Color loginPanelBg = Color(0xFFF2F5F3);
  static const Color loginButtonDark = Color(0xFF1B3A2E);
  static const Color loginInputAccent = primaryGreen;

  // Paleta de la pantalla Mesas (estado por color, ver mesa_card.dart).
  static const Color mesaOcupada = Color(0xFF4A82E0);
  static const Color mesaLibre = Color(0xFF9CA3AF);

  // Neón: verde para lo libre/activo y rojo para lo ocupado. `verdeTexto` es
  // el verde oscuro que se usa para el texto sobre fondos neón claros.
  static const Color neonVerde = Color(0xFF19F5A1);
  static const Color neonRojo = Color(0xFFFF3B5C);
  static const Color verdeTexto = Color(0xFF078A5F);
  static const Color rojoTexto = Color(0xFFC21A3A);
}

// Etiquetas "medio neón": fondo translúcido, trazo neón y, si están activas,
// un brillo suave alrededor. Verde por defecto; `color` permite el rojo de
// "Ocupada" (ver mesas_screen.dart) con el mismo estilo.
class Neon {
  static BoxDecoration etiqueta({
    bool activa = false,
    double radio = 20,
    Color color = AppColors.neonVerde,
  }) => BoxDecoration(
    color: color.withValues(alpha: activa ? 0.28 : 0.10),
    borderRadius: BorderRadius.circular(radio),
    border: Border.all(color: color.withValues(alpha: activa ? 1 : 0.5)),
    boxShadow: activa
        ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10)]
        : null,
  );
}

// Radios de esquina estándar (nivel "moderado": consistente pero no pill-shape).
class AppRadii {
  static const double input = 14;
  static const double button = 14;
  static const double card = 16;
  static const double sheet = 24;
}

// Punto de quiebre único para todo el diseño responsive: por debajo de este
// ancho se usa el layout mobile (navbar inferior, modales como hoja
// inferior, cards en una sola columna); por encima, el layout de escritorio.
class AppBreakpoints {
  static const double mobile = 700;

  static bool esMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;
}

class AppTheme {
  static ThemeData get light {
    final baseTextTheme = GoogleFonts.poppinsTextTheme();
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primaryGreen,
          secondary: AppColors.accentGold,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: baseTextTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(
            color: AppColors.primaryGreen,
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
    );
  }
}
