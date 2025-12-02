import 'package:finanalyzer/backup/cubit/backup_cubit.dart';
import 'package:finanalyzer/backup/cubit/backup_state.dart';
import 'package:finanalyzer/backup/model/backup_metadata.dart';
import 'package:finanalyzer/backup/widgets/nextcloud_settings_page.dart';
import 'package:finanalyzer/backup/widgets/restore_confirmation_dialog.dart';
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
    context.read<BackupCubit>().loadBackups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backups'),
        actions: [
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));
              },
              error: (message, exception) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
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
                    CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                    ),
                    const SizedBox(height: 16),
                    Text(operation),
                    if (progress > 0) Text('${(progress * 100).toInt()}%'),
                  ],
                ),
              ),
              loaded:
                  (
                    localBackups,
                    config,
                    isOnNextcloudById,
                    nextcloudOnly,
                    nextcloudConfigured,
                  ) => _BackupListView(
                    localBackups: localBackups,
                    isOnNextcloudById: isOnNextcloudById,
                    nextcloudOnly: nextcloudOnly,
                    nextcloudConfigured: nextcloudConfigured,
                  ),
              success: (message, backup) =>
                  const Center(child: CircularProgressIndicator()),
              error: (message, exception) => Center(
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
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createBackup(context),
        icon: const Icon(Icons.add),
        label: const Text('Create Backup'),
      ),
    );
  }

  void _createBackup(BuildContext context) async {
    // For Phase 1, always create local, unencrypted backup
    await context.read<BackupCubit>().createBackup(password: null);
  }
}

class _BackupListView extends StatelessWidget {
  final List<BackupMetadata> localBackups;
  final Map<String, bool> isOnNextcloudById;
  final List<String> nextcloudOnly;
  final bool nextcloudConfigured;

  const _BackupListView({
    required this.localBackups,
    required this.isOnNextcloudById,
    required this.nextcloudOnly,
    required this.nextcloudConfigured,
  });

  @override
  Widget build(BuildContext context) {
    if (localBackups.isEmpty && nextcloudOnly.isEmpty) {
      return _buildNoBackups(context);
    }

    final missingOnNextcloud = nextcloudConfigured
        ? localBackups.where((b) => !(isOnNextcloudById[b.id] ?? false)).length
        : 0;
    return Column(
      children: [
        if (nextcloudConfigured && missingOnNextcloud > 0)
          _buildUploadAllMissing(context, missingOnNextcloud),
        if (nextcloudConfigured) _buildDownloadFromNextcloudCard(context),
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
              final onNextcloud = isOnNextcloudById[backup.id] ?? false;
              return _BackupCard(
                backup: backup,
                onNextcloud: onNextcloud,
                nextcloudConfigured: nextcloudConfigured,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadFromNextcloudCard(BuildContext context) {
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
                      context.read<BackupCubit>().downloadFromToNextcloud(
                        selectedFilename,
                      );
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

  Card _buildUploadAllMissing(BuildContext context, int missingOnNextcloud) {
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
                '$missingOnNextcloud backup(s) not on Nextcloud',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                context.read<BackupCubit>().uploadAllMissingToNextcloud();
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
  final bool onNextcloud;
  final bool nextcloudConfigured;

  const _BackupCard({
    required this.backup,
    required this.onNextcloud,
    required this.nextcloudConfigured,
  });

  @override
  Widget build(BuildContext context) {
    final sizeInMB = (backup.fileSizeBytes ?? 0) / (1024 * 1024);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              child: Icon(backup.encrypted ? Icons.lock : Icons.folder_zip),
            ),
            if (nextcloudConfigured)
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: onNextcloud
                      ? Colors.green
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    onNextcloud ? Icons.cloud_done : Icons.cloud_off,
                    size: 10,
                    color: onNextcloud
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
            if (nextcloudConfigured)
              Row(
                children: [
                  Icon(
                    onNextcloud ? Icons.cloud_done : Icons.cloud_off,
                    size: 14,
                    color: onNextcloud
                        ? Colors.green
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    onNextcloud ? 'On Nextcloud' : 'Local only',
                    style: TextStyle(
                      color: onNextcloud
                          ? Colors.green
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
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
            if (nextcloudConfigured)
              PopupMenuItem(
                value: 'upload',
                enabled: !onNextcloud,
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
      ),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final confirmed = await RestoreConfirmationDialog.show(context, backup);
    if (!confirmed) return;

    if (context.mounted) {
      await context.read<BackupCubit>().restoreBackup(
        backup,
        null, // No password for Phase 1
      );
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

    if (confirmed == true && context.mounted) {
      await context.read<BackupCubit>().deleteBackup(backup);
    }
  }

  Future<void> _uploadToNextcloud(BuildContext context) async {
    await context.read<BackupCubit>().uploadToNextcloud(backup);
  }

  Future<void> _export(BuildContext context) async {
    await context.read<BackupCubit>().exportBackup(backup);
  }
}
