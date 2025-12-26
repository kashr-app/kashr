// ignore_for_file: constant_identifier_names

import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Must be in sync with the supported currencies (see backend Currency enum).
enum Currency {
  EUR,

  // other currencies
  USD,
  JPY,
  BGN,
  CZK,
  DKK,
  GBP,
  HUF,
  PLN,
  RON,
  SEK,
  CHF,
  ISK,
  NOK,
  HRK,
  TRY,
  AUD,
  BRL,
  CAD,
  CNY,
  HKD,
  IDR,
  ILS,
  INR,
  KRW,
  MXN,
  MYR,
  NZD,
  PHP,
  SGD,
  THB,
  ZAR;

  static Currency currencyFrom(String name) {
    return values.firstWhere((e) => e.name == name);
  }
}

extension CurrencyExtension on Currency {
  /// Applies forced sign to formatted currency based on locale conventions.
  /// For positive numbers, formats the negative equivalent and replaces '-'
  /// with '+' to ensure correct sign placement per locale.
  /// For zero, replaces '-' with '±'.
  String _applyForceSign(
    Decimal amount,
    String formatted,
    String Function(Decimal) formatter,
  ) {
    if (amount > Decimal.zero) {
      // Format as negative to get sign position, then replace with '+'
      final negativeFormatted = formatter(-amount);
      return negativeFormatted.replaceFirst('-', '+');
    } else if (amount < Decimal.zero) {
      // Already has the sign
      return formatted;
    } else {
      // Zero: replace '-' with '±' using same position logic
      final negativeFormatted = formatter(Decimal.parse('-0.01'));
      // Find position of '-' and create formatted string with '±'
      final signIndex = negativeFormatted.indexOf('-');
      if (signIndex >= 0) {
        return '${formatted.substring(0, signIndex)}±${formatted.substring(signIndex)}';
      }
      return '±$formatted';
    }
  }

  /// Parses [amount.toString()] using 'en' decimal pattern and formats the
  /// result as currency of the given [currency] (ISO 4217) and using a decimal
  /// pattern of the [Intl.getCurrentLocale()].
  String format(Decimal amount, {int decimalDigits = 2, forceSign = false}) {
    final value = NumberFormat.decimalPattern('en').parse(amount.toString());
    final locale = Intl.getCurrentLocale();
    final currencyFormatter = NumberFormat.simpleCurrency(
      name: name,
      locale: locale,
      decimalDigits: decimalDigits,
    );
    final formatted = currencyFormatter.format(value);

    if (forceSign) {
      return _applyForceSign(amount, formatted, (amt) {
        final val = NumberFormat.decimalPattern('en').parse(amt.toString());
        return currencyFormatter.format(val);
      });
    }
    return formatted;
  }

  /// Parses [amount.toString()] using 'en' decimal pattern and formats the
  /// result with a decimal pattern of the [Intl.getCurrentLocale()].
  static String formatNoSymbol(
    dynamic amount, {
    int decimalDigits = 2,
    String symbol = '',
  }) {
    final value = NumberFormat.decimalPattern('en').parse(amount.toString());
    final locale = Intl.getCurrentLocale();
    final currencyFormatter = NumberFormat.currency(
      locale: locale,
      decimalDigits: decimalDigits,
      symbol: symbol,
    );
    return currencyFormatter
        .format(value)
        .trim() /* format does add a space between the value and the
                        symbol "" (i.e. a space at the end). */;
  }

  String symbol() {
    final locale = Intl.getCurrentLocale();
    final currencyFormatter = NumberFormat.simpleCurrency(
      name: name,
      locale: locale,
    );
    return currencyFormatter.simpleCurrencySymbol(name);
  }

  /// Formats [amount] with compact notation (k, M, B, T) for large values.
  /// Uses full formatting for values below the threshold (default 1,000).
  String formatCompact(
    Decimal amount, {
    int threshold = 1000,
    int decimalDigits = 1,
    bool forceSign = false,
  }) {
    final absAmount = amount.abs();
    final value = double.parse(absAmount.toString());

    // If below threshold, use regular formatting
    if (value < threshold) {
      return format(amount, forceSign: forceSign);
    }

    // Determine the suffix and divisor
    final String suffix;
    final double divisor;

    if (value >= 1e12) {
      suffix = 'T';
      divisor = 1e12;
    } else if (value >= 1e9) {
      suffix = 'B';
      divisor = 1e9;
    } else if (value >= 1e6) {
      suffix = 'M';
      divisor = 1e6;
    } else {
      suffix = 'k';
      divisor = 1e3;
    }

    // Calculate abbreviated value
    final abbreviated = value / divisor;
    final abbreviatedDecimal = amount < Decimal.zero
        ? Decimal.parse('-$abbreviated')
        : Decimal.parse('$abbreviated');

    // Format using currency formatter for proper localization
    final locale = Intl.getCurrentLocale();
    final currencyFormatter = NumberFormat.simpleCurrency(
      name: name,
      locale: locale,
      decimalDigits: decimalDigits,
    );

    final formatted = currencyFormatter.format(
      NumberFormat.decimalPattern('en').parse(abbreviatedDecimal.toString()),
    );

    // Append suffix to the formatted currency
    // The formatter handles symbol placement based on locale
    final formattedWithSuffix = '$formatted$suffix';

    if (forceSign) {
      return _applyForceSign(amount, formattedWithSuffix, (amt) {
        final abbr = double.parse(amt.abs().toString()) / divisor;
        final abbrDecimal = amt < Decimal.zero
            ? Decimal.parse('-$abbr')
            : Decimal.parse('$abbr');
        final val = NumberFormat.decimalPattern(
          'en',
        ).parse(abbrDecimal.toString());
        return '${currencyFormatter.format(val)}$suffix';
      });
    }

    return formattedWithSuffix;
  }
}
