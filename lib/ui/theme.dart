import 'package:flutter/material.dart';

import '../models/settings.dart';
import 'tokens.dart';

ThemeMode themeModeOf(AppTheme theme) => switch (theme) {
      AppTheme.system => ThemeMode.system,
      AppTheme.light => ThemeMode.light,
      AppTheme.dark => ThemeMode.dark,
    };

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = _schemeFor(brightness);

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: _textThemeOf(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: kGapL, vertical: kGapXS),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusField),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
      padding: const EdgeInsets.symmetric(horizontal: kGapS, vertical: 2),
      shape: const StadiumBorder(),
    ),
    // Текстовое поле расшифровки должно выглядеть как лист бумаги,
    // а не как форма ввода: рамку и подчёркивание убираем.
    inputDecorationTheme: InputDecorationTheme(
      border: InputBorder.none,
      focusedBorder: InputBorder.none,
      enabledBorder: InputBorder.none,
      isDense: true,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearMinHeight: 6,
      borderRadius: BorderRadius.circular(kGapS),
      linearTrackColor: scheme.surfaceContainerHighest,
      color: scheme.primary,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      thumbColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? kDarkSurfaceHigh : scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: dark ? scheme.onSurface : scheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusField),
      ),
    ),
  );
}

/// Палитра.
///
/// `vibrant` вместо стандартного `tonalSpot`: тот десатурирует фуксию до
/// блёклого лилового, и фирменный розовый Handy пропадает. Поверхности
/// задаём вручную — тёмная тема не зеркало светлой, а почти чёрная,
/// как в десктопной версии.
ColorScheme _schemeFor(Brightness brightness) {
  final seeded = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
  );

  if (brightness == Brightness.dark) {
    return seeded.copyWith(
      primary: kAccentSoft,
      onPrimary: const Color(0xFF3F0521),
      surface: kDarkSurface,
      surfaceContainerLowest: kDarkSurface,
      surfaceContainerLow: kDarkSurfaceLow,
      surfaceContainer: kDarkSurfaceContainer,
      surfaceContainerHigh: kDarkSurfaceHigh,
      surfaceContainerHighest: kDarkSurfaceHigh,
      outline: kDarkOutline,
      outlineVariant: kDarkOutline,
      error: kRecording,
    );
  }

  return seeded.copyWith(
    primary: kAccentDeep,
    surface: kLightSurface,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: kLightSurfaceLow,
    surfaceContainer: kLightSurfaceContainer,
    surfaceContainerHigh: kLightSurfaceContainer,
    surfaceContainerHighest: kLightOutline,
    outline: kLightOutline,
    outlineVariant: kLightOutline,
  );
}

/// Заголовки чуть плотнее стандартных — так они читаются как заголовки,
/// а не как увеличенный текст.
TextTheme _textThemeOf(TextTheme base) => base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(letterSpacing: -0.5),
      headlineMedium: base.headlineMedium?.copyWith(letterSpacing: -0.4),
      headlineSmall: base.headlineSmall?.copyWith(letterSpacing: -0.3),
      titleLarge: base.titleLarge?.copyWith(letterSpacing: -0.2),
      titleMedium: base.titleMedium?.copyWith(letterSpacing: -0.1),
    );
