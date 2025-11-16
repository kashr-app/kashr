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
  ZAR,
;

  static Currency currencyFrom(String name) {
    return values.firstWhere((e) => e.name == name);
  }
}


extension CurrencyExtension on Currency {
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
      final String sign;
      if (amount > Decimal.zero) {
        sign = '+';
      } else if (amount < Decimal.zero) {
        // formatted has the sign already
        sign = '';
      } else {
        sign = '±';
      }
      return sign + formatted;
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
                        symbol "" (i.e. a space at the end). */
        ;
  }

  String symbol() {
    final locale = Intl.getCurrentLocale();
    final currencyFormatter = NumberFormat.simpleCurrency(
      name: name,
      locale: locale,
    );
    return currencyFormatter.simpleCurrencySymbol(name);
  }
}
