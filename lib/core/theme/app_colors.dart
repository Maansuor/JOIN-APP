import 'package:flutter/material.dart';

/// Paleta de colores oficial de la aplicación Join.
/// Importar este archivo en cualquier pantalla que necesite los colores.
///
/// Uso: `AppColors.primaryOrange`
class AppColors {
  AppColors._();

  // --- Naranja (Color primario) ---
  static const Color primaryOrange = Color(0xFFFD7C36);
  static const Color lightOrange = Color(0xFFFD9D2E);
  static const Color intenseOrange = Color(0xFFFD5F33);
  static const Color accentOrange = Color(0xFFFE870A);
  static const Color yellow = Color(0xFFFDBA1B);

  // --- Azul (Color secundario) ---
  static const Color navyBlue = Color(0xFF12357B);
  static const Color deepBlue = Color(0xFF041249);
  static const Color skyBlue = Color(0xFF089FD7);
  static const Color mediumBlue = Color(0xFF0E7BCF);
  static const Color turquoise = Color(0xFF02C9DC);

  // --- Neutros ---
  static const Color backgroundGrey = Color(0xFFFAFAFA);
  static const Color cardWhite = Colors.white;
  static const Color divider = Color(0xFFE0E0E0);

  // --- Semánticos ---
  static const Color success = Color(0xFF43A047);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);

  // --- Categorías de actividad ---
  static const Map<String, Color> categoryColors = {
    'Todos': primaryOrange,
    'Deportes': Color(0xFFE53935),
    'Comida': Color(0xFFFFA726),
    'Naturaleza': Color(0xFF43A047),
    'Chill': Color(0xFF5E35B1),
    'Juntas': Color(0xFFD81B60),
  };

  // --- Íconos de categoría ---
  static const Map<String, IconData> categoryIcons = {
    'Todos': Icons.category,
    'Deportes': Icons.sports_baseball,
    'Comida': Icons.restaurant,
    'Naturaleza': Icons.forest,
    'Chill': Icons.local_cafe,
    'Juntas': Icons.celebration,
  };
}
