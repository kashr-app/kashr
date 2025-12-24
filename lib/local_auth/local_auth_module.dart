import 'package:kashr/core/app_lifecycle_listeners.dart';
import 'package:kashr/core/module.dart';
import 'package:kashr/local_auth/cubit/local_auth_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:provider/single_child_widget.dart';

class LocalAuthModule implements Module {
  @override
  late final List<SingleChildWidget> providers;

  LocalAuthModule(AppLifecycleListeners appLifecycleListeners, Logger log) {
    final localAuthCubit = LocalAuthCubit(log);

    providers = [BlocProvider.value(value: localAuthCubit)];

    appLifecycleListeners.registerOnHide(() => localAuthCubit.logout());
  }

  @override
  void dispose() {}
}
