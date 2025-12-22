import 'package:finanalyzer/logging/model/log_level_setting.dart';
import 'package:finanalyzer/logging/services/log_service.dart';
import 'package:finanalyzer/settings/settings_repository.dart';
import 'package:finanalyzer/settings/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _repository;
  final LogService _logService;

  SettingsCubit(this._repository, this._logService)
    : super(const SettingsState()) {
    load();
  }

  Future<void> load() async {
    final stored = await _repository.loadAll();
    emit(stored);

    _logService.setLogLevel(stored.logLevel);
  }

  Future<void> setTheme(ThemeMode value) async {
    final newState = state.copyWith(themeMode: value);
    _upsertAndEmit('themeMode', newState);
  }

  Future<void> setFastFormMode(bool value) async {
    final newState = state.copyWith(fastFormMode: value);
    await _upsertAndEmit('fastFormMode', newState);
  }

  Future<void> setLogLevel(LogLevelSetting value) async {
    final newState = state.copyWith(logLevel: value);
    await _upsertAndEmit('logLevel', newState);

    _logService.setLogLevel(value);
  }

  Future<void> _upsertAndEmit(String key, SettingsState newState) async {
    // get the converted value that we can store in db.
    // this helps utilizing annotated json converters in the SettingsState class
    // we then however still use toString on it because the DB uses string for all values
    final json = newState.toJson();
    final value = json[key].toString();

    await _repository.upsertSetting(key, value);

    emit(newState);
  }
}
