import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/core/uuid_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:decimal/decimal.dart';

part '../_gen/model/tag_turnover.freezed.dart';
part '../_gen/model/tag_turnover.g.dart';

@freezed
abstract class TagTurnover with _$TagTurnover {
  const TagTurnover._();

  const factory TagTurnover({
    @UUIDNullableJsonConverter() UuidValue? id,
    @UUIDJsonConverter() required UuidValue turnoverId,
    @UUIDJsonConverter() required UuidValue tagId,
    @DecimalJsonConverter() required Decimal amountValue,
    required String amountUnit,
    required String? note,
  }) = _TagTurnover;

  factory TagTurnover.fromJson(Map<String, dynamic> json) =>
      _$TagTurnoverFromJson(json);
}
