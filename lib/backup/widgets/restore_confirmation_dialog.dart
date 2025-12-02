import 'package:finanalyzer/backup/model/backup_metadata.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Dialog to confirm backup restore operation
class RestoreConfirmationDialog extends StatefulWidget {
  final BackupMetadata backup;

  const RestoreConfirmationDialog({
    required this.backup,
    super.key,
  });

  /// Show the dialog and return true if user confirms
  static Future<bool> show(
    BuildContext context,
    BackupMetadata backup,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => RestoreConfirmationDialog(backup: backup),
    );
    return result ?? false;
  }

  @override
  State<RestoreConfirmationDialog> createState() =>
      _RestoreConfirmationDialogState();
}

class _RestoreConfirmationDialogState
    extends State<RestoreConfirmationDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final sizeInMB = (widget.backup.fileSizeBytes ?? 0) / (1024 * 1024);

    return AlertDialog(
      title: const Text('Restore Backup?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will replace all current data with the backup from:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(dateFormat.format(widget.backup.createdAt)),
            subtitle: const Text('Backup date'),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: Text('${sizeInMB.toStringAsFixed(2)} MB'),
            subtitle: const Text('Backup size'),
          ),
          if (widget.backup.encrypted)
            const ListTile(
              leading: Icon(Icons.lock),
              title: Text('Encrypted'),
              subtitle: Text('You will need to enter the password'),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This will permanently replace all current data!',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _understood,
            onChanged: (value) {
              setState(() {
                _understood = value ?? false;
              });
            },
            title: const Text('I understand this cannot be undone'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _understood
              ? () => Navigator.of(context).pop(true)
              : null,
          child: const Text('Restore'),
        ),
      ],
    );
  }
}
