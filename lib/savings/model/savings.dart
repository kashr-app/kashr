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
    @UUIDJsonConverter() required UuidValue id,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'tag_id') @UUIDJsonConverter() required UuidValue tagId,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'goal_value')
    @DecimalNullableJsonConverter()
    Decimal? goalValue,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'goal_unit') String? goalUnit,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _Savings;

  factory Savings.fromJson(Map<String, dynamic> json) =>
      _$SavingsFromJson(json);
}
