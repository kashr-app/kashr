import 'package:kashr/backup/cubit/backup_state.dart';
import 'package:kashr/backup/model/backup_config.dart';
import 'package:kashr/backup/model/backup_metadata.dart';
import 'package:kashr/backup/services/backup_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

/// Cubit for managing backup operations
class BackupCubit extends Cubit<BackupState> {
  final BackupService _backupService;
  final Logger log;

  BackupCubit(this._backupService, this.log)
    : super(const BackupState.initial());

  /// Load all backups and configuration
  Future<void> loadBackups() async {
    emit(const BackupState.loading(operation: 'Loading backups...'));
    try {
      final local = await _backupService.listBackups();
      final config = await _backupService.getConfig();

      emit(BackupState.loaded(localBackups: local, config: config));

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
  Future<bool> restoreBackup(BackupMetadata backup, String? password) async {
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
      return true;
    } catch (e, stack) {
      log.e('Failed to restore backup', error: e, stackTrace: stack);
      emit(
        BackupState.error(
          message: 'Failed to restore backup: ${e.toString()}',
          exception: e as Exception?,
        ),
      );
      return false;
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

  Future<void> importBackup() async {
    emit(const BackupState.loading(operation: 'Importing backup...'));

    try {
      final success = await _backupService.importBackup();
      if (success) {
        emit(
          const BackupState.success(
            message: 'File imported successfully. You can now restore it.',
          ),
        );
      }
      // Reload backups to return to normal state
      await loadBackups();
    } catch (e, stack) {
      log.e('Failed to import backup', error: e, stackTrace: stack);
      emit(
        BackupState.error(
          message: 'Failed to import backup: ${e.toString()}',
          exception: e as Exception?,
        ),
      );
      // Reload backups even on error to show current state
      await loadBackups();
    }
  }
}
