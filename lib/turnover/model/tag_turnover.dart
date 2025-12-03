import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/core/uuid_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:decimal/decimal.dart';

part '../../_gen/turnover/model/tag_turnover.freezed.dart';
part '../../_gen/turnover/model/tag_turnover.g.dart';

@freezed
abstract class TagTurnover with _$TagTurnover {
  const TagTurnover._();

  const factory TagTurnover({
    @UUIDJsonConverter() required UuidValue id,
    // Can be null for immediate/planned expenses that have not yet been associated with a turnover
    @UUIDNullableJsonConverter() UuidValue? turnoverId,
    @UUIDJsonConverter() required UuidValue tagId,
    @DecimalJsonConverter() required Decimal amountValue,
    required String amountUnit,
    String? note,
    required DateTime createdAt,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'booking_date') required DateTime bookingDate,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'account_id')
    @UUIDJsonConverter()
    required UuidValue accountId,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'recurring_rule_id')
    @UUIDNullableJsonConverter()
    UuidValue? recurringRuleId,
  }) = _TagTurnover;

  String format() => Currency.currencyFrom(amountUnit).format(amountValue);

  // Computed properties
  bool get isMatched => turnoverId != null;
  bool get isUnmatched => turnoverId == null;
  bool get isRecurring => recurringRuleId != null;

  factory TagTurnover.fromJson(Map<String, dynamic> json) =>
      _$TagTurnoverFromJson(json);
}
