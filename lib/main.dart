import 'package:finanalyzer/account/account_module.dart';
import 'package:finanalyzer/backup/backup_module.dart';
import 'package:finanalyzer/comdirect/comdirect_module.dart';
import 'package:finanalyzer/core/app_lifecycle_listeners.dart';
import 'package:finanalyzer/core/module.dart';
import 'package:finanalyzer/core/restart_widget.dart';
import 'package:finanalyzer/local_auth/cubit/local_auth_cubit.dart';
import 'package:finanalyzer/local_auth/local_auth_module.dart';
import 'package:finanalyzer/savings/savings_module.dart';
import 'package:finanalyzer/router.dart';
import 'package:finanalyzer/settings/settings_cubit.dart';
import 'package:finanalyzer/settings/settings_module.dart';
import 'package:finanalyzer/settings/settings_state.dart';
import 'package:finanalyzer/theme.dart';
import 'package:finanalyzer/turnover/turnover_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

const bool isDevelopment = bool.fromEnvironment('dart.vm.product') == false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RestartWidget(child: const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final List<Module> _modules;
  final _appLifeCycleListeners = AppLifecycleListeners();

  @override
  void initState() {
    super.initState();

    // Initialize dependency tree
    final turnoverModule = TurnoverModule();
    _modules = [
      LocalAuthModule(_appLifeCycleListeners),
      SettingsModule(),
      BackupModule(),
      turnoverModule,
      SavingsModule(turnoverModule),
      AccountModule(turnoverModule),
      ComdirectModule(),
    ];
  }

  @override
  void dispose() {
    for (var it in _modules) {
      it.dispose();
    }

    _appLifeCycleListeners.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        for (final m in _modules) Provider.value(value: m),
        ..._modules.expand((it) => it.providers),
      ],
      child: BlocListener<LocalAuthCubit, LocalAuthState>(
        // ensure to re-evaluate router redirects when auth state changes.
        listener: (context, state) => router.refresh(),
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            return MaterialApp.router(
              title: 'Finanalyzer',
              theme: lightMode,
              darkTheme: darkMode,
              themeMode: state.themeMode,
              debugShowCheckedModeBanner: false,
              routerConfig: router,
            );
          },
        ),
      ),
    );
  }
}
