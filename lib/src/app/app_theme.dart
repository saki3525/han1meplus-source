import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as modern;

import '../core/settings.dart';

ThemeData appTheme(ColorScheme? dynamicScheme, Color seedColor, {Brightness brightness = Brightness.light, bool amoled = false}) {
  var scheme = dynamicScheme ?? material3ExpressiveScheme(seedColor, brightness);
  if (amoled) {
    scheme = scheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: Colors.black,
      surfaceContainer: Colors.black,
      surfaceContainerHigh: Colors.black,
      surfaceContainerHighest: Colors.black,
    );
  }
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: amoled ? Colors.black : null,
    canvasColor: amoled ? Colors.black : null,
    sliderTheme: const SliderThemeData(year2023: false),
  );
}

final Map<(Color, Brightness), ColorScheme> _schemeCache = {};

ColorScheme material3ExpressiveScheme(Color seedColor, Brightness brightness) {
  final key = (seedColor, brightness);
  final cached = _schemeCache[key];
  if (cached != null) return cached;
  final source = modern.ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    dynamicSchemeVariant: modern.DynamicSchemeVariant.tonalSpot,
  );
  final scheme = ColorScheme(
    brightness: source.brightness,
    primary: source.primary,
    onPrimary: source.onPrimary,
    primaryContainer: source.primaryContainer,
    onPrimaryContainer: source.onPrimaryContainer,
    primaryFixed: source.primaryFixed,
    primaryFixedDim: source.primaryFixedDim,
    onPrimaryFixed: source.onPrimaryFixed,
    onPrimaryFixedVariant: source.onPrimaryFixedVariant,
    secondary: source.secondary,
    onSecondary: source.onSecondary,
    secondaryContainer: source.secondaryContainer,
    onSecondaryContainer: source.onSecondaryContainer,
    secondaryFixed: source.secondaryFixed,
    secondaryFixedDim: source.secondaryFixedDim,
    onSecondaryFixed: source.onSecondaryFixed,
    onSecondaryFixedVariant: source.onSecondaryFixedVariant,
    tertiary: source.tertiary,
    onTertiary: source.onTertiary,
    tertiaryContainer: source.tertiaryContainer,
    onTertiaryContainer: source.onTertiaryContainer,
    tertiaryFixed: source.tertiaryFixed,
    tertiaryFixedDim: source.tertiaryFixedDim,
    onTertiaryFixed: source.onTertiaryFixed,
    onTertiaryFixedVariant: source.onTertiaryFixedVariant,
    error: source.error,
    onError: source.onError,
    errorContainer: source.errorContainer,
    onErrorContainer: source.onErrorContainer,
    outline: source.outline,
    outlineVariant: source.outlineVariant,
    surface: source.surface,
    onSurface: source.onSurface,
    surfaceDim: source.surfaceDim,
    surfaceBright: source.surfaceBright,
    surfaceContainerLowest: source.surfaceContainerLowest,
    surfaceContainerLow: source.surfaceContainerLow,
    surfaceContainer: source.surfaceContainer,
    surfaceContainerHigh: source.surfaceContainerHigh,
    surfaceContainerHighest: source.surfaceContainerHighest,
    onSurfaceVariant: source.onSurfaceVariant,
    inverseSurface: source.inverseSurface,
    onInverseSurface: source.onInverseSurface,
    inversePrimary: source.inversePrimary,
    shadow: source.shadow,
    scrim: source.scrim,
    surfaceTint: source.surfaceTint,
  );
  _schemeCache[key] = scheme;
  return scheme;
}

extension AppThemeColorSeed on AppThemeColor {
  Color seedColor(String customColor) => switch (this) {
        AppThemeColor.rose => const Color(0xffb3265a),
        AppThemeColor.blue => const Color(0xff00639b),
        AppThemeColor.teal => const Color(0xff006b5f),
        AppThemeColor.amber => const Color(0xff875400),
        AppThemeColor.green => const Color(0xff386a20),
        AppThemeColor.orange => const Color(0xff9b4400),
        AppThemeColor.indigo => const Color(0xff4a5f9e),
        AppThemeColor.pink => const Color(0xff9c3c66),
        AppThemeColor.purple => const Color(0xff6d3f90),
        AppThemeColor.custom => Color(int.parse('ff$customColor', radix: 16)),
      };
}
