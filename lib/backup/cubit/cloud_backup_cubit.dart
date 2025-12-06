import 'package:finanalyzer/backup/cubit/cloud_backup_state.dart';
import 'package:finanalyzer/backup/model/backup_config.dart';
import 'package:finanalyzer/backup/model/backup_metadata.dart';
import 'package:finanalyzer/backup/services/backup_service.dart';
import 'package:finanalyzer/backup/services/nextcloud_service.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class CloudBackupCubit extends Cubit<CloudBackupState> {
  final BackupService _backupService;
  final FlutterSecureStorage _secureStorage;
  final NextcloudService _nextcloudService;
  final log = Logger();

  CloudBackupCubit(this._backupService, this._secureStorage)
    : _nextcloudService = NextcloudService(_secureStorage),
      super(const CloudBackupState());

  Future<void> loadBackups() async {
    emit(
      state.copyWith(
        status: Status.loading,
        message: 'Loading cloud backups',
        progress: null,
      ),
    );
    try {
      final nextcloudConfig = await _getNextcloudConfig();
      final nextcloudConfigured = nextcloudConfig != null;
      // emit that nextcloud is configured so related errors get rendered
      emit(
        state.copyWith(
          nextcloudConfigured: nextcloudConfigured,
        ),
      );

      final List<String> nextcloud = nextcloudConfigured
          ? (await _nextcloudService.listBackupsOnCloud(nextcloudConfig))
          : [];
      final statusByFilename = {for (final n in nextcloud) n: Status.success};
      final isOnNextcloudByFilename = {for (final n in nextcloud) n: true};

      emit(
        state.copyWith(
          status: Status.success,
          message: '',
          config: nextcloudConfig,
          statusByFilename: statusByFilename,
          isOnNextcloudByFilename: isOnNextcloudByFilename,
          nextcloudConfigured: nextcloudConfigured,
        ),
      );

      log.i('Loaded ${nextcloud.length} cloud backups');
    } catch (e, stack) {
      log.e('Failed to load cloud backups', error: e, stackTrace: stack);
      emit(
        state.copyWith(
          status: Status.error,
          message: 'Failed to load cloud backups: ${e.toString()}',
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

  /// Download a single backup from Nextcloud
  /// returns if download was successful
  Future<bool> downloadFromNextcloud(String filename) async {
    emit(
      state.copyWith(
        status: Status.loading,
        message: 'Downloading...',
        progress: 0,
        statusByFilename: {...state.statusByFilename, filename: Status.loading},
      ),
    );
    try {
      final nextcloudConfig = await _getNextcloudConfig();
      if (nextcloudConfig == null) {
        throw Exception('Nextcloud not configured');
      }

      emit(state.copyWithProgress(filename, 0));

      final backupsDir = await _backupService.getLocalBackupsDirectory();
      final downloadedFile = await _nextcloudService.downloadBackup(
        nextcloudConfig,
        filename,
        backupsDir,
        onProgress: (sent, total) {
          final p = sent / total;
          emit(state.copyWithProgress(filename, p).copyWith(progress: p));
        },
      );

      if (!(await _backupService.verifyBackupFile(downloadedFile))) {
        throw Exception('File downloaded but not a valid backup.');
      }

      final backup = await _backupService.getMetadata(downloadedFile);
      log.i(
        'Backup downloaded from Nextcloud: ${backup.filename} (${backup.id})',
      );
      emit(
        state.copyWith(
          status: Status.success,
          message: '',
          statusByFilename: {
            ...state.statusByFilename,
            filename: Status.success,
          },
        ),
      );
      return true;
    } catch (e, stack) {
      log.e(
        'Failed to download backup from Nextcloud',
        error: e,
        stackTrace: stack,
      );
      emit(
        state.copyWith(
          status: Status.error,
          message: 'Failed to download from Nextcloud: ${e.toString()}',
          statusByFilename: {...state.statusByFilename, filename: Status.error},
        ),
      );
      return false;
    }
  }

  /// Upload a single backup to Nextcloud
  /// returns if upload was successful
  Future<bool> uploadToNextcloud(
    BackupMetadata backup, {
    bool updateOverallProgress = true,
  }) async {
    final filename = backup.filename;
    emit(
      state.copyWith(
        status: updateOverallProgress ? Status.loading : state.status,
        message: updateOverallProgress ? 'Uploading ...' : state.message,
        progress: updateOverallProgress ? 0 : state.progress,
        statusByFilename: {...state.statusByFilename, filename: Status.loading},
      ),
    );
    try {
      final nextcloudConfig = await _getNextcloudConfig();
      if (nextcloudConfig == null) {
        throw Exception('Nextcloud not configured');
      }

      emit(state.copyWithProgress(filename, 0));

      await _nextcloudService.uploadBackup(
        nextcloudConfig,
        backup,
        onProgress: (sent, total) {
          final p = sent / total;
          emit(
            state
                .copyWithProgress(filename, p)
                .copyWith(progress: updateOverallProgress ? p : state.progress),
          );
        },
      );

      emit(
        state.copyWith(
          status: updateOverallProgress ? Status.success : state.status,
          message: updateOverallProgress ? '' : state.message,
          statusByFilename: {
            ...state.statusByFilename,
            filename: Status.success,
          },
          isOnNextcloudByFilename: {
            ...state.isOnNextcloudByFilename,
            filename: true,
          },
        ),
      );

      log.i('Backup uploaded to Nextcloud: ${backup.id}');
      return true;
    } catch (e, stack) {
      log.e(
        'Failed to upload backup to Nextcloud',
        error: e,
        stackTrace: stack,
      );
      emit(
        state.copyWith(
          status: updateOverallProgress ? Status.error : state.status,
          message: updateOverallProgress
              ? 'Failed to upload to Nextcloud: ${e.toString()}'
              : state.message,
          statusByFilename: {...state.statusByFilename, filename: Status.error},
        ),
      );
      return false;
    }
  }

  /// Upload all backups that are not yet on Nextcloud
  Future<void> uploadAllMissingToNextcloud(
    List<BackupMetadata> backupsToUpload,
  ) async {
    if (backupsToUpload.isEmpty) {
      emit(
        state.copyWith(
          status: Status.success,
          message: 'No backups to upload',
          progress: 1,
        ),
      );
    }

    emit(
      state.copyWith(
        status: Status.loading,
        progress: 0,
        message: 'Uploading ${backupsToUpload.length} backups',
      ),
    );

    int processedCount = 0;
    int errorCount = 0;
    int successCount = 0;
    for (final backup in backupsToUpload) {
      final success = await uploadToNextcloud(
        backup,
        updateOverallProgress: false,
      );
      if (success) {
        successCount++;
      } else {
        errorCount++;
      }
      processedCount++;

      final errorMsg = errorCount > 0 ? ' ($errorCount failed)' : '';
      final msg = 'Uploaded $successCount/${backupsToUpload.length}$errorMsg';
      emit(
        state.copyWith(
          progress: processedCount / backupsToUpload.length,
          message: msg,
        ),
      );
      log.i(msg);
    }

    final errorMsg = errorCount > 0 ? ' ($errorCount failed)' : '';
    emit(
      state.copyWith(
        status: errorCount > 0 ? Status.error : Status.success,
        message: 'Uploaded $successCount backup(s)$errorMsg',
      ),
    );

    log.i('All backups uploaded to Nextcloud');
  }
}
