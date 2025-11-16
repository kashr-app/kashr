import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

// We store Decimals as int scaled by 100
// E.g. 10.24 will be stored as 1024
const int decimalScaleFactor = 100;

int? decimalScale(Decimal? d) => d == null
    ? null
    : (d * Decimal.fromInt(decimalScaleFactor)).toBigInt().toInt();

Decimal? decimalUnscale(int? d) => d == null
    ? null
    : (Decimal.fromInt(d) / Decimal.fromInt(decimalScaleFactor)).toDecimal();

class DecimalNullableJsonConverter extends JsonConverter<Decimal?, int?> {
  const DecimalNullableJsonConverter();

  @override
  Decimal? fromJson(int? json) {
    if (json == null) {
      return null;
    }
    return decimalUnscale(json);
  }

  @override
  int? toJson(Decimal? object) {
    if (object == null) {
      return null;
    }
    return decimalScale(object);
  }
}

class DecimalJsonConverter extends JsonConverter<Decimal, int> {
  const DecimalJsonConverter();

  @override
  Decimal fromJson(int json) {
    return decimalUnscale(json)!;
  }

  @override
  int toJson(Decimal object) {
    return decimalScale(object)!;
  }
}
