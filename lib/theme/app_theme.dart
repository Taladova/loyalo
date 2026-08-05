import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Charte graphique Loyalo, reprise de la maquette officielle du projet.
class AppColors {
  // Couleurs de marque
  static const teal = Color(0xFF2DD4BF);
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFF7C3AED);

  // Couleurs secondaires
  static const navy = Color(0xFF0F172A); // bleu nuit — texte principal / fonds sombres
  static const slate = Color(0xFF334155); // gris foncé
  static const gray = Color(0xFF64748B); // gris moyen
  static const lightGray = Color(0xFFCBD5E1); // gris clair
  static const lightBg = Color(0xFFF8FAFC); // fond clair
  static const white = Color(0xFFFFFFFF);

  static const lavender = Color(0xFFEDE9FE); // teinte claire du violet, pour badges/fonds
  static const orange = Color(0xFFF6A623); // accent étincelle
  static const success = Color(0xFF2FBF71);
  static const danger = Color(0xFFE0554F);

  static const textDark = navy;
  static const textGray = gray;
  static const border = lightGray;
  static const cloud = lightBg;

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, blue, purple],
  );
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.purple,
        primary: AppColors.purple,
        secondary: AppColors.teal,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.cloud,
      fontFamily: GoogleFonts.poppins().fontFamily,
    );

    return base.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.purple,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
        ),
      ),
    );
  }
}
