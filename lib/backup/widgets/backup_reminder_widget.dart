import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/backup/model/backup_config.dart';
import 'package:kashr/backup/services/backup_service.dart';
import 'package:kashr/core/extensions/date_time_extensions.dart';
import 'package:kashr/theme.dart';

class BackupReminderWidget extends StatefulWidget {
  const BackupReminderWidget({super.key, required this.action, this.margin});

  final Widget action;
  final EdgeInsets? margin;

  @override
  State<BackupReminderWidget> createState() => _BackupReminderWidgetState();
}

class _BackupReminderWidgetState extends State<BackupReminderWidget> {
  late final Stream<BackupConfig> _configStream;

  @override
  void initState() {
    super.initState();
    _configStream = context.read<BackupService>().watchConfig();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;

    return StreamBuilder<BackupConfig>(
      stream: _configStream,
      builder: (context, snapshot) {
        final config = snapshot.data;

        var visible = true;
        if (config == null) {
          visible = false;
        } else {
          final cutoff = DateTime.now().subtract(
            Duration(days: config.intervalDays),
          );

          if (config.lastBackupAt?.isAfter(cutoff) ?? false) {
            // backup is recent, so we render no reminder
            visible = false;
          }
        }
        if (!visible) return const SizedBox.shrink();
        return Card(
          margin: widget.margin ?? const EdgeInsets.all(8),
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
                    widget.action,
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
