import 'package:intl/intl.dart';

const String displayDateFormat = 'MMM dd, yyyy HH:mm';
final displayDateFormatter = DateFormat(isoDateFormat);

const String isoDateFormat = 'yyyy-MM-dd';
final isoDateFormatter = DateFormat(isoDateFormat);

extension DateTimeExt on DateTime {
  String get isoDate => isoDateFormatter.format(this);
  String? get format => displayDateFormatter.format(this);
}

extension NullableDateTimeExt on DateTime? {
  String? get format =>
      this != null ? displayDateFormatter.format(this!) : null;
}
