import 'package:finanalyzer/core/module.dart';
import 'package:finanalyzer/settings/settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';

class SettingsModule implements Module {
  @override
  late final List<SingleChildWidget> providers;


SettingsModule () {
  providers = [
    BlocProvider(create: (_) => SettingsCubit()),
  ];
}

  @override
  void dispose() {
  }
}