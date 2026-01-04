import 'package:intl/intl.dart';

const String isoDateFormat = 'yyyy-MM-dd';
final isoDateFormatter = DateFormat(isoDateFormat);

extension DateTimeExt on DateTime {
  String get isoDate => isoDateFormatter.format(this);
}
