import 'package:finanalyzer/account/services/balance_calculation_service.dart';
import 'package:finanalyzer/backup/cubit/backup_cubit.dart';
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
import 'package:finanalyzer/savings/cubit/savings_cubit.dart';
import 'package:finanalyzer/savings/model/savings_repository.dart';
import 'package:finanalyzer/savings/model/savings_virtual_booking_repository.dart';
import 'package:finanalyzer/savings/services/savings_balance_service.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_cubit.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/services/turnover_matching_service.dart';
import 'package:finanalyzer/router.dart';
import 'package:finanalyzer/settings/settings_cubit.dart';
import 'package:finanalyzer/settings/settings_state.dart';
import 'package:finanalyzer/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

const bool isDevelopment = bool.fromEnvironment('dart.vm.product') == false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RestartWidget(child: const MyApp()));
}

final turnoverRepository = TurnoverRepository();
final accountRepository = AccountRepository();
final tagRepository = TagRepository();
final tagTurnoverRepository = TagTurnoverRepository();
final savingsRepository = SavingsRepository();
final savingsVirtualBookingRepository = SavingsVirtualBookingRepository();
final balanceCalculationService = BalanceCalculationService(
  turnoverRepository,
  tagTurnoverRepository,
);
final savingsBalanceService = SavingsBalanceService(
  tagTurnoverRepository,
  savingsVirtualBookingRepository,
  savingsRepository,
);
final turnoverMatchingService = TurnoverMatchingService(
  tagTurnoverRepository,
  turnoverRepository,
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
        Provider<TurnoverRepository>.value(value: turnoverRepository),
        Provider<AccountRepository>.value(value: accountRepository),
        Provider<TagRepository>.value(value: tagRepository),
        Provider<TagTurnoverRepository>.value(value: tagTurnoverRepository),
        Provider<SavingsRepository>.value(value: savingsRepository),
        Provider<SavingsVirtualBookingRepository>.value(
          value: savingsVirtualBookingRepository,
        ),
        Provider<BalanceCalculationService>.value(
          value: balanceCalculationService,
        ),
        Provider<SavingsBalanceService>.value(value: savingsBalanceService),
        Provider<TurnoverMatchingService>.value(value: turnoverMatchingService),
        Provider<BackupService>.value(value: backupService),
        BlocProvider(create: (_) => LocalAuthCubit()),
        BlocProvider(create: (_) => SettingsCubit()),
        BlocProvider(create: (_) => TurnoverCubit(turnoverRepository)),
        BlocProvider(
          lazy: false,
          create: (_) =>
              AccountCubit(accountRepository, balanceCalculationService)
                ..loadAccounts(),
        ),
        BlocProvider(create: (_) => ComdirectAuthCubit()),
        BlocProvider(
          lazy: false,
          create: (_) => TagCubit(tagRepository)..loadTags(),
        ),
        BlocProvider(
          create: (_) =>
              SavingsCubit(savingsRepository, savingsBalanceService)
                ..loadAllSavings(),
        ),
        BlocProvider(
          create: (_) => BackupCubit(backupService, secureStorage()),
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
