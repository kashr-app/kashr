import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../_gen/settings/settings_state.freezed.dart';
part '../_gen/settings/settings_state.g.dart';

@freezed
abstract class SettingsState with _$SettingsState {
  const factory SettingsState({
    required ThemeMode themeMode,
  }) = _SettingsState;

  factory SettingsState.initial() {
    return const SettingsState(
      themeMode: ThemeMode.system,
    );
  }

  factory SettingsState.fromJson(Map<String, Object?> json) =>
      _$SettingsStateFromJson(json);
}
