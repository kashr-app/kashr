import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/core/uuid_json_converter.dart';
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

  const factory SavingsVirtualBooking({
    @UUIDNullableJsonConverter() UuidValue? id,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'savings_id')
    @UUIDJsonConverter()
    required UuidValue savingsId,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'account_id')
    @UUIDJsonConverter()
    required UuidValue accountId,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'amount_value')
    @DecimalJsonConverter()
    required Decimal amountValue,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'amount_unit') required String amountUnit,
    String? note,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'booking_date') required DateTime bookingDate,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _SavingsVirtualBooking;

  String format() => Currency.currencyFrom(amountUnit).format(amountValue);

  factory SavingsVirtualBooking.fromJson(Map<String, dynamic> json) =>
      _$SavingsVirtualBookingFromJson(json);
}
