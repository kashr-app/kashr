import 'package:finanalyzer/core/bool_json_converter.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../_gen/settings/settings_state.freezed.dart';
part '../_gen/settings/settings_state.g.dart';

@freezed
abstract class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(ThemeMode.system) ThemeMode themeMode,
    @BoolJsonConverter() @Default(false) bool quickTurnoverEntryAutoFlow,
  }) = _SettingsState;

  factory SettingsState.fromJson(Map<String, Object?> json) =>
      _$SettingsStateFromJson(json);
}
