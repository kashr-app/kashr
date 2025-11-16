import 'package:finanalyzer/settings/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(SettingsState.initial());

  void setTheme(ThemeMode value) => emit(state.copyWith(
        themeMode: value,
      ));
}
