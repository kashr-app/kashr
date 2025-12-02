import 'package:finanalyzer/backup/cubit/backup_state.dart';
import 'package:finanalyzer/backup/model/backup_config.dart';
import 'package:finanalyzer/backup/model/backup_metadata.dart';
import 'package:finanalyzer/backup/services/backup_service.dart';
import 'package:finanalyzer/backup/services/nextcloud_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// Cubit for managing backup operations
class BackupCubit extends Cubit<BackupState> {
  final BackupService _backupService;
  final FlutterSecureStorage _secureStorage;
  final NextcloudService _nextcloudService;
  final log = Logger();

  BackupCubit(this._backupService, this._secureStorage)
    : _nextcloudService = NextcloudService(_secureStorage),
      super(const BackupState.initial());

  /// Load all backups and configuration
  Future<void> loadBackups() async {
    emit(const BackupState.loading(operation: 'Loading backups...'));
    try {
      final local = await _backupService.listBackups();
      final config = await _backupService.getConfig();

      // Check if Nextcloud is configured
      final nextcloudConfig = await _getNextcloudConfig();
      final nextcloudConfigured = nextcloudConfig != null;
      final List<String> nextcloud = nextcloudConfigured
          ? (await _nextcloudService.listBackupsOnCloud(nextcloudConfig))
          : [];

      // Check Nextcloud status for each local backup
      final Map<String, bool> isOnNextcloudById = {};
      final List<String> nextcloudOnly = [];
      final localFilenames = <String>{};
      if (nextcloudConfig != null) {
        final ns = {for (final n in nextcloud) n: true};
        for (final l in local) {
          isOnNextcloudById[l.id] = ns[l.filename] ?? false;
          localFilenames.add(l.filename);
        }
        for (final n in nextcloud) {
          if (!localFilenames.contains(n)) {
            nextcloudOnly.add(n);
          }
        }
      }

      emit(
        BackupState.loaded(
          localBackups: local,
          config: config,
          isOnNextcloudById: isOnNextcloudById,
          nextcloudOnly: nextcloudOnly,
          nextcloudConfigured: nextcloudConfigured,
        ),
      );

      log.i('Loaded ${local.length} local backups');
    } catch (e, stack) {
      log.e('Failed to load backups', error: e, stackTrace: stack);
      emit(
        BackupState.error(
          message: 'Failed to load backups: ${e.toString()}',
          exception: e as Exception?,
        ),
      );
    }
  }

  /// Create a new backup
  Future<void> createBackup({String? password}) async {
    emit(const BackupState.loading(operation: 'Creating backup...'));
    try {
      final metadata = await _backupService.createBackup(
        password: password,
        onProgress: (progress) {
          emit(
            BackupState.loading(
              operation: 'Creating backup...',
              progress: progress,
            ),
          );
        },
      );

      emit(
        BackupState.success(
          message: 'Backup created successfully',
          backup: metadata,
        ),
      );

      log.i('Backup created: ${metadata.id}');

      // Reload backups
      await loadBackups();
    } catch (e, stack) {
      log.e('Failed to create backup', error: e, stackTrace: stack);
      emit(
        BackupState.error(
          message: 'Failed to create backup: ${e.toString()}',
          exception: e as Exception?,
        ),
      );
    }
  }

  /// Restore from backup
  Future<void> restoreBackup(BackupMetadata backup, String? password) async {
    emit(const BackupState.loading(operation: 'Restoring backup...'));
    try {
      await _backupService.restoreBackup(backup, password, (progress) {
        emit(
          BackupState.loading(
            operation: 'Restoring backup...',
            progress: progress,
          ),
        );
      });

      emit(
        const BackupState.success(
          message: 'Backup restored successfully. Please restart the app.',
        ),
      );

      log.i('Backup restored: ${backup.id}');
    } catch (e, stack) {
      log.e('Failed to restore backup', error: e, stackTrace: stack);
      emit(
        BackupState.error(
          message: 'Failed to restore backup: ${e.toString()}',
          exception: e as Exception?,
        ),
      );
    }
  }

  /// Delete a backup
  Future<void> deleteBackup(BackupMetadata backup) async {
    emit(const BackupState.loading(operation: 'Deleting backup...'));
    try {
      await _backupService.deleteBackup(backup);

      emit(const BackupState.success(message: 'Backup deleted successfully'));

      log.i('Backup deleted: ${backup.id}');

      // Reload backups
      await loadBackups();
    } catch (e, stack) {
      log.e('Failed to delete backup', error: e, stackTrace: stack);
      emit(
        BackupState.error(
          message: 'Failed to delete backup: ${e.toString()}',
          exception: e as Exception?,
        ),
      );
    }
  }

  /// Update backup configuration
  Future<void> updateConfig(BackupConfig config) async {
    try {
      await _backupService.saveConfig(config);

      log.i('Backup config updated');

      // Reload to refresh config
      await loadBackups();
    } catch (e, stack) {
      log.e('Failed to update config', error: e, stackTrace: stack);
      emit(
        BackupState.error(
          message: 'Failed to update configuration: ${e.toString()}',
          exception: e as Exception?,
        ),
      );
    }
  }

