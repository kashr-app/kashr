import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

ThemeData lightMode = buildTheme(
  ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: Colors.green,
  ),
);

ThemeData darkMode = buildTheme(
  ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.green,
  ),
);

ThemeData buildTheme(ThemeData themeData) {
  final customColors = CustomColors.fromTheme(themeData);
  return themeData.copyWith(extensions: [customColors]);
}

class CustomColors extends ThemeExtension<CustomColors> {
  final Color amountNegative;
  final Color amountPositive;
  final Color amountNeutral;

  const CustomColors({
    required this.amountNegative,
    required this.amountPositive,
    required this.amountNeutral,
  });

  // Create CustomColors from the current ColorScheme
  static CustomColors fromTheme(ThemeData themeData) {
    final colorScheme = themeData.colorScheme;
    switch (themeData.brightness) {
      case Brightness.dark:
        return CustomColors(
          amountNegative: colorScheme.error,
          amountPositive: colorScheme.primary,
          amountNeutral: colorScheme.onSurface,
        );
      case Brightness.light:
        return CustomColors(
          amountNegative: colorScheme.error,
          amountPositive: colorScheme.primary,
          amountNeutral: colorScheme.onSurface,
        );
    }
  }

  @override
  CustomColors copyWith({
    Color? amountNegative,
    Color? amountPositive,
    Color? amountNeutral,
  }) {
    return CustomColors(
      amountNegative: amountNegative ?? this.amountNegative,
      amountPositive: amountPositive ?? this.amountPositive,
      amountNeutral: amountNeutral ?? this.amountNeutral,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      amountNegative: Color.lerp(amountNegative, other.amountNegative, t)!,
      amountPositive: Color.lerp(amountPositive, other.amountPositive, t)!,
      amountNeutral: Color.lerp(amountNeutral, other.amountNeutral, t)!,
    );
  }
}

extension ThemeDataExtensions on ThemeData {
  Color decimalColor(Decimal? value) {
    // Access the custom theme colors from the Theme extension
    final customColors = extension<CustomColors>();

    final v = value ?? Decimal.zero;

    // Choose the color based on the value
    return v < Decimal.zero
        ? customColors?.amountNegative ?? Colors.red
        : v > Decimal.zero
        ? customColors?.amountPositive ?? Colors.green
        : customColors?.amountNeutral ?? Colors.grey;
  }
}
