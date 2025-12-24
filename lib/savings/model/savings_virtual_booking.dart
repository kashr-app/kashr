import 'package:kashr/core/currency.dart';
import 'package:kashr/core/decimal_json_converter.dart';
import 'package:kashr/core/uuid_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:decimal/decimal.dart';

part '../../_gen/savings/model/savings_virtual_booking.freezed.dart';
part '../../_gen/savings/model/savings_virtual_booking.g.dart';

/// Virtual booking for mental accounting (not linked to any turnover)
///
/// Represents adjustments not tied to any turnover, e.g.:
/// - "€3K of my €20K balance is child savings"
/// - "Moving €500 from spendable to child savings"
@freezed
abstract class SavingsVirtualBooking with _$SavingsVirtualBooking {
  const SavingsVirtualBooking._();

  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory SavingsVirtualBooking({
    @UUIDJsonConverter() required UuidValue id,

    @UUIDJsonConverter() required UuidValue savingsId,

    @UUIDJsonConverter() required UuidValue accountId,

    @DecimalJsonConverter() required Decimal amountValue,

    required String amountUnit,
    String? note,
    required DateTime bookingDate,
    required DateTime createdAt,
  }) = _SavingsVirtualBooking;

  String format() => Currency.currencyFrom(amountUnit).format(amountValue);

  factory SavingsVirtualBooking.fromJson(Map<String, dynamic> json) =>
      _$SavingsVirtualBookingFromJson(json);
}
