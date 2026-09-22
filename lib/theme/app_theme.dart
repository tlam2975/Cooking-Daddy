import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_controller.dart';

/// Design tokens for the Cooking Daddy UI. Values now come from whichever
/// ThemePreset is active in ThemeController. These are getters, not const
/// fields — any `const` widget referencing AppColors.* needs `const`
/// removed (Dart's compiler flags every site).
class AppColors {
  AppColors._();

  static const brandPink = Color(0xFFFFA4A4);

  static AppColorScheme get _current => ThemeController.instance.colors;

  static Color get primary => _current.primary;
  static Color get primaryLight => _current.primaryLight;
  static Color get background => _current.background;
  static Color get surface => _current.surface;
  static Color get border => _current.border;
  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get success => _current.success;
  static Color get successLight => _current.successLight;
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get greeting => GoogleFonts.beVietnamPro(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get sectionTitle => GoogleFonts.beVietnamPro(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get cardTitle => GoogleFonts.beVietnamPro(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get body => GoogleFonts.beVietnamPro(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle get caption => GoogleFonts.beVietnamPro(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
}

class AppRadii {
  AppRadii._();

  static BorderRadius get small => BorderRadius.circular(8);
  static BorderRadius get medium => BorderRadius.circular(12);
  static BorderRadius get large => BorderRadius.circular(14);
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get soft => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = GoogleFonts.beVietnamProTextTheme();
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.beVietnamPro().fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.primary,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: base.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.medium),
          elevation: 0,
          textStyle: AppTextStyles.cardTitle.copyWith(color: Colors.white),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.small),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: BorderSide(color: AppColors.border),
        ),
        border: OutlineInputBorder(borderRadius: AppRadii.medium),
        labelStyle: AppTextStyles.caption,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.large,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.medium),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
