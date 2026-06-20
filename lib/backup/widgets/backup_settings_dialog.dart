import 'package:kashr/backup/cubit/backup_cubit.dart';
import 'package:kashr/backup/model/backup_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Dialog for configuring backup settings
class BackupSettingsDialog extends StatefulWidget {
  final BackupConfig initialConfig;

  const BackupSettingsDialog({super.key, required this.initialConfig});

  /// Show the backup settings dialog
  static Future<void> show(BuildContext context, BackupConfig config) async {
    return showDialog(
      context: context,
      builder: (context) => BackupSettingsDialog(initialConfig: config),
    );
  }

  @override
  State<BackupSettingsDialog> createState() => _BackupSettingsDialogState();
}

class _BackupSettingsDialogState extends State<BackupSettingsDialog> {
  late BackupConfig _config;

  late final TextEditingController _intervalDaysController;
  late final TextEditingController _maxLocalBackupsController;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _intervalDaysController = TextEditingController(
      text: _config.intervalDays.toString(),
    );
    _maxLocalBackupsController = TextEditingController(
      text: _config.maxLocalBackups.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Backup Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Enable Encryption'),
              subtitle: const Text('Protect backups with a password'),
              value: _config.encryptionEnabled,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(encryptionEnabled: value);
                });
              },
            ),
            if (_config.encryptionEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  'You will be asked for a password when creating backups. '
                  'Keep your password safe - it cannot be recovered!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const Divider(),
            ListTile(
              title: const Text('Backup Reminder'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shows a reminder when the latest backup is older\n'
                    'than the configured number of days.',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    controller: _intervalDaysController,
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        setState(() {
                          _config = _config.copyWith(intervalDays: parsed);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Local Backups Count'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Count of local backups to keep when cleaning up.'),
                  const SizedBox(height: 8),
                  TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    controller: _maxLocalBackupsController,
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        setState(() {
                          _config = _config.copyWith(maxLocalBackups: parsed);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Auto Backup'),
              subtitle: Text(
                _config.autoBackupEnabled
                    ? 'Automatically backup every ${_config.intervalDays} days'
                    : 'Create backups manually',
              ),
              value: _config.autoBackupEnabled,
              onChanged: true
                  ? null
                  : (value) {
                      // TODO enable once auto backups suported
                      setState(() {
                        _config = _config.copyWith(autoBackupEnabled: value);
                      });
                    },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            context.read<BackupCubit>().updateConfig(_config);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
