import 'dart:async';
import 'dart:developer' as developer;

import 'package:kashr/account/account_module.dart';
import 'package:kashr/backup/backup_module.dart';
import 'package:kashr/comdirect/comdirect_module.dart';
import 'package:kashr/core/app_lifecycle_listeners.dart';
import 'package:kashr/core/module.dart';
import 'package:kashr/core/restart_widget.dart';
import 'package:kashr/local_auth/cubit/local_auth_cubit.dart';
import 'package:kashr/local_auth/local_auth_module.dart';
import 'package:kashr/logging/logging_module.dart';
import 'package:kashr/logging/model/log_level_setting.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:kashr/savings/savings_module.dart';
import 'package:kashr/app_router.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:kashr/settings/settings_module.dart';
import 'package:kashr/settings/settings_state.dart';
import 'package:kashr/theme.dart';
import 'package:kashr/turnover/turnover_module.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jiffy/jiffy.dart';
import 'package:provider/provider.dart';

LogService? _logService;

void main() async {
  await runZonedGuarded(
    () async {
      developer.log('main() started', name: 'kashr.main');
      WidgetsFlutterBinding.ensureInitialized();
      developer.log('WidgetsFlutterBinding initialized', name: 'kashr.main');

      await Jiffy.setLocale('en');
      developer.log('Jiffy initialized with default locale', name: 'kashr.main');

      final loggingModule = LoggingModule();
      developer.log('LoggingModule created', name: 'kashr.main');

      // Add timeout protection to prevent indefinite hanging
      await loggingModule.logService.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          developer.log(
            'LogService initialization timed out after 10s',
            name: 'kashr.main',
            level: 900,
          );
        },
      );
      developer.log('LogService initialized', name: 'kashr.main');

      _logService = loggingModule.logService;

      _setupErrorHandlers(loggingModule.logService);
      developer.log('Error handlers configured', name: 'kashr.main');

      developer.log('Starting runApp()', name: 'kashr.main');
      runApp(
        RestartWidget(
          child: MyApp(loggingModule, AppRouter(loggingModule.logService.log)),
        ),
      );
      developer.log('runApp() completed', name: 'kashr.main');
    },
    (error, stack) {
      developer.log(
        'Uncaught Zone error',
        name: 'kashr.main',
        level: 1000,
        error: error,
        stackTrace: stack,
      );
      _logService?.logToFile(
        level: LogLevelSetting.error,
        message: 'Uncaught zone error',
        loggerName: 'ZoneError',
        error: error.toString(),
        stackTrace: stack.toString(),
      );
    },
  );
}

void _setupErrorHandlers(LogService logService) {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    logService.logToFile(
      level: LogLevelSetting.fatal,
      message: 'Flutter Error: ${details.exceptionAsString()}',
      loggerName: 'FlutterError',
      error: details.exception.toString(),
      stackTrace: details.stack?.toString(),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logService.logToFile(
      level: LogLevelSetting.error,
      message: 'Uncaught async error',
      loggerName: 'AsyncError',
      error: error.toString(),
      stackTrace: stack.toString(),
    );
    return true;
  };
}

class MyApp extends StatefulWidget {
  final LoggingModule loggingModule;
  final AppRouter router;

  const MyApp(this.loggingModule, this.router, {super.key});

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
    final log = widget.loggingModule.logService.log;
    final settingsModule = SettingsModule(widget.loggingModule.logService);
    final turnoverModule = TurnoverModule(log);
    _modules = [
      widget.loggingModule,
      settingsModule,
      LocalAuthModule(
        _appLifeCycleListeners,
        settingsModule.settingsCubit,
        widget.router.router,
        log,
      ),
      BackupModule(log),
      turnoverModule,
      SavingsModule(turnoverModule, log),
      AccountModule(turnoverModule, log),
      ComdirectModule(log),
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
    final themeBuilder = ThemeBuilder();
    return MultiProvider(
      providers: [..._modules.expand((it) => it.providers)],
      child: BlocListener<LocalAuthCubit, LocalAuthState>(
        // ensure to re-evaluate router redirects when auth state changes.
        listener: (context, state) => widget.router.router.refresh(),
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            return MaterialApp.router(
              title: 'Kashr',
              theme: themeBuilder.lightMode(),
              darkTheme: themeBuilder.darkMode(),
              themeMode: state.themeMode,
              debugShowCheckedModeBanner: false,
              routerConfig: widget.router.router,
            );
          },
        ),
      ),
    );
  }
}