  /// Get Nextcloud configuration from secure storage
  Future<NextcloudConfig?> _getNextcloudConfig() async {
    try {
      final url = await _secureStorage.read(key: 'nextcloud_url');
      final username = await _secureStorage.read(key: 'nextcloud_username');
      final path = await _secureStorage.read(key: 'nextcloud_path');

      if (url == null || username == null) {
        return null;
      }

      return NextcloudConfig(
        url: url,
        username: username,
        passwordKey: 'nextcloud_password',
        backupPath: path ?? '/Backups/Finanalyzer/',
      );
    } catch (e) {
      log.w('Failed to load Nextcloud config', error: e);
      return null;
    }
  }

  /// Upload a single backup to Nextcloud
  Future<void> downloadFromToNextcloud(String filename) async {
    emit(const BackupState.loading(operation: 'Downloading from Nextcloud...'));
    try {
      final nextcloudConfig = await _getNextcloudConfig();
      if (nextcloudConfig == null) {
        throw Exception('Nextcloud not configured');
      }

      final backupsDir = await _backupService.getLocalBackupsDirectory();
      final downloadedFile = await _nextcloudService.downloadBackup(
        nextcloudConfig,
        filename,
        backupsDir,
      );

      if (!(await _backupService.verifyBackupFile(downloadedFile))) {
        throw Exception('File downloaded but not a valid backup.');
      }

      final backup = await _backupService.getMetadata(downloadedFile);
      log.i(
        'Backup downloaded from Nextcloud: ${backup.filename} (${backup.id})',
      );
      emit(
        const BackupState.success(
          message: 'Backup downloaded from Nextcloud successfully',
        ),
      );

      // Reload backups
      await loadBackups();
    } catch (e, stack) {
      log.e(
        'Failed to upload backup to Nextcloud',
        error: e,
        stackTrace: stack,
      );
      emit(
        BackupState.error(
          message: 'Failed to upload to Nextcloud: ${e.toString()}',
          exception: e as Exception?,
        ),
      );
      // Reload backups even on error to show current state
      await loadBackups();
    }
  }

  /// Upload a single backup to Nextcloud
  Future<void> uploadToNextcloud(BackupMetadata backup) async {
    emit(const BackupState.loading(operation: 'Uploading to Nextcloud...'));
    try {
      final nextcloudConfig = await _getNextcloudConfig();
      if (nextcloudConfig == null) {
        throw Exception('Nextcloud not configured');
      }

      await _nextcloudService.uploadBackup(nextcloudConfig, backup);

      emit(
        const BackupState.success(
          message: 'Backup uploaded to Nextcloud successfully',
        ),
      );

      log.i('Backup uploaded to Nextcloud: ${backup.id}');

      // Reload backups
      await loadBackups();
    } catch (e, stack) {
      log.e(
        'Failed to upload backup to Nextcloud',
        error: e,
        stackTrace: stack,
      );
      emit(
        BackupState.error(
          message: 'Failed to upload to Nextcloud: ${e.toString()}',
          exception: e as Exception?,
        ),
      );
      // Reload backups even on error to show current state
      await loadBackups();
    }
  }

  /// Upload all backups that are not yet on Nextcloud
  Future<void> uploadAllMissingToNextcloud() async {
    // Capture the current state before emitting loading
    final currentState = state;
    if (currentState is! BackupLoaded) {
      throw Exception('No backups loaded');
    }

    emit(const BackupState.loading(operation: 'Uploading to Nextcloud...'));
    try {
      final nextcloudConfig = await _getNextcloudConfig();
      if (nextcloudConfig == null) {
        throw Exception('Nextcloud not configured');
      }

      final backupsToUpload = currentState.localBackups
          .where(
            (backup) => !(currentState.isOnNextcloudById[backup.id] ?? false),
          )
          .toList();

      if (backupsToUpload.isEmpty) {
        emit(
          const BackupState.success(
            message: 'All backups are already on Nextcloud',
          ),
        );
        await loadBackups();
        return;
      }

      int uploaded = 0;
      for (final backup in backupsToUpload) {
        await _nextcloudService.uploadBackup(nextcloudConfig, backup);
        uploaded++;
        log.i('Uploaded $uploaded/${backupsToUpload.length} backups');
      }

      emit(
        BackupState.success(
          message: 'Uploaded $uploaded backup(s) to Nextcloud successfully',
        ),
      );

      log.i('All backups uploaded to Nextcloud');

      // Reload backups
      await loadBackups();
    } catch (e, stack) {
      log.e(
        'Failed to upload backups to Nextcloud',
        error: e,
        stackTrace: stack,
      );
      emit(
        BackupState.error(
          message: 'Failed to upload to Nextcloud: ${e.toString()}',
          exception: e as Exception?,
        ),
      );
      // Reload backups even on error to show current state
      await loadBackups();
    }
  }

  /// Export backup to user-chosen location
  Future<void> exportBackup(BackupMetadata backup) async {
    emit(const BackupState.loading(operation: 'Exporting backup...'));
    try {
      await _backupService.exportBackup(backup);

      emit(const BackupState.success(message: 'Backup exported successfully'));

      log.i('Backup exported: ${backup.id}');

      // Reload backups to return to normal state
      await loadBackups();
    } catch (e, stack) {
      log.e('Failed to export backup', error: e, stackTrace: stack);
      emit(
        BackupState.error(
          message: 'Failed to export backup: ${e.toString()}',
          exception: e as Exception?,
        ),
      );
      // Reload backups even on error to show current state
      await loadBackups();
    }
  }
}
