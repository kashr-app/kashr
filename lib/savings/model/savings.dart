import 'package:kashr/core/decimal_json_converter.dart';
import 'package:kashr/core/uuid_json_converter.dart';
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

  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Savings({
    @UUIDJsonConverter() required UuidValue id,

    @UUIDJsonConverter() required UuidValue tagId,

    @DecimalNullableJsonConverter() Decimal? goalValue,
    String? goalUnit,
    required DateTime createdAt,
  }) = _Savings;

  factory Savings.fromJson(Map<String, dynamic> json) =>
      _$SavingsFromJson(json);
}
