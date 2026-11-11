// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dark_colors.dart';

/// Holds the current theme mode. Call ThemeController.toggle(context)
/// from any screen to switch between light and dark.
class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> mode =
  ValueNotifier<ThemeMode>(ThemeMode.light);

  static void toggle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    mode.value = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}

class AppTheme {
  AppTheme._();

  static const ColorScheme _lightScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.textOnPrimary,
    primaryContainer: AppColors.primaryLight,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.primaryDark,
    onSecondary: AppColors.textOnPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceSecondary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.border,
    error: AppColors.error,
    onError: AppColors.textOnPrimary,
  );

  static const ColorScheme _darkScheme = ColorScheme.dark(
    primary: AppDarkColors.primary,
    onPrimary: AppDarkColors.textOnPrimary,
    primaryContainer: AppDarkColors.primaryLight,
    onPrimaryContainer: AppDarkColors.primary,
    secondary: AppDarkColors.primaryDark,
    onSecondary: AppDarkColors.textOnPrimary,
    surface: AppDarkColors.surface,
    onSurface: AppDarkColors.textPrimary,
    surfaceContainerHighest: AppDarkColors.surfaceSecondary,
    onSurfaceVariant: AppDarkColors.textSecondary,
    outline: AppDarkColors.border,
    error: AppDarkColors.error,
    onError: AppDarkColors.textOnPrimary,
  );

  static ThemeData get light => _build(
    scheme: _lightScheme,
    background: AppColors.background,
    hint: AppColors.textHint,
    focused: AppColors.borderFocused,
  );

  static ThemeData get dark => _build(
    scheme: _darkScheme,
    background: AppDarkColors.background,
    hint: AppDarkColors.textHint,
    focused: AppDarkColors.borderFocused,
  );

  static ThemeData _build({
    required ColorScheme scheme,
    required Color background,
    required Color hint,
    required Color focused,
  }) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: TextStyle(color: hint),
        enabledBorder: border(scheme.outline),
        focusedBorder: border(focused),
        border: border(scheme.outline),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}