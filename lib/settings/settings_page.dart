import 'package:finanalyzer/backup/backup_list_page.dart';
import 'package:finanalyzer/db/db_helper.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/settings/banks_page.dart';
import 'package:finanalyzer/settings/settings_cubit.dart';
import 'package:finanalyzer/settings/settings_state.dart';
import 'package:finanalyzer/turnover/tags_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const SettingsPage();
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String appName = '';
  String packageName = '';
  String version = '?';
  String buildNumber = '?';
  String sqliteVersion = '?';

  @override
  void initState() {
    super.initState();
    _getAppVersion();
    _getSqlLiteVersion();
  }

  // Get the app version
  Future<void> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();

    setState(() {
      appName = packageInfo.appName;
      packageName = packageInfo.packageName;
      version = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    });
  }

  Future<void> _getSqlLiteVersion() async {
    final db = await DatabaseHelper().database;
    final v =
        (await db.rawQuery('SELECT sqlite_version()')).first.values.first
            as String?;
    setState(() {
      sqliteVersion = v ?? 'err';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, state) => ListTile(
                    title: const Text("Theme Mode"),
                    subtitle: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text("System"),
                          icon: Icon(Icons.brightness_6),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text("Light"),
                          icon: Icon(Icons.light_mode),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text("Dark"),
                          icon: Icon(Icons.dark_mode),
                        ),
                      ],
                      selected: <ThemeMode>{state.themeMode},
                      onSelectionChanged: (value) =>
                          context.read<SettingsCubit>().setTheme(value.first),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  onTap: () => const BanksRoute().go(context),
                  title: Text('Banks'),
                  leading: const Icon(Icons.account_balance),
                  subtitle: const Text('Manage bank synchronization'),
                ),
                ListTile(
                  onTap: () => const TagsRoute().go(context),
                  title: Text('Tags'),
                  leading: const Icon(Icons.label),
                  subtitle: const Text('Manage tags'),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Backup & Restore'),
                  subtitle: const Text('Manage database backups'),
                  leading: const Icon(Icons.backup),
                  onTap: () => const BackupListRoute().go(context),
                ),
                const Divider(),
                ListTile(
                  title: Text('App Version'),
                  subtitle: Text(version),
                  leading: const Icon(Icons.info_outline),
                ),
                ListTile(
                  title: Text('Build Number'),
                  subtitle: Text(buildNumber),
                  leading: const Icon(Icons.build),
                ),
                ListTile(
                  title: const Text('Database Version'),
                  subtitle: Text('$dbVersion'),
                  leading: const Icon(Icons.storage),
                ),
                ListTile(
                  title: const Text('SQLite Version'),
                  subtitle: Text(sqliteVersion),
                  leading: const Icon(Icons.storage),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
