import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

/// A calendar day, such as the day a bank booked a transaction on.
///
/// Deliberately not a [DateTime]. A [DateTime] is an instant, so modelling a
/// day as one forces an "always midnight, always local" convention that
/// nothing can enforce, and it lets elapsed-time arithmetic
/// (`add(Duration(days: 1))`, `difference(...).inDays`) look right while
/// silently depending on the time of day.
@immutable
class BookingDate implements Comparable<BookingDate> {
  final int year;
  final int month;
  final int day;

  const BookingDate._(this.year, this.month, this.day);

  /// Out-of-range values roll over, so `BookingDate(2026, 1, 32)` is
  /// 1 February 2026 and [addDays] needs no month arithmetic of its own.
  factory BookingDate(int year, int month, int day) =>
      BookingDate.on(DateTime(year, month, day));

  /// The local calendar day [instant] falls on.
  factory BookingDate.on(DateTime instant) =>
      BookingDate._(instant.year, instant.month, instant.day);

  factory BookingDate.today() => BookingDate.on(DateTime.now());

  /// Reads a bare `yyyy-MM-dd` and a full ISO-8601 timestamp alike, so a row
  /// written before the storage format was normalised still parses as the day
  /// it names.
  factory BookingDate.parse(String value) =>
      BookingDate.on(DateTime.parse(value));

  /// How a booking date is stored, and how it bounds SQL.
  String get iso =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// Midnight local, for the APIs that still speak [DateTime], such as
  /// `showDatePicker`.
  DateTime get atMidnight => DateTime(year, month, day);

  String format(DateFormat dateFormat) => dateFormat.format(atMidnight);

  BookingDate addDays(int days) => BookingDate(year, month, day + days);

  /// Whole calendar days from this day to [other], negative when [other] is
  /// earlier.
  ///
  /// Measured in UTC because a local day is 23 or 25 hours long around a
  /// daylight saving change, which would round the answer to the wrong day.
  int daysUntil(BookingDate other) => other._utc.difference(_utc).inDays;

  DateTime get _utc => DateTime.utc(year, month, day);

  bool isBefore(BookingDate other) => compareTo(other) < 0;

  bool isAfter(BookingDate other) => compareTo(other) > 0;

  @override
  int compareTo(BookingDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingDate &&
          other.year == year &&
          other.month == month &&
          other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => iso;
}
