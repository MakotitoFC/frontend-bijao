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

  // Naranja del "Plato del día" (estrella de la card y botones asociados).
  static const Color platoDelDia = Color(0xFFF07F13);

  static const Color success = Color(0xFF2E7D4F);
  static const Color error = Color(0xFFC24444);
  static const Color warning = Color(0xFFC98A3E);
  static const Color info = Color(0xFF3D6B8C);

  // Paleta de la pantalla Mesas (estado por color, ver mesa_card.dart).
  static const Color mesaOcupada = Color(0xFF4A82E0);

  // Verde neón para estados activos; `verdeTexto` es el verde oscuro del
  // texto sobre esos fondos claros.
  static const Color neonVerde = Color(0xFF19F5A1);
  static const Color verdeTexto = Color(0xFF078A5F);
}

// Radios de esquina estándar (nivel "moderado": consistente pero no pill-shape).
class AppRadii {
  static const double input = 14;
  // Botones: un poco más redondeados que los tags (no pastilla).
  static const double button = 12;
  static const double tag = 8;
  static const double card = 16;
  static const double sheet = 24;
}

// Alto común de tags y botones.
class AppSizes {
  static const double control = 36;
  // Alto de los botones: mayor que el de tags y selects.
  static const double boton = 44;
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
  // Todos los botones: mismo alto entre sí (mayor que los tags) y esquinas algo
  // más redondeadas que las de los tags.
  static ButtonStyle _estiloBoton() => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, AppSizes.boton)),
    maximumSize: const WidgetStatePropertyAll(
      Size(double.infinity, AppSizes.boton),
    ),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );

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
        style: _estiloBoton().copyWith(
          backgroundColor: const WidgetStatePropertyAll(AppColors.primaryGreen),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _estiloBoton()),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _estiloBoton()),
      textButtonTheme: TextButtonThemeData(style: _estiloBoton()),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
    );
  }
}
