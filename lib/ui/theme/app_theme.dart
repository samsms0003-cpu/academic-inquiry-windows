import 'package:flutter/material.dart';

/// Design Tokens مستخلصة من الوثيقة وstyles.css.
class AppColors {
  AppColors._();
  static const green = Color(0xFF006B45);
  static const greenDark = Color(0xFF004B31);
  static const greenLight = Color(0xFFE6F2EC);
  static const gold = Color(0xFFC9962C);
  static const goldLight = Color(0xFFF6EBD2);
  static const ivory = Color(0xFFFBFAF5);
  static const danger = Color(0xFFB3261E);
  static const textPrimary = Color(0xFF1B1B1B);
  static const textSecondary = Color(0xFF667085);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const info = Color(0xFF0891B2);
}

class AppTheme {
  AppTheme._();

  static ThemeData light([String font = 'Cairo']) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      secondary: AppColors.gold,
      surface: Colors.white,
      error: AppColors.danger,
      brightness: Brightness.light,
    );
    return _base(scheme, AppColors.ivory, font);
  }

  static ThemeData dark([String font = 'Cairo']) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: const Color(0xFF3FBF8F),
      secondary: AppColors.gold,
      surface: const Color(0xFF16201B),
      error: const Color(0xFFFF6B6B),
      brightness: Brightness.dark,
    );
    return _base(scheme, const Color(0xFF0F1613), font);
  }

  static ThemeData _base(ColorScheme scheme, Color bg, String font) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: font,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF13261D) : AppColors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: scheme.surface,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C2A23) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w600)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: AppColors.green.withValues(alpha: isDark ? 0.35 : 0.15),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: font, fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface)),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant)),
      ),
      listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), labelStyle: TextStyle(fontFamily: font)),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: TextStyle(fontFamily: font, color: Colors.white),
      ),
      tabBarTheme: TabBarThemeData(labelStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w700), unselectedLabelStyle: TextStyle(fontFamily: font)),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(isDark ? const Color(0xFF1E3A2E) : AppColors.greenLight),
        headingTextStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w700, fontSize: 12, color: scheme.onSurface),
        dataTextStyle: TextStyle(fontFamily: font, fontSize: 12, color: scheme.onSurface),
        columnSpacing: 14,
        horizontalMargin: 10,
        dividerThickness: 0.6,
      ),
    );
  }
}
