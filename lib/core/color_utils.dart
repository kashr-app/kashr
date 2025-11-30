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
      final hexString = colorString.replaceFirst('#', '');
      final hexValue = int.parse(hexString, radix: 16);
      // Add alpha channel if not present (assumes RGB format)
      final colorValue =
          hexString.length == 6 ? 0xFF000000 + hexValue : hexValue;
      return Color(colorValue);
    } catch (e) {
      return null;
    }
  }

  /// Converts a [Color] to a hex string (e.g., "#FF5733").
  ///
  /// The returned string includes the RGB values but excludes the alpha channel.
  static String colorToString(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
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
