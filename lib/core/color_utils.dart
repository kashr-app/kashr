import 'package:flutter/material.dart';

/// Utilities for working with colors in the application.
class ColorUtils {
  ColorUtils._();

  /// Parses a color string (e.g., "#FF5733") into a [Color] object.
  ///
  /// Returns null if the string cannot be parsed.
  static Color? parseColor(String? colorString) {
    if (colorString == null) return null;

    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xff')));
    } catch (e) {
      return null;
    }
  }

  /// Returns a contrasting text color (black or white) based on the
  /// luminance of the background color.
  ///
  /// Uses the WCAG recommendations for text contrast.
  static Color getContrastingTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
