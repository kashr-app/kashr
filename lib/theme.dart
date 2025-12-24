import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

class ThemeBuilder {
  ThemeData lightMode() {
    return buildTheme(
      ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF28CA97),
      ),
    );
  }

  ThemeData darkMode() {
    final t = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF28CA97),
    );

    return buildTheme(
      t.copyWith(
        colorScheme: t.colorScheme.copyWith(
          // onSurface: const Color(0xFFFFFFFF),
        ),
      ),
    );
  }

  ThemeData buildTheme(ThemeData themeData) {
    final customColors = CustomColors.fromTheme(themeData);
    return themeData.copyWith(extensions: [customColors]);
  }
}

class CustomColors extends ThemeExtension<CustomColors> {
  final Color amountNegative;
  final Color amountPositive;
  final Color amountNeutral;

  final Color warning;
  final Color info;

  const CustomColors({
    required this.amountNegative,
    required this.amountPositive,
    required this.amountNeutral,
    required this.warning,
    required this.info,
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
          warning: Colors.orange[200]!,
          info: Colors.blue[300]!,
        );
      case Brightness.light:
        return CustomColors(
          amountNegative: colorScheme.error,
          amountPositive: colorScheme.primary,
          amountNeutral: colorScheme.onSurface,
          warning: Colors.orange,
          info: Colors.blue[500]!,
        );
    }
  }

  @override
  CustomColors copyWith({
    Color? amountNegative,
    Color? amountPositive,
    Color? amountNeutral,
    Color? warning,
    Color? info,
  }) {
    return CustomColors(
      amountNegative: amountNegative ?? this.amountNegative,
      amountPositive: amountPositive ?? this.amountPositive,
      amountNeutral: amountNeutral ?? this.amountNeutral,
      warning: warning ?? this.warning,
      info: info ?? this.info,
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
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
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
