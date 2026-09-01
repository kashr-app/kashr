import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kashr/backup/model/backup_config.dart';
import 'package:kashr/backup/services/backup_service.dart';
import 'package:kashr/settings/extensions.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:kashr/theme.dart';

/// How long the very first backup reminder is held back after onboarding.
///
/// A fresh install has barely any data worth backing up, so reminding on the
/// first dashboard view is noise rather than help.
const backupReminderGrace = Duration(days: 3);

/// Whether the backup reminder should be rendered.
///
/// Once a backup exists, [BackupConfig.intervalDays] alone decides. Before the
/// first backup the reminder is held back until [grace] has passed since
/// [onboardingCompletedOn], which stands in for the install date.
bool shouldShowBackupReminder({
  required BackupConfig? config,
  required DateTime? onboardingCompletedOn,
  required DateTime now,
  Duration grace = backupReminderGrace,
}) {
  if (config == null) return false;

  final lastBackupAt = config.lastBackupAt;
  if (lastBackupAt != null) {
    final cutoff = now.subtract(Duration(days: config.intervalDays));
    return !lastBackupAt.isAfter(cutoff);
  }

  if (onboardingCompletedOn == null) return false;
  return now.isAfter(onboardingCompletedOn.add(grace));
}

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
    final onboardingCompletedOn = context.select(
      (SettingsCubit c) => c.state.onboardingCompletedOn,
    );

    return StreamBuilder<BackupConfig>(
      stream: _configStream,
      builder: (context, snapshot) {
        final config = snapshot.data;

        final visible = shouldShowBackupReminder(
          config: config,
          onboardingCompletedOn: onboardingCompletedOn,
          now: DateTime.now(),
        );
        if (!visible) return const SizedBox.shrink();

        final lastBackupAt = config?.lastBackupAt;
        final message = lastBackupAt == null
            ? 'No backup yet. Your data only lives on this device.'
            : 'Last backup: ${context.dateFormat.format(lastBackupAt)} '
                  '${DateFormat.Hm().format(lastBackupAt)}';

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
                        message,
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
