import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Paleta propia de Bijao: verde selva (la hoja de bijao) + acento tierra/dorado.
class AppColors {
  static const Color primaryGreen = Color(0xFF1B5E3F);
  static const Color primaryGreenDark = Color(0xFF12432D);
  static const Color accentGold = Color(0xFFC98A3E);
  static const Color background = Color(0xFFF7F5F0);

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
  static const Color loginInputAccent = Color(0xFF045125);

  // Paleta de la pantalla Mesas (estado por color, ver mesa_card.dart).
  static const Color mesaOcupada = Color(0xFF4A82E0);
  static const Color mesaLibre = Color(0xFF9CA3AF);
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
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      brightness: Brightness.light,
    ).copyWith(secondary: AppColors.accentGold);

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
