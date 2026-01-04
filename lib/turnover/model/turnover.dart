import 'package:kashr/core/currency.dart';
import 'package:kashr/core/decimal_json_converter.dart';
import 'package:kashr/core/uuid_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:decimal/decimal.dart';

part '../../_gen/turnover/model/turnover.freezed.dart';
part '../../_gen/turnover/model/turnover.g.dart';

final dateFormat = DateFormat("dd.MM.yyyy");

/// Enum representing the sign/type of a turnover amount
enum TurnoverSign {
  /// Income (positive amount)
  income,

  /// Expense (negative amount)
  expense;

  static TurnoverSign fromDecimal(Decimal amount) {
    return amount < Decimal.zero ? expense : income;
  }
}

@freezed
abstract class Turnover with _$Turnover {
  // required because of custom methods in the class annotated with @freezed
  const Turnover._();

  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Turnover({
    @UUIDJsonConverter() required UuidValue id,

    required DateTime createdAt,

    @UUIDJsonConverter() required UuidValue accountId,

    DateTime? bookingDate,

    @DecimalJsonConverter() required Decimal amountValue,

    required String amountUnit,
    String? counterPart,
    String? counterIban,
    required String purpose,

    String? apiId,
    String? apiTurnoverType,
    // the raw unparsed data from the API
    String? apiRaw,

  }) = _Turnover;

  factory Turnover.fromJson(Map<String, dynamic> json) =>
      _$TurnoverFromJson(json);

  String formatAmount() =>
      Currency.currencyFrom(amountUnit).format(amountValue);
  String? formatDate() {
    final bd = bookingDate;
    return bd != null ? dateFormat.format(bd) : null;
  }

  TurnoverSign get sign => TurnoverSign.fromDecimal(amountValue);
}

@freezed
abstract class TurnoverAccountIdAndApiId with _$TurnoverAccountIdAndApiId {
  const factory TurnoverAccountIdAndApiId({
    @UUIDJsonConverter() required UuidValue accountId,
    String? apiId,
  }) = _TurnoverAccountIdAndApiId;

  factory TurnoverAccountIdAndApiId.fromJson(Map<String, dynamic> json) =>
      _$TurnoverAccountIdAndApiIdFromJson(json);
}
