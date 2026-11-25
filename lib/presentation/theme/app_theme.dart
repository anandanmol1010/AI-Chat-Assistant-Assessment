import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  const AppTheme._();

  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF186358),
      brightness: brightness,
      primary: dark ? const Color(0xFF9CD3C4) : const Color(0xFF1D6255),
      onPrimary: dark ? const Color(0xFF10251F) : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF142822)
          : const Color(0xFFE5EEE8),
      onPrimaryContainer: dark
          ? const Color(0xFFDCECE4)
          : const Color(0xFF1F4539),
      surface: dark ? Colors.black : const Color(0xFFFAF9F6),
      onSurface: dark ? const Color(0xFFECEDE9) : const Color(0xFF202420),
      onSurfaceVariant: dark
          ? const Color(0xFFA9B0AA)
          : const Color(0xFF58615B),
      surfaceContainerLow: dark ? const Color(0xFF0D100E) : Colors.white,
      surfaceContainer: dark
          ? const Color(0xFF131815)
          : const Color(0xFFEFEFE9),
      surfaceContainerHigh: dark
          ? const Color(0xFF1C221E)
          : const Color(0xFFE8EAE3),
      outline: dark ? const Color(0xFF657269) : const Color(0xFF6E796F),
      outlineVariant: dark ? const Color(0xFF262E29) : const Color(0xFFDDDCD4),
      errorContainer: dark ? const Color(0xFF321A24) : const Color(0xFFFFE9EC),
      onErrorContainer: dark
          ? const Color(0xFFFFCBD1)
          : const Color(0xFF791E32),
    );
    final base = ThemeData(colorScheme: colors, useMaterial3: true);
    final text = base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 29,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -.55,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.42),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    OutlineInputBorder fieldBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarThemeData(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: brightness,
          systemNavigationBarColor: colors.surface,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: fieldBorder(colors.outlineVariant),
        enabledBorder: fieldBorder(colors.outlineVariant),
        disabledBorder: fieldBorder(colors.outlineVariant),
        focusedBorder: fieldBorder(colors.primary, width: 1.5),
        hintStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        prefixIconColor: colors.onSurfaceVariant,
        suffixIconColor: colors.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHigh,
      ),
    );
  }
}
