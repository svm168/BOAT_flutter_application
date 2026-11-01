import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.dmSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.sand,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.moss,
        primary: AppColors.moss,
        secondary: AppColors.leaf,
        surface: AppColors.surface,
        error: AppColors.clay,
        brightness: Brightness.light,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.fraunces(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.moss,
        ),
        displayMedium: GoogleFonts.fraunces(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: AppColors.moss,
        ),
        displaySmall: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.moss,
        ),
        headlineMedium: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.moss,
        ),
        titleLarge: GoogleFonts.fraunces(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16,
          color: AppColors.ink,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          color: AppColors.ink,
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12,
          color: AppColors.inkLight,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.sand,
        foregroundColor: AppColors.moss,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.moss,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.leaf, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.clay),
        ),
        labelStyle: GoogleFonts.dmSans(color: AppColors.inkLight),
        hintStyle: GoogleFonts.dmSans(color: AppColors.inkMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.moss,
          foregroundColor: AppColors.sand,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.moss,
          side: const BorderSide(color: AppColors.moss, width: 1.5),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.leaf,
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.moss,
        unselectedItemColor: AppColors.inkMuted,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
