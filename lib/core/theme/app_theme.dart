import 'package:flutter/material.dart';

class AppColors {
  // Background
  static const bg = Color(0xFFFAF8F4);
  static const bgCard = Color(0xFFFFFFFF);
  static const bgElevated = Color(0xFFF5F1EB);
  static const bgWarm = Color(0xFFF0EBE1);

  // Primary
  static const primary = Color(0xFF2C3E50);
  static const primaryLight = Color(0xFF34495E);

  // Accent (골드)
  static const accent = Color(0xFFC9893A);
  static const accentLight = Color(0xFFE8C992);
  static const accentPale = Color(0xFFFDF5E9);

  // Status
  static const success = Color(0xFF27AE60);
  static const successLight = Color(0xFFE8F8EF);

  // Text
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);

  // Border
  static const border = Color(0xFFE8E2D8);

  // Group colors (12명)
  static const groupColors = [
    Color(0xFF5B9BD5),
    Color(0xFFE07B7B),
    Color(0xFF7BC67E),
    Color(0xFFD4A05A),
    Color(0xFF9B7ED4),
    Color(0xFF5BC5C5),
    Color(0xFFD47BA0),
    Color(0xFF8B9E5B),
    Color(0xFFD4845A),
    Color(0xFF5B7ED4),
    Color(0xFFB5D45B),
    Color(0xFFD45BB5),
  ];
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: 'Pretendard',
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.bgCard,
        background: AppColors.bg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        iconTheme: IconThemeData(color: AppColors.text),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
          letterSpacing: -1.0,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
          height: 1.7,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
          height: 1.6,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.textTertiary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(14),
         side: const BorderSide(color: AppColors.border),
       ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}