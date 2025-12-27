import 'package:kashr/core/bool_json_converter.dart';
import 'package:kashr/logging/model/log_level_setting.dart';
import 'package:kashr/local_auth/auth_delay.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../_gen/settings/settings_state.freezed.dart';
part '../_gen/settings/settings_state.g.dart';

@freezed
abstract class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(ThemeMode.system) ThemeMode themeMode,
    @BoolJsonConverter() @Default(false) bool fastFormMode,
    @LogLevelSettingConverter()
    @Default(LogLevelSetting.error)
    LogLevelSetting logLevel,
    @AuthDelayOptionConverter()
    @Default(AuthDelayOption.immediate)
    AuthDelayOption authDelay,
  }) = _SettingsState;

  factory SettingsState.fromJson(Map<String, Object?> json) =>
      _$SettingsStateFromJson(json);
}

class LogLevelSettingConverter
    implements JsonConverter<LogLevelSetting, String> {
  const LogLevelSettingConverter();

  @override
  LogLevelSetting fromJson(String json) {
    return LogLevelSetting.values.firstWhere(
      (e) => e.name == json,
      orElse: () => LogLevelSetting.error,
    );
  }

  @override
  String toJson(LogLevelSetting object) => object.name;
}
