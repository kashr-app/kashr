import 'package:intl/intl.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/core/decimal_json_converter.dart';
import 'package:kashr/core/uuid_json_converter.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:decimal/decimal.dart';

part '../../_gen/turnover/model/tag_turnover.freezed.dart';
part '../../_gen/turnover/model/tag_turnover.g.dart';

@freezed
abstract class TagTurnover with _$TagTurnover {
  const TagTurnover._();

  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory TagTurnover({
    @UUIDJsonConverter() required UuidValue id,

    // Can be null for immediate/planned expenses that have not yet been associated with a turnover
    @UUIDNullableJsonConverter() UuidValue? turnoverId,

    @UUIDJsonConverter() required UuidValue tagId,

    @DecimalJsonConverter() required Decimal amountValue,

    required String amountUnit,
    String? counterPart,
    String? note,
    required DateTime createdAt,
    required DateTime bookingDate,

    @UUIDJsonConverter() required UuidValue accountId,

    @UUIDNullableJsonConverter() UuidValue? recurringRuleId,
  }) = _TagTurnover;

  String formatAmount() =>
      Currency.currencyFrom(amountUnit).format(amountValue);

  String formatDate(DateFormat dateFormat) => dateFormat.format(bookingDate);

  // Computed properties
  bool get isMatched => turnoverId != null;
  bool get isUnmatched => turnoverId == null;
  bool get isRecurring => recurringRuleId != null;

  factory TagTurnover.fromJson(Map<String, dynamic> json) =>
      _$TagTurnoverFromJson(json);

  TurnoverSign get sign => TurnoverSign.fromDecimal(amountValue);
}

/// The tag turnovers touching one period, split by where they were booked.
/// 
/// Two DISJOINT sets
/// - [allocatedInPeriod]: [TagTurnover]s with booking_date in the period
/// - [allocatedOutsidePeriodButTurnoverInPeriod]: [TagTurnover]s outside
///   the period, but with their [Turnover] booking_date in the period.
///   The [Turnover]s untagged remainder still belongs to the period; i.e.
///   Total in period =
///     tagged (by TagTurnover.booking_date)
///     + untagged (by Turnover.booking_date)
typedef TagTurnoverAllocation = ({
  List<TagTurnover> allocatedInPeriod,
  List<TagTurnover> allocatedOutsidePeriodButTurnoverInPeriod,
});
