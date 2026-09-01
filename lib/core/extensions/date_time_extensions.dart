import 'package:intl/intl.dart';

const String displayDateFormat = 'MMM dd, yyyy HH:mm';
final displayDateFormatter = DateFormat(isoDateFormat);

const String isoDateFormat = 'yyyy-MM-dd';
final isoDateFormatter = DateFormat(isoDateFormat);

extension DateTimeExt on DateTime {
  /// Day-granular bound for the ISO-8601 timestamps stored in TEXT columns.
  ///
  /// SQLite compares TEXT lexicographically, so `'2026-09-30T12:00' < '2026-10-01'`
  /// holds while `<= '2026-09-30'` would drop that entire day. Range bounds must
  /// therefore be half-open: `>= startInclusive AND < endExclusive`.
  String get isoDate => isoDateFormatter.format(this);
  String? get format => displayDateFormatter.format(this);
}

extension NullableDateTimeExt on DateTime? {
  String? get format =>
      this != null ? displayDateFormatter.format(this!) : null;
}
