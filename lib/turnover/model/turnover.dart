import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/core/uuid_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:decimal/decimal.dart';

part '../../_gen/turnover/model/turnover.freezed.dart';
part '../../_gen/turnover/model/turnover.g.dart';

final dateFormat = DateFormat("dd.MM.yyyy");
const String isoDateFormat = 'yyyy-MM-dd';

@freezed
abstract class Turnover with _$Turnover {
  // required because of custom methods in the class annotated with @freezed
  const Turnover._();

  const factory Turnover({
    @UUIDJsonConverter() required UuidValue id,
    required DateTime createdAt,
    @UUIDJsonConverter() required UuidValue accountId,
    DateTime? bookingDate,
    @DecimalJsonConverter() required Decimal amountValue,
    required String amountUnit,
    String? counterPart,
    required String purpose,
    String? apiId,
  }) = _Turnover;

  factory Turnover.fromJson(Map<String, dynamic> json) =>
      _$TurnoverFromJson(json);

  String formatAmount() =>
      Currency.currencyFrom(amountUnit).format(amountValue);
  String? formatDate() {
    final bd = bookingDate;
    return bd != null ? dateFormat.format(bd) : null;
  }
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
