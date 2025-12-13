import 'package:finanalyzer/core/app_lifecycle_listeners.dart';
import 'package:finanalyzer/core/module.dart';
import 'package:finanalyzer/local_auth/cubit/local_auth_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';

class LocalAuthModule implements Module {
  @override
  late final List<SingleChildWidget> providers;

  LocalAuthModule(AppLifecycleListeners appLifecycleListeners) {
    final localAuthCubit = LocalAuthCubit();

    providers = [BlocProvider.value(value: localAuthCubit)];

    appLifecycleListeners.registerOnHide(() => localAuthCubit.logout());
  }

  @override
  void dispose() {}
}
