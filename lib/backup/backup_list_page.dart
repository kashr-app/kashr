import 'package:finanalyzer/backup/cubit/backup_cubit.dart';
import 'package:finanalyzer/backup/cubit/backup_state.dart';
import 'package:finanalyzer/backup/cubit/cloud_backup_cubit.dart';
import 'package:finanalyzer/backup/cubit/cloud_backup_state.dart';
import 'package:finanalyzer/backup/model/backup_metadata.dart';
import 'package:finanalyzer/backup/widgets/backup_settings_dialog.dart';
import 'package:finanalyzer/backup/widgets/encryption_password_dialog.dart';
import 'package:finanalyzer/backup/widgets/nextcloud_settings_page.dart';
import 'package:finanalyzer/backup/widgets/restore_confirmation_dialog.dart';
import 'package:finanalyzer/core/associate_by.dart';
import 'package:finanalyzer/core/restart_widget.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BackupListRoute extends GoRouteData with $BackupListRoute {
  const BackupListRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const BackupListPage();
  }
}

class NextcloudSettingsRoute extends GoRouteData with $NextcloudSettingsRoute {
  const NextcloudSettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const NextcloudSettingsPage();
  }
}

final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

/// Page for viewing and managing backups
class BackupListPage extends StatefulWidget {
  const BackupListPage({super.key});

  @override
  State<BackupListPage> createState() => _BackupListPageState();
}

class _BackupListPageState extends State<BackupListPage> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    context.read<BackupCubit>().loadBackups();
    context.read<CloudBackupCubit>().loadBackups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Page',
            onPressed: () => _refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Backup Settings',
            onPressed: () => _showBackupSettings(context),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            tooltip: 'Nextcloud Settings',
            onPressed: () => const NextcloudSettingsRoute().go(context),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<BackupCubit, BackupState>(
          listener: (context, state) {
            state.maybeWhen(
              success: (message, backup) {
                Status.success.snack(context, message);
              },
              error: (message, exception) {
                Status.error.snack(context, message);
              },
              orElse: () {},
            );
          },
          builder: (context, state) {
            return state.when(
              initial: () => const Center(child: CircularProgressIndicator()),
              loading: (operation, progress) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (progress > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: LinearProgressIndicator(value: progress),
                      )
                    else
                      CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(operation),
                    if (progress > 0) Text('${(progress * 100).toInt()}%'),
                  ],
                ),
              ),
              loaded: (localBackups, config) => _BackupListView(
                localBackups: localBackups,
                refresh: _refresh,
              ),
              success: (message, backup) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Icon(
                      size: 24,
                      Icons.done,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(height: 24),
                    Text(message),
                  ],
                ),
              ),
              error: (message, exception) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          context.read<BackupCubit>().loadBackups();
                        },
                        child: const Text('Reload page'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: BlocBuilder<BackupCubit, BackupState>(
        builder: (context, state) => state.when(
          initial: () => SizedBox.shrink(),
          loading: (_, _) => SizedBox.shrink(),
          loaded: (_, _) => FloatingActionButton.extended(
            onPressed: () => _createBackup(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Backup'),
          ),
          success: (_, _) => SizedBox.shrink(),
          error: (_, _) => SizedBox.shrink(),
        ),
      ),
    );
  }

  void _createBackup(BuildContext context) async {
    final cubit = context.read<BackupCubit>();
    final currentState = cubit.state;

    // Get encryption setting from config
    String? password;
    if (currentState is BackupLoaded && currentState.config.encryptionEnabled) {
      password = await EncryptionPasswordDialog.show(context, isRestore: false);

      // User cancelled
      if (password == null) return;
    }

    await cubit.createBackup(password: password);
  }

  void _showBackupSettings(BuildContext context) {
    final state = context.read<BackupCubit>().state;
    if (state is BackupLoaded) {
      BackupSettingsDialog.show(context, state.config);
    }
  }
}

class _BackupListView extends StatelessWidget {
  final List<BackupMetadata> localBackups;
  final VoidCallback refresh;

