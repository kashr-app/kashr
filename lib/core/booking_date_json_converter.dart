import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kashr/core/model/booking_date.dart';

class BookingDateNullableJsonConverter
    extends JsonConverter<BookingDate?, String?> {
  const BookingDateNullableJsonConverter();

  @override
  BookingDate? fromJson(String? json) =>
      json == null ? null : BookingDate.parse(json);

  @override
  String? toJson(BookingDate? object) => object?.iso;
}

class BookingDateJsonConverter extends JsonConverter<BookingDate, String> {
  const BookingDateJsonConverter();

  @override
  BookingDate fromJson(String json) => BookingDate.parse(json);

  @override
  String toJson(BookingDate object) => object.iso;
}
