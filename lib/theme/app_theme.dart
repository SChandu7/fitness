import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Core palette
  static const Color black = Color(0xFF0A0A0A);
  static const Color blackCard = Color(0xFF111111);
  static const Color blackSurface = Color(0xFF1A1A1A);
  static const Color blackElevated = Color(0xFF222222);
  static const Color blackBorder = Color(0xFF2A2A2A);

  // Orange spectrum
  static const Color orange = Color(0xFFFF6B00);
  static const Color orangeLight = Color(0xFFFF8C3A);
  static const Color orangeDark = Color(0xFFCC5500);
  static const Color orangeGlow = Color(0x33FF6B00);
  static const Color orangeFaint = Color(0x11FF6B00);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF5F5F5);
  static const Color grey100 = Color(0xFFE8E8E8);
  static const Color grey300 = Color(0xFFAAAAAA);
  static const Color grey500 = Color(0xFF666666);
  static const Color grey700 = Color(0xFF333333);

  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color successFaint = Color(0x224CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color warningFaint = Color(0x22FFC107);
  static const Color danger = Color(0xFFEF5350);
  static const Color dangerFaint = Color(0x22EF5350);
  static const Color info = Color(0xFF42A5F5);
  static const Color infoFaint = Color(0x2242A5F5);

  // Gradients
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [orangeLight, orangeDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [blackCard, blackSurface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [black, Color(0xFF1A0800)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.orange,
        secondary: AppColors.orangeLight,
        surface: AppColors.blackCard,
        onPrimary: AppColors.white,
        onSurface: AppColors.white,
      ),
      textTheme: GoogleFonts.beVietnamProTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            color: AppColors.white,
            fontSize: 48,
            fontWeight: FontWeight.w800,
            letterSpacing: -2,
          ),
          displayMedium: TextStyle(
            color: AppColors.white,
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
          ),
          displaySmall: TextStyle(
            color: AppColors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
          headlineMedium: TextStyle(
            color: AppColors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
          headlineSmall: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            color: AppColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: AppColors.grey300,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(
            color: AppColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: TextStyle(
            color: AppColors.grey300,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: TextStyle(
            color: AppColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.blackCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.blackBorder, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.beVietnamPro(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.blackCard,
        selectedItemColor: AppColors.orange,
        unselectedItemColor: AppColors.grey500,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}

class AppTextStyles {
  static TextStyle get displayHero => GoogleFonts.beVietnamPro(
        color: AppColors.white,
        fontSize: 52,
        fontWeight: FontWeight.w800,
        letterSpacing: -2.5,
        height: 0.95,
      );

  static TextStyle get sectionLabel => GoogleFonts.beVietnamPro(
        color: AppColors.grey300,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      );

  static TextStyle get statNumber => GoogleFonts.beVietnamPro(
        color: AppColors.white,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
      );

  static TextStyle get statUnit => GoogleFonts.beVietnamPro(
        color: AppColors.grey300,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get cardTitle => GoogleFonts.beVietnamPro(
        color: AppColors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get cardSubtitle => GoogleFonts.beVietnamPro(
        color: AppColors.grey300,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get orangeAccent => GoogleFonts.beVietnamPro(
        color: AppColors.orange,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get buttonText => GoogleFonts.beVietnamPro(
        color: AppColors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      );

  static TextStyle get labelLarge => GoogleFonts.beVietnamPro(
        color: AppColors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );
}
