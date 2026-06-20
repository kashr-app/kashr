import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/backup/model/backup_config.dart';
import 'package:kashr/backup/services/backup_service.dart';
import 'package:kashr/core/extensions/date_time_extensions.dart';
import 'package:kashr/theme.dart';

class BackupReminderWidget extends StatelessWidget {
  const BackupReminderWidget({super.key, required this.action, this.margin});

  final Widget action;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;

    return StreamBuilder<BackupConfig>(
      stream: context.read<BackupService>().watchConfig(),
      builder: (context, snapshot) {
        final config = snapshot.data;

        if (config != null) {
          final cutoff = DateTime.now().subtract(
            Duration(days: config.intervalDays),
          );

          if (config.lastBackupAt?.isAfter(cutoff) ?? false) {
            // backup is recent, so we render no reminder
            return const SizedBox.shrink();
          }
        }
        return Card(
          margin: margin ?? const EdgeInsets.all(8),
          color: customColors.warning,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: customColors.onWarning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Last backup: ${config?.lastBackupAt?.format ?? 'n/a'}',
                        style: TextStyle(color: customColors.onWarning),
                      ),
                    ),
                    action,
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
