import 'package:go_router/go_router.dart';
import 'package:kashr/core/app_lifecycle_listeners.dart';
import 'package:kashr/core/module.dart';
import 'package:kashr/local_auth/cubit/local_auth_cubit.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:provider/single_child_widget.dart';

class LocalAuthModule implements Module {
  @override
  late final List<SingleChildWidget> providers;

  LocalAuthModule(
    AppLifecycleListeners appLifecycleListeners,
    SettingsCubit settingsCubit,
    GoRouter router,
    Logger log,
  ) {
    final localAuthCubit = LocalAuthCubit(log, router, settingsCubit);

    providers = [BlocProvider.value(value: localAuthCubit)];

    appLifecycleListeners.registerOnHide(() {
      localAuthCubit.onAppHidden();
    });

    appLifecycleListeners.registerOnShow(() {
      localAuthCubit.onAppShow();
    });
  }

  @override
  void dispose() {}
}
