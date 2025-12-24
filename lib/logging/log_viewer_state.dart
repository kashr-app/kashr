import 'package:kashr/logging/model/log_entry.dart';
import 'package:kashr/logging/model/log_level_setting.dart';
import 'package:kashr/settings/settings_state.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../_gen/logging/log_viewer_state.freezed.dart';

@freezed
abstract class LogViewerState with _$LogViewerState {
  const factory LogViewerState({
    @Default([]) List<LogEntry> logs,
    @Default(false) bool isLoading,
    String? error,
    @LogLevelSettingConverter() LogLevelSetting? filterLevel,
  }) = _LogViewerState;
}
