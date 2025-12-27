import 'package:kashr/core/module.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:kashr/settings/settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class SettingsModule implements Module {
  final LogService logService;
  late final SettingsCubit settingsCubit;

  @override
  late final List<SingleChildWidget> providers;

  SettingsModule(this.logService) {
    settingsCubit = SettingsCubit(SettingsRepository(), logService);

    providers = [
      Provider.value(value: this),
      BlocProvider.value(value: settingsCubit),
    ];
  }

  @override
  void dispose() {}
}
