import 'package:finanalyzer/backup/cubit/backup_cubit.dart';
import 'package:finanalyzer/backup/model/backup_config.dart';
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

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
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
              title: const Text('Max Local Backups'),
              subtitle: Text('Keep up to ${_config.maxLocalBackups} backups'),
              trailing: SizedBox(
                width: 100,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  controller: TextEditingController(
                    text: _config.maxLocalBackups.toString(),
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      setState(() {
                        _config = _config.copyWith(maxLocalBackups: parsed);
                      });
                    }
                  },
                ),
              ),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Auto Backup'),
              subtitle: Text(
                _config.autoBackupEnabled
                    ? 'Automatically backup ${_config.frequency.name}'
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
            if (_config.autoBackupEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: DropdownButtonFormField<BackupFrequency>(
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _config.frequency,
                  items: BackupFrequency.values.map((freq) {
                    return DropdownMenuItem(
                      value: freq,
                      child: Text(
                        freq.name[0].toUpperCase() + freq.name.substring(1),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _config = _config.copyWith(frequency: value);
                      });
                    }
                  },
                ),
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
