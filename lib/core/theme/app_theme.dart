import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Configuración global del tema de la aplicación Join.
/// Usar en MaterialApp.router(theme: AppTheme.light)
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryOrange,
        brightness: Brightness.light,
        primary: AppColors.primaryOrange,
        secondary: AppColors.navyBlue,
        surface: AppColors.cardWhite,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.navyBlue,
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: AppColors.navyBlue,
        displayColor: AppColors.navyBlue,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.navyBlue),
        titleTextStyle: TextStyle(
          color: AppColors.navyBlue,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      ),
      scaffoldBackgroundColor: AppColors.cardWhite,
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        labelStyle: const TextStyle(color: AppColors.navyBlue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppColors.primaryOrange, width: 2),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryOrange,
        brightness: Brightness.dark,
        primary: AppColors.primaryOrange,
        secondary: const Color(0xFF6366F1), // Indigo/Lavender
        surface: const Color(0xFF161920), // Slate-blue oscuro premium
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: const Color(0xFFF8FAFC), // Slate 50
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: const Color(0xFFE2E8F0), // Slate 200
        displayColor: const Color(0xFFF8FAFC), // Slate 50
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF161920),
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0D14), // Midnight Black background
      cardTheme: const CardThemeData(
        color: Color(0xFF161920),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E222B), // Un poco más claro que la surface
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)), // Slate 400
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2E323F)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2E323F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppColors.primaryOrange, width: 2),
        ),
      ),
    );
  }
}
