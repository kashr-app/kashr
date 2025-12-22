import 'package:finanalyzer/logging/model/log_level_setting.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/logging/model/log_entry.freezed.dart';
part '../../_gen/logging/model/log_entry.g.dart';

@freezed
abstract class LogEntry with _$LogEntry {
  const factory LogEntry({
    required DateTime timestamp,
    required LogLevelSetting level,
    required String message,
    String? loggerName,
    String? error,
    String? stackTrace,
    Map<String, dynamic>? context,
  }) = _LogEntry;

  factory LogEntry.fromJson(Map<String, dynamic> json) =>
      _$LogEntryFromJson(json);
}
