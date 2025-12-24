import 'package:kashr/core/module.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:kashr/settings/settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class SettingsModule implements Module {
  final LogService logService;

  @override
  late final List<SingleChildWidget> providers;

  SettingsModule(this.logService) {
    providers = [
      Provider.value(value: this),
      BlocProvider(
        create: (_) => SettingsCubit(SettingsRepository(), logService),
      ),
    ];
  }

  @override
  void dispose() {}
}
