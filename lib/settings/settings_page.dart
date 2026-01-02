import 'package:kashr/backup/backup_list_page.dart';
import 'package:kashr/db/db_helper.dart';
import 'package:kashr/home/home_page.dart';
import 'package:kashr/logging/log_viewer_page.dart';
import 'package:kashr/logging/model/log_level_setting.dart';
import 'package:kashr/local_auth/auth_delay.dart';
import 'package:kashr/settings/banks_page.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:kashr/settings/settings_state.dart';
import 'package:kashr/turnover/tag_turnovers_page.dart';
import 'package:kashr/turnover/tags_page.dart';
import 'package:kashr/turnover/transfers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final v = await DatabaseHelper().sqlLiteVersion();
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
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsHeadline(label: 'Experience'),
                BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, state) => Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.brightness_6),
                        title: const Text("Theme Mode"),
                        subtitle: Text(state.themeMode.title()),
                        onTap: () async {
                          final newValue = await _showThemeSelectionDialog(
                            context,
                          );
                          if (newValue != null && context.mounted) {
                            await context.read<SettingsCubit>().setTheme(newValue);
                          }
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.fast_forward),
                        title: const Text("Fast Form Mode"),
                        subtitle: const Text('Tap <here> for explanation'),
                        trailing: Switch(
                          value: state.fastFormMode,
                          onChanged: (value) {
                            context.read<SettingsCubit>().setFastFormMode(
                              value,
                            );
                          },
                        ),
                        onTap: () => _showFastFormModeInfo(context),
                      ),
                      ListTile(
                        leading: const Icon(Icons.lock_clock),
                        title: const Text("Auto Lock App"),
                        subtitle: Text(state.authDelay.displayName),
                        onTap: () async {
                          final newValue = await showAuthDelayDialog(
                            context,
                            state.authDelay,
                          );
                          if (newValue != null && context.mounted) {
                            await context.read<SettingsCubit>().setAuthDelay(
                              newValue,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                _SettingsHeadline(label: 'Configuration and Data'),
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
                ListTile(
                  onTap: () => const TagTurnoversRoute().go(context),
                  title: Text('TagTurnovers'),
                  leading: const Icon(Icons.my_library_books_outlined),
                  subtitle: const Text('Manage TagTurnovers'),
                ),
                ListTile(
                  onTap: () => const TransfersRoute().go(context),
                  title: Text('Transfers'),
                  leading: const Icon(Icons.swap_horiz),
                  subtitle: const Text('Manage Transfers'),
                ),
                _SettingsHeadline(label: 'Maintenance'),
                ListTile(
                  title: const Text('Backup & Restore'),
                  subtitle: const Text('Manage database backups'),
                  leading: const Icon(Icons.backup),
                  onTap: () => const BackupListRoute().go(context),
                ),
                _SettingsHeadline(label: 'System'),
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
                  subtitle: Text('${DatabaseHelper().dbVersion}'),
                  leading: const Icon(Icons.storage),
                ),
                ListTile(
                  title: const Text('SQLite Version'),
                  subtitle: Text(sqliteVersion),
                  leading: const Icon(Icons.storage),
                ),
                ListTile(
                  title: const Text('Licenses'),
                  leading: Icon(Icons.article),
                  onTap: () => showLicensePage(context: context),
                ),
                _SettingsHeadline(label: 'Developer'),
                ListTile(
                  title: const Text('Source Code'),
                  leading: Icon(Icons.code),
                  onTap: () async {
                    final url = Uri.parse('https://github.com/kashr-app/kashr');
                    if (!await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication,
                    )) {
                      throw Exception('Could not launch $url');
                    }
                  },
                ),
                BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, state) => ListTile(
                    leading: const Icon(Icons.filter_list),
                    title: const Text("Log Level"),
                    subtitle: Text(state.logLevel.displayName),
                    onTap: () async {
                      final newValue = await _showLogLevelDialog(
                        context,
                        state.logLevel,
                      );
                      if (newValue != null && context.mounted) {
                        await context.read<SettingsCubit>().setLogLevel(newValue);
                      }
                    },
                  ),
                ),
                ListTile(
                  onTap: () => const LogViewerRoute().go(context),
                  title: const Text('Logs'),
                  leading: const Icon(Icons.bug_report),
                  subtitle: const Text('View application logs'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<ThemeMode?> _showThemeSelectionDialog(BuildContext context) {
    return showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: Text(ThemeMode.system.title()),
                onTap: () {
                  Navigator.pop(context, ThemeMode.system);
                },
              ),
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: Text(ThemeMode.light.title()),
                onTap: () {
                  Navigator.pop(context, ThemeMode.light);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: Text(ThemeMode.dark.title()),
                onTap: () {
                  Navigator.pop(context, ThemeMode.dark);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<LogLevelSetting?> _showLogLevelDialog(
    BuildContext context,
    LogLevelSetting current,
  ) {
    return showModalBottomSheet<LogLevelSetting>(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: LogLevelSetting.values.map((level) {
            return ListTile(
              title: Text(level.displayName),
              trailing: level == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, level),
            );
          }).toList(),
        );
      },
    );
  }

  void _showFastFormModeInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Fast Form Mode"),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enable this to save some taps! Instead of tapping each field, the app will automatically walk you through the form, popping up dialogs one by one. Work\'s for:',
              ),
              SizedBox(height: 8),
              Text('Dasboard', style: Theme.of(context).textTheme.labelMedium),
              Text('- Adding a transaction'),
              Text('- Adding a transfer'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsHeadline extends StatelessWidget {
  const _SettingsHeadline({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

extension ThemeModeTitle on ThemeMode {
  String title() => switch (this) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}
