import 'package:flutter/material.dart';

/// アイデアシート指定の「灰・白」を基調としたアプリケーションテーマ定義
class AppTheme {
  AppTheme._();

  static const Color primaryGrey = Color(0xFF616161);
  static const Color darkGrey = Color(0xFF333333);
  static const Color mediumGrey = Color(0xFF8E8E93);
  static const Color lightGrey = Color(0xFFE5E5EA);
  static const Color surfaceGrey = Color(0xFFF5F5F7);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color accentPinRed = Color(0xFFD9383A);

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: darkGrey,
      onPrimary: pureWhite,
      secondary: primaryGrey,
      onSecondary: pureWhite,
      surface: pureWhite,
      onSurface: darkGrey,
      surfaceContainerHighest: surfaceGrey,
      outline: mediumGrey,
      outlineVariant: lightGrey,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pureWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: pureWhite,
        foregroundColor: darkGrey,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: pureWhite,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightGrey),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceGrey,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: darkGrey, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: lightGrey, thickness: 1),
    );
  }
}
