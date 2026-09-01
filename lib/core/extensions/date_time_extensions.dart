import 'package:intl/intl.dart';

const String displayDateFormat = 'MMM dd, yyyy HH:mm';
final displayDateFormatter = DateFormat(isoDateFormat);

const String isoDateFormat = 'yyyy-MM-dd';
final isoDateFormatter = DateFormat(isoDateFormat);

extension DateTimeExt on DateTime {
  /// Renders a `Period` bound as the day-granular string SQL compares against.
  ///
  /// Ranges are half-open; see `doc/README.md`.
  String get isoDate => isoDateFormatter.format(this);
  String? get format => displayDateFormatter.format(this);
}

extension NullableDateTimeExt on DateTime? {
  String? get format =>
      this != null ? displayDateFormatter.format(this!) : null;
}
