import 'package:finanalyzer/account/services/balance_calculation_service.dart';
import 'package:finanalyzer/backup/cubit/backup_cubit.dart';
import 'package:finanalyzer/backup/cubit/cloud_backup_cubit.dart';
import 'package:finanalyzer/backup/model/backup_repository.dart';
import 'package:finanalyzer/backup/services/archive_service.dart';
import 'package:finanalyzer/backup/services/backup_service.dart';
import 'package:finanalyzer/backup/services/encryption_service.dart';
import 'package:finanalyzer/backup/services/local_storage_service.dart';
import 'package:finanalyzer/core/restart_widget.dart';
import 'package:finanalyzer/core/secure_storage.dart';
import 'package:finanalyzer/db/db_helper.dart';
import 'package:finanalyzer/local_auth/cubit/local_auth_cubit.dart';
import 'package:finanalyzer/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/model/account_repository.dart';
import 'package:finanalyzer/savings/savings_module.dart';
import 'package:finanalyzer/router.dart';
import 'package:finanalyzer/settings/settings_cubit.dart';
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

final turnoverModule = TurnoverModule();
final modules = [
  //
  turnoverModule,
  SavingsModule(turnoverModule),
];

final accountRepository = AccountRepository();
final balanceCalculationService = BalanceCalculationService(
  turnoverModule.turnoverRepository,
  turnoverModule.tagTurnoverRepository,
);

// Backup services
final archiveService = ArchiveService();
final localStorageService = LocalStorageService();
final encryptionService = EncryptionService();
final backupRepository = BackupRepository(
  localStorageService: localStorageService,
);
final backupService = BackupService(
  dbHelper: DatabaseHelper(),
  backupRepository: backupRepository,
  archiveService: archiveService,
  localStorageService: localStorageService,
  encryptionService: encryptionService,
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TurnoverModule>.value(value: turnoverModule),
        Provider<BalanceCalculationService>.value(
          value: balanceCalculationService,
        ),
        ...modules.expand((it) => it.providers),
        Provider<AccountRepository>.value(value: accountRepository),

        Provider<BackupService>.value(value: backupService),
        BlocProvider(create: (_) => LocalAuthCubit()),
        BlocProvider(create: (_) => SettingsCubit()),
        BlocProvider(
          lazy: false,
          create: (_) =>
              AccountCubit(accountRepository, balanceCalculationService)
                ..loadAccounts(),
        ),
        BlocProvider(create: (_) => ComdirectAuthCubit()),
        BlocProvider(create: (_) => BackupCubit(backupService)),
        BlocProvider(
          create: (_) => CloudBackupCubit(backupService, secureStorage()),
        ),
      ],
      child: BlocListener<LocalAuthCubit, LocalAuthState>(
        // ensure to re-evaluate router redirects when auth state changes.
        listener: (context, state) => router.refresh(),
        child: ListenAppLifecycle(
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
      ),
    );
  }
}

class ListenAppLifecycle extends StatefulWidget {
  final Widget child;
  const ListenAppLifecycle({required this.child, super.key});

  @override
  State<ListenAppLifecycle> createState() => _ListenAppLifecycleState();
}

class _ListenAppLifecycleState extends State<ListenAppLifecycle> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onHide: () => context.read<LocalAuthCubit>().logout(),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