  const _BackupListView({required this.localBackups, required this.refresh});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildNextcloudStatus(context, localBackups, refresh),
        if (localBackups.isEmpty)
          _buildNoBackups(context)
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: AlignmentGeometry.centerLeft,
              child: Text(
                '${localBackups.length} local backups',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: localBackups.length,
              itemBuilder: (context, index) {
                final backup = localBackups[index];
                return _BackupCard(backup: backup);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNextcloudStatus(
    BuildContext context,
    List<BackupMetadata> localBackups,
    VoidCallback refresh,
  ) {
    return BlocBuilder<CloudBackupCubit, CloudBackupState>(
      builder: (context, state) {
        if (!state.nextcloudConfigured) {
          return SizedBox.shrink();
        }

        switch (state.status) {
          case Status.loading:
            return Card(
              margin: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    LinearProgressIndicator(value: state.progress),
                    SizedBox(height: 4),
                    Text(state.message),
                  ],
                ),
              ),
            );
          case Status.error:
            return Card(
              margin: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      state.message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    TextButton(onPressed: refresh, child: Text('Reload page')),
                  ],
                ),
              ),
            );
          case Status.initial:
          case Status.success:
            break;
        }

        final missingOnNextcloud = localBackups
            .where((b) => !(state.isOnNextcloudByFilename[b.filename] ?? false))
            .toList();

        return Column(
          children: [
            _buildUploadAllMissing(context, missingOnNextcloud),
            _builNextcloudOnlyCard(state, localBackups, context),
          ],
        );
      },
    );
  }

  Widget _builNextcloudOnlyCard(
    CloudBackupState state,
    List<BackupMetadata> localByFilename,
    BuildContext context,
  ) {
    final localByFilename = localBackups.associateBy((it) => it.filename);
    final nextcloudOnly = [
      for (final filename in state.isOnNextcloudByFilename.keys)
        if (null == localByFilename[filename]) filename,
    ];
    if (nextcloudOnly.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Align(
          alignment: AlignmentGeometry.centerLeft,
          child: Text('No additional backups on nextcloud'),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_download,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${nextcloudOnly.length} additional on Nextcloud',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final selectedFilename = await showFilenamePickerDialog(
                      context,
                      nextcloudOnly,
                    );
                    if (selectedFilename != null && context.mounted) {
                      final backupCubit = context.read<BackupCubit>();
                      final success = await context
                          .read<CloudBackupCubit>()
                          .downloadFromNextcloud(selectedFilename);
                      if (success) {
                        // refresh list to show the downloaded backup
                        backupCubit.loadBackups();
                      }
                    }
                  },
                  child: Text('View'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadAllMissing(
    BuildContext context,
    List<BackupMetadata> missingOnNextcloud,
  ) {
    if (missingOnNextcloud.isEmpty) {
      return SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.cloud_upload,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${missingOnNextcloud.length} backup(s) not on Nextcloud',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                context.read<CloudBackupCubit>().uploadAllMissingToNextcloud(
                  missingOnNextcloud,
                );
              },
              child: const Text('Upload All'),
            ),
          ],
        ),
      ),
    );
  }

  Center _buildNoBackups(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.backup_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text('No backups yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Create your first backup to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> showFilenamePickerDialog(
    BuildContext context,
    List<String> filenames,
  ) {
    String? selected;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select a file'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filenames.length,
                  itemBuilder: (context, index) {
                    final file = filenames[index];
                    final isSelected = file == selected;

                    return ListTile(
                      title: Text(file),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).primaryColor,
                            )
                          : SizedBox.shrink(),
                      onTap: () {
                        setState(() {
                          selected = file;
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(context, selected),
                  child: Text('Download'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BackupCard extends StatelessWidget {
  final BackupMetadata backup;

  const _BackupCard({required this.backup});

  @override
  Widget build(BuildContext context) {
    final sizeInMB = (backup.fileSizeBytes ?? 0) / (1024 * 1024);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: BlocBuilder<CloudBackupCubit, CloudBackupState>(
        builder: (context, cloudState) {
          final isOnNextcloud =
              cloudState.isOnNextcloudByFilename[backup.filename] ?? false;
          final cloudStatus =
              cloudState.statusByFilename[backup.filename] ?? Status.initial;
          final cloudProgress = cloudState.progressByFilename[backup.filename];
          final cloudColor = cloudStatus.isSuccess
              ? Colors.green
              : cloudStatus.isError
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant;
          return ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  child: Icon(backup.encrypted ? Icons.lock : Icons.folder_zip),
                ),
                if (cloudState.nextcloudConfigured)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: cloudStatus.isSuccess
                          ? Colors.green
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        cloudStatus.isSuccess
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        size: 10,
                        color: cloudStatus.isSuccess
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(dateFormat.format(backup.createdAt)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${sizeInMB.toStringAsFixed(2)} MB'),
                Row(
                  children: [
                    Text('DB v${backup.dbVersion} • App v${backup.appVersion}'),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      backup.encrypted ? Icons.lock : Icons.lock_open,
                      size: 14,
                      color: backup.encrypted
                          ? Colors.green
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      backup.encrypted ? 'Encrypted' : 'Not encrypted',
                      style: TextStyle(
                        color: backup.encrypted
                            ? Colors.green
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (cloudState.nextcloudConfigured)
                  Row(
                    children: [
                      Icon(
                        cloudStatus.isSuccess
                            ? Icons.cloud_done
                            : cloudStatus.isLoading
                            ? Icons.cloud_queue
                            : Icons.cloud_off,
                        size: 14,
                        color: cloudColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: cloudStatus.isLoading
                            ? LinearProgressIndicator(value: cloudProgress)
                            : Text(
                                switch (cloudStatus) {
                                  Status.initial => 'Local only',
                                  Status.loading => 'Loading',
                                  Status.success => 'Nextcloud',
                                  Status.error => 'Error',
                                },
                                style: TextStyle(
                                  color: cloudColor,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ],
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'restore') {
                  _restore(context);
                } else if (value == 'delete') {
                  _delete(context);
                } else if (value == 'upload') {
                  _uploadToNextcloud(context);
                } else if (value == 'export') {
                  _export(context);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'name',
                  enabled: false,
                  child: Text(
                    backup.filename,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                ),
                const PopupMenuItem(
                  value: 'restore',
                  child: Row(
                    children: [
                      Icon(Icons.restore),
                      SizedBox(width: 12),
                      Text('Restore'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_download),
                      SizedBox(width: 12),
                      Text('Export'),
                    ],
                  ),
                ),
                if (cloudState.nextcloudConfigured)
                  PopupMenuItem(
                    value: 'upload',
                    enabled: !isOnNextcloud,
                    child: Row(
                      children: [
                        Icon(Icons.cloud_upload),
                        SizedBox(width: 12),
                        Text('Upload to Nextcloud'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete),
                      SizedBox(width: 12),
                      Text('Delete locally'),
                    ],
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final confirmed = await RestoreConfirmationDialog.show(context, backup);
    if (!confirmed) return;

    String? password;
    if (backup.encrypted) {
      if (context.mounted) {
        password = await EncryptionPasswordDialog.show(
          context,
          isRestore: true,
        );

        // User cancelled
        if (password == null) return;

        // Allow dialog dismissal animation to complete
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    if (context.mounted) {
      final restarter = RestartWidget.getRestarter(context);
      final goRouter = GoRouter.of(context);
      final restored = await context.read<BackupCubit>().restoreBackup(
        backup,
        password,
      );
      if (restored) {
        // give the user some time to read the success message
        await Future.delayed(const Duration(seconds: 2));
        // not really a restart but we re-new widget state etc
        //but still would like the user to restart the app
        goRouter.go(HomeRoute().location);
        restarter?.restart();
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // give the user some time to read the success message
      await Future.delayed(const Duration(seconds: 3));
      if (context.mounted) {
        await context.read<BackupCubit>().deleteBackup(backup);
      }
    }
  }

  Future<void> _uploadToNextcloud(BuildContext context) async {
    await context.read<CloudBackupCubit>().uploadToNextcloud(backup);
  }

  Future<void> _export(BuildContext context) async {
    await context.read<BackupCubit>().exportBackup(backup);
  }
}
