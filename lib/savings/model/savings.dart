import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/core/uuid_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:decimal/decimal.dart';

part '../../_gen/savings/model/savings.freezed.dart';
part '../../_gen/savings/model/savings.g.dart';

/// Represents a savings goal/category linked to a tag
///
/// The balance of this savings is calculated as:
/// Sum(TagTurnover where tag = tagId) + Sum(SavingsVirtualBooking where savingsId = id)
@freezed
abstract class Savings with _$Savings {
  const Savings._();

  const factory Savings({
    @UUIDNullableJsonConverter() UuidValue? id,
    @JsonKey(name: 'tag_id') @UUIDJsonConverter() required UuidValue tagId,
    @JsonKey(name: 'goal_value')
    @DecimalNullableJsonConverter()
    Decimal? goalValue,
    @JsonKey(name: 'goal_unit') String? goalUnit,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _Savings;

  factory Savings.fromJson(Map<String, dynamic> json) =>
      _$SavingsFromJson(json);
}
