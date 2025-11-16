import 'package:finanalyzer/local_auth/cubit/local_auth_cubit.dart';
import 'package:finanalyzer/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:finanalyzer/account/model/account_cubit.dart';
import 'package:finanalyzer/account/model/account_repository.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_cubit.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
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
  runApp(const MyApp());
}

final turnoverRepository = TurnoverRepository();
final accountRepository = AccountRepository();
final tagRepository = TagRepository();
final tagTurnoverRepository = TagTurnoverRepository();

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
        BlocProvider(
          create: (_) => LocalAuthCubit(),
        ),
        BlocProvider(
          create: (_) => SettingsCubit(),
        ),
        BlocProvider(
          create: (_) => TurnoverCubit(turnoverRepository),
        ),
        BlocProvider(
          create: (_) => AccountCubit(accountRepository),
        ),
        BlocProvider(
          create: (_) => ComdirectAuthCubit(),
        ),
        BlocProvider(
          create: (_) => TagCubit(tagRepository),
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
          }),
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
